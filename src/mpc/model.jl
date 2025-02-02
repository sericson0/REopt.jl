# *********************************************************************************
# REopt, Copyright (c) 2019-2020, Alliance for Sustainable Energy, LLC.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without modification,
# are permitted provided that the following conditions are met:
#
# Redistributions of source code must retain the above copyright notice, this list
# of conditions and the following disclaimer.
#
# Redistributions in binary form must reproduce the above copyright notice, this
# list of conditions and the following disclaimer in the documentation and/or other
# materials provided with the distribution.
#
# Neither the name of the copyright holder nor the names of its contributors may be
# used to endorse or promote products derived from this software without specific
# prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
# IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
# INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
# BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
# OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
# OF THE POSSIBILITY OF SUCH DAMAGE.
# *********************************************************************************
"""
    run_mpc(m::JuMP.AbstractModel, fp::String)

Solve the model predictive control problem using the `MPCScenario` defined in the JSON file stored at the file path `fp`.

Returns a Dict of results with keys matching those in the `MPCScenario`.
"""
function run_mpc(m::JuMP.AbstractModel, fp::String)
	s = MPCScenario(JSON.parsefile(fp))
	run_mpc(m, MPCInputs(s))
end


"""
    run_mpc(m::JuMP.AbstractModel,  d::Dict)

Solve the model predictive control problem using the `MPCScenario` defined in the dict `d`.

Returns a Dict of results with keys matching those in the `MPCScenario`.
"""
function run_mpc(m::JuMP.AbstractModel, d::Dict)
	s = MPCScenario(d)
	run_mpc(m, MPCInputs(s))
end


"""
    run_mpc(m::JuMP.AbstractModel, p::MPCInputs)

Solve the model predictive control problem using the `MPCInputs`.

Returns a Dict of results with keys matching those in the `MPCScenario`.
"""
function run_mpc(m::JuMP.AbstractModel, p::MPCInputs)
    build_mpc!(m, p)

    if !p.s.settings.add_soc_incentive
		@objective(m, Min, m[:Costs])
	else # Keep SOC high
		@objective(m, Min, m[:Costs] - sum(m[:dvStoredEnergy][:elec, ts] for ts in p.time_steps) /
									   (8760. / p.hours_per_timestep)
		)
	end

	@info "Model built. Optimizing..."
	tstart = time()
	optimize!(m)
	opt_time = round(time() - tstart, digits=3)
	if termination_status(m) == MOI.TIME_LIMIT
		status = "timed-out"
    elseif termination_status(m) == MOI.OPTIMAL
        status = "optimal"
    else
		status = "not optimal"
		@warn "MPC solved with " termination_status(m), ", returning the model."
		return m
	end
	@info "MPC solved with " termination_status(m)
	@info "Solving took $(opt_time) seconds."

	tstart = time()
	results = mpc_results(m, p)
	time_elapsed = time() - tstart
	@info "Total results processing took $(round(time_elapsed, digits=3)) seconds."
	results["status"] = status
	results["solver_seconds"] = opt_time
	return results
end


"""
    build_mpc!(m::JuMP.AbstractModel, p::MPCInputs)

Add variables and constraints for model predictive control model. 
Similar to a REopt model but with any length of horizon (instead of one calendar year,
and the DER sizes must be provided.
"""
function build_mpc!(m::JuMP.AbstractModel, p::MPCInputs)
    add_variables!(m, p)

	for ts in p.time_steps_without_grid

		fix(m[:dvGridPurchase][ts], 0.0, force=true)

		for t in p.s.storage.types
			fix(m[:dvGridToStorage][t, ts], 0.0, force=true)
		end

		for t in p.techs.elec, u in p.export_bins_by_tech[t]
			fix(m[:dvProductionToGrid][t, u, ts], 0.0, force=true)
		end
	end

	for b in p.s.storage.types
		if p.s.storage.size_kw[b] == 0 || p.s.storage.size_kwh[b] == 0
			@constraint(m, [ts in p.time_steps], m[:dvStoredEnergy][b, ts] == 0)
			@constraint(m, [t in p.techs.elec, ts in p.time_steps_with_grid],
						m[:dvProductionToStorage][b, t, ts] == 0)
			@constraint(m, [ts in p.time_steps], m[:dvDischargeFromStorage][b, ts] == 0)
			@constraint(m, [ts in p.time_steps], m[:dvGridToStorage][b, ts] == 0)
		else
			add_storage_dispatch_constraints(m, p, b)
		end
	end

	if any(size_kw->size_kw > 0, (p.s.storage.size_kw[b] for b in p.s.storage.types))
		add_storage_sum_constraints(m, p)
	end

	add_production_constraints(m, p)

	if !isempty(p.techs.no_turndown)
		@constraint(m, [t in p.techs.no_turndown, ts in p.time_steps],
            m[:dvRatedProduction][t,ts] == m[:dvSize][t]
        )
	end

	add_elec_load_balance_constraints(m, p)

	if !isempty(p.s.electric_tariff.export_bins)
		add_export_constraints(m, p)
	end

	if !isempty(p.s.electric_tariff.monthly_demand_rates)
		add_monthly_peak_constraint(m, p)
	end

	if !isempty(p.s.electric_tariff.tou_demand_ratchet_timesteps)
		add_tou_peak_constraint(m, p)
	end

	if !(p.s.electric_utility.allow_simultaneous_export_import) & !isempty(p.s.electric_tariff.export_bins)
		add_simultaneous_export_import_constraint(m, p)
	end
	
    m[:TotalFuelCosts] = 0.0
    m[:TotalPerUnitProdOMCosts] = 0.0

    if !isempty(p.techs.gen)
        add_gen_constraints(m, p)
		m[:TotalPerUnitProdOMCosts] += @expression(m, 
			sum(p.s.generator.om_cost_per_kwh * p.hours_per_timestep *
			m[:dvRatedProduction][t, ts] for t in p.techs.gen, ts in p.time_steps)
		)
        m[:TotalGenFuelCosts] = @expression(m,
            sum(m[:dvFuelUsage][t,ts] * p.s.generator.fuel_cost_per_gallon for t in p.techs.gen, ts in p.time_steps)
        )
        m[:TotalFuelCosts] += m[:TotalGenFuelCosts]
	end

	add_elec_utility_expressions(m, p)
    add_previous_monthly_peak_constraint(m, p)
    add_previous_tou_peak_constraint(m, p)

    # TODO: random outages in MPC?
	if !isempty(p.s.electric_utility.outage_durations)
		add_dv_UnservedLoad_constraints(m,p)
		add_outage_cost_constraints(m,p)
		add_MG_production_constraints(m,p)
		add_MG_storage_dispatch_constraints(m,p)
		add_cannot_have_MG_with_only_PVwind_constraints(m,p)
		add_MG_size_constraints(m,p)
		
		if !isempty(p.techs.gen)
			add_MG_fuel_burn_constraints(m,p)
			add_binMGGenIsOnInTS_constraints(m,p)
		else
			m[:ExpectedMGFuelUsed] = 0
			m[:ExpectedMGFuelCost] = 0
			@constraint(m, [s in p.s.electric_utility.scenarios, tz in p.s.electric_utility.outage_start_timesteps, ts in p.s.electric_utility.outage_timesteps],
				m[:binMGGenIsOnInTS][s, tz, ts] == 0
			)
		end
		
		if p.s.site.min_resil_timesteps > 0
			add_min_hours_crit_ld_met_constraint(m,p)
		end
	end

	#################################  Objective Function   ########################################
	@expression(m, Costs,

		# Variable O&M
		m[:TotalPerUnitProdOMCosts] +

		# Total Generator Fuel Costs
        m[:TotalFuelCosts] +

		# Utility Bill
		m[:TotalElecBill]
	);
	if !isempty(p.s.electric_utility.outage_durations)
		add_to_expression!(Costs, m[:ExpectedOutageCost] + m[:mgTotalTechUpgradeCost] + m[:dvMGStorageUpgradeCost] + m[:ExpectedMGFuelCost])
	end
    #= Note: 0.9999*MinChargeAdder in Objective b/c when TotalMinCharge > (TotalEnergyCharges + TotalDemandCharges + TotalExportBenefit + TotalFixedCharges)
		it is arbitrary where the min charge ends up (eg. could be in TotalDemandCharges or MinChargeAdder).
		0.0001*MinChargeAdder is added back into LCC when writing to results.  =#
	nothing
end


function add_variables!(m::JuMP.AbstractModel, p::MPCInputs)
    @variables m begin
		# dvSize[p.techs.all] >= 0  # System Size of Technology t [kW]
		# dvPurchaseSize[p.techs.all] >= 0  # system kW beyond existing_kw that must be purchased
		dvGridPurchase[p.time_steps] >= 0  # Power from grid dispatched to meet electrical load [kW]
		dvRatedProduction[p.techs.all, p.time_steps] >= 0  # Rated production of technology t [kW]
		dvCurtail[p.techs.all, p.time_steps] >= 0  # [kW]
		dvProductionToStorage[p.s.storage.types, p.techs.all, p.time_steps] >= 0  # Power from technology t used to charge storage system b [kW]
		dvDischargeFromStorage[p.s.storage.types, p.time_steps] >= 0 # Power discharged from storage system b [kW]
		dvGridToStorage[p.s.storage.types, p.time_steps] >= 0 # Electrical power delivered to storage by the grid [kW]
		dvStoredEnergy[p.s.storage.types, 0:p.time_steps[end]] >= 0  # State of charge of storage system b
		# dvStoragePower[p.s.storage.types] >= 0   # Power capacity of storage system b [kW]
		# dvStorageEnergy[p.s.storage.types] >= 0   # Energy capacity of storage system b [kWh]
		dvPeakDemandTOU[p.ratchets, 1:1] >= 0  # Peak electrical power demand during ratchet r [kW]
		dvPeakDemandMonth[p.months] >= 0  # Peak electrical power demand during month m [kW]
		# MinChargeAdder >= 0
	end
	# TODO: tiers in MPC tariffs and variables?

	if !isempty(p.s.electric_tariff.export_bins)
		@variable(m, dvProductionToGrid[p.techs.elec, p.s.electric_tariff.export_bins, p.time_steps] >= 0)
	end

    m[:dvSize] = p.existing_sizes

    m[:dvStoragePower] = p.s.storage.size_kw
    m[:dvStorageEnergy] = p.s.storage.size_kwh
    # not modeling min charges since control does not affect them
    m[:MinChargeAdder] = 0

	if !isempty(p.techs.gen)  # Problem becomes a MILP
		@warn """Adding binary variable to model gas generator. 
				 Some solvers are very slow with integer variables"""
		@variables m begin
			dvFuelUsage[p.techs.gen, p.time_steps] >= 0 # Fuel burned by technology t in each time step
			binGenIsOnInTS[p.techs.gen, p.time_steps], Bin  # 1 If technology t is operating in time step h; 0 otherwise
		end
	end

	if !(p.s.electric_utility.allow_simultaneous_export_import)
		@warn """Adding binary variable to prevent simultaneous grid import/export. 
				 Some solvers are very slow with integer variables"""
		@variable(m, binNoGridPurchases[p.time_steps], Bin)
	end

	if !isempty(p.s.electric_utility.outage_durations) # add dvUnserved Load if there is at least one outage
		@warn """Adding binary variable to model outages. 
				 Some solvers are very slow with integer variables"""
		max_outage_duration = maximum(p.s.electric_utility.outage_durations)
		outage_timesteps = p.s.electric_utility.outage_timesteps
		tZeros = p.s.electric_utility.outage_start_timesteps
		S = p.s.electric_utility.scenarios
		# TODO: currently defining more decision variables than necessary b/c using rectangular arrays, could use dicts of decision variables instead
		@variables m begin # if there is more than one specified outage, there can be more othan one outage start time
			dvUnservedLoad[S, tZeros, outage_timesteps] >= 0 # unserved load not met by system
			dvMGProductionToStorage[p.techs.all, S, tZeros, outage_timesteps] >= 0 # Electricity going to the storage system during each timestep
			dvMGDischargeFromStorage[S, tZeros, outage_timesteps] >= 0 # Electricity coming from the storage system during each timestep
			dvMGRatedProduction[p.techs.all, S, tZeros, outage_timesteps]  # MG Rated Production at every timestep.  Multiply by ProdFactor to get actual energy
			dvMGStoredEnergy[S, tZeros, 0:max_outage_duration] >= 0 # State of charge of the MG storage system
			dvMaxOutageCost[S] >= 0 # maximum outage cost dependent on number of outage durations
			# dvMGTechUpgradeCost[p.techs.all] >= 0
			# dvMGStorageUpgradeCost >= 0
			# dvMGsize[p.techs.all] >= 0
			
			dvMGFuelUsed[p.techs.all, S, tZeros] >= 0
			dvMGMaxFuelUsage[S] >= 0
			dvMGMaxFuelCost[S] >= 0
			dvMGCurtail[p.techs.all, S, tZeros, outage_timesteps] >= 0

			# binMGStorageUsed, Bin # 1 if MG storage battery used, 0 otherwise
			# binMGTechUsed[p.techs.all], Bin # 1 if MG tech used, 0 otherwise
			binMGGenIsOnInTS[S, tZeros, outage_timesteps], Bin
		end
	end
end