


function add_variables!(m::JuMP.AbstractModel, ps::Array{REoptInputs})
	
	dvs_idx_on_techs = String[
		"dvSize",
		"dvPurchaseSize",
	]
	dvs_idx_on_techs_timesteps = String[
        "dvCurtail",
		"dvRatedProduction",
	]
	dvs_idx_on_storagetypes = String[
		"dvStoragePower",
		"dvStorageEnergy",
	]
	dvs_idx_on_storagetypes_timesteps = String[
		"dvDischargeFromStorage",
		"dvGridToStorage",
	]
	for p in ps
		_n = string("_", p.s.site.node)
		for dv in dvs_idx_on_techs
			x = dv*_n
			m[Symbol(x)] = @variable(m, [p.techs.all], base_name=x, lower_bound=0)
		end

		for dv in dvs_idx_on_techs_timesteps
			x = dv*_n
			m[Symbol(x)] = @variable(m, [p.techs.all, p.time_steps], base_name=x, lower_bound=0)
		end

		for dv in dvs_idx_on_storagetypes
			x = dv*_n
			m[Symbol(x)] = @variable(m, [p.s.storage.types], base_name=x, lower_bound=0)
		end

		for dv in dvs_idx_on_storagetypes_timesteps
			x = dv*_n
			m[Symbol(x)] = @variable(m, [p.s.storage.types, p.time_steps], base_name=x, lower_bound=0)
		end

		dv = "dvGridPurchase"*_n
		m[Symbol(dv)] = @variable(m, [p.time_steps], base_name=dv, lower_bound=0)

		dv = "dvPeakDemandTOU"*_n
		m[Symbol(dv)] = @variable(m, [p.ratchets, 1], base_name=dv, lower_bound=0)

		dv = "dvPeakDemandMonth"*_n
		m[Symbol(dv)] = @variable(m, [p.months, 1], base_name=dv, lower_bound=0)

		dv = "dvProductionToStorage"*_n
		m[Symbol(dv)] = @variable(m, [p.s.storage.types, p.techs.all, p.time_steps], base_name=dv, lower_bound=0)

		dv = "dvStoredEnergy"*_n
		m[Symbol(dv)] = @variable(m, [p.s.storage.types, 0:p.time_steps[end]], base_name=dv, lower_bound=0)

		dv = "MinChargeAdder"*_n
		m[Symbol(dv)] = @variable(m, base_name=dv, lower_bound=0)

        if !isempty(p.s.electric_tariff.export_bins)
            dv = "dvProductionToGrid"*_n
            m[Symbol(dv)] = @variable(m, [p.techs.elec, p.s.electric_tariff.export_bins, p.time_steps], base_name=dv, lower_bound=0)
        end

		ex_name = "TotalTechCapCosts"*_n
		m[Symbol(ex_name)] = @expression(m, p.third_party_factor *
			sum( p.cap_cost_slope[t] * m[Symbol("dvPurchaseSize"*_n)][t] for t in p.techs.all ) 
		)

		ex_name = "TotalStorageCapCosts"*_n
		m[Symbol(ex_name)] = @expression(m, p.third_party_factor * 
			sum(  p.s.storage.installed_cost_per_kw[b] * m[Symbol("dvStoragePower"*_n)][b] 
				+ p.s.storage.installed_cost_per_kwh[b] * m[Symbol("dvStorageEnergy"*_n)][b] for b in p.s.storage.types )
		)

		ex_name = "TotalPerUnitSizeOMCosts"*_n
		m[Symbol(ex_name)] = @expression(m, p.third_party_factor * p.pwf_om * 
			sum( p.om_cost_per_kw[t] * m[Symbol("dvSize"*_n)][t] for t in p.techs.all ) 
		)

        ex_name = "TotalPerUnitProdOMCosts"*_n
		m[Symbol(ex_name)] = 0
	
		add_elec_utility_expressions(m, p; _n=_n)
	
		#################################  Objective Function   ########################################
		m[Symbol("Costs"*_n)] = @expression(m,
			# Capital Costs
			m[Symbol("TotalTechCapCosts"*_n)] + m[Symbol("TotalStorageCapCosts"*_n)] +  
			
			## Fixed O&M, tax deductible for owner
			m[Symbol("TotalPerUnitSizeOMCosts"*_n)] * (1 - p.s.financial.owner_tax_pct) +
	
			# Utility Bill, tax deductible for offtaker, including export benefit
			m[Symbol("TotalElecBill"*_n)] * (1 - p.s.financial.offtaker_tax_pct)
		);
    end
    add_bounds(m, ps)
end


"""
add non-negative bounds to decision variables
"""
function add_bounds(m::JuMP.AbstractModel, ps::Array{REoptInputs})
	
	dvs_idx_on_techs = String[
		"dvSize",
		"dvPurchaseSize",
	]
	dvs_idx_on_techs_timesteps = String[
        "dvCurtail",
		"dvRatedProduction",
	]
	dvs_idx_on_storagetypes = String[
		"dvStoragePower",
		"dvStorageEnergy",
	]
	dvs_idx_on_storagetypes_timesteps = String[
		"dvDischargeFromStorage",
		"dvGridToStorage",
	]
	for p in ps
        _n = string("_", p.s.site.node)
        
		for dv in dvs_idx_on_techs
			x = dv*_n
			@constraint(m, [tech in p.techs.all], -m[Symbol(x)][tech] ≤ 0 )
		end

		for dv in dvs_idx_on_techs_timesteps
			x = dv*_n
            @constraint(m, [tech in p.techs.all, ts in p.time_steps], 
                -m[Symbol(x)][tech, ts] ≤ 0
            )
		end

		for dv in dvs_idx_on_storagetypes
			x = dv*_n
            @constraint(m, [b in p.s.storage.types], 
                -m[Symbol(x)][b] ≤ 0
            )
		end

		for dv in dvs_idx_on_storagetypes_timesteps
			x = dv*_n
            @constraint(m, [b in p.s.storage.types, ts in p.time_steps], 
                -m[Symbol(x)][b, ts] ≤ 0
            )
		end

		dv = "dvGridPurchase"*_n
		@constraint(m, [ts in p.time_steps], -m[Symbol(dv)][ts] ≤ 0)

		dv = "dvPeakDemandTOU"*_n
		@constraint(m, [r in p.ratchets], -m[Symbol(dv)][r, 1] ≤ 0)

		dv = "dvPeakDemandMonth"*_n
		@constraint(m, [mth in p.months], -m[Symbol(dv)][mth, 1] ≤ 0)

		dv = "dvProductionToStorage"*_n
        @constraint(m, [b in p.s.storage.types, tech in p.techs.all, ts in p.time_steps], 
            -m[Symbol(dv)][b, tech, ts] ≤ 0
        )

		dv = "dvStoredEnergy"*_n
        @constraint(m, [b in p.s.storage.types, ts in 0:p.time_steps[end]], 
            -m[Symbol(dv)][b, ts] ≤ 0
        )

		dv = "MinChargeAdder"*_n
		@constraint(m, -m[Symbol(dv)] ≤ 0)
    end
end


function build_reopt!(m::JuMP.AbstractModel, ps::Array{REoptInputs})
    add_variables!(m, ps)
    @warn "Outages are not currently modeled in multinode mode."
    @warn "Diesel generators are not currently modeled in multinode mode."
    for p in ps
        _n = string("_", p.s.site.node)

        for b in p.s.storage.types
            if p.s.storage.max_kw[b] == 0 || p.s.storage.max_kwh[b] == 0
                @constraint(m, [ts in p.time_steps], m[Symbol("dvStoredEnergy"*_n)][b, ts] == 0)
                @constraint(m, m[Symbol("dvStorageEnergy"*_n)][b] == 0)
                @constraint(m, m[Symbol("dvStoragePower"*_n)][b] == 0)
                @constraint(m, [t in p.techs.elec, ts in p.time_steps_with_grid],
                            m[Symbol("dvProductionToStorage"*_n)][b, t, ts] == 0)
                @constraint(m, [ts in p.time_steps], m[Symbol("dvDischargeFromStorage"*_n)][b, ts] == 0)
                @constraint(m, [ts in p.time_steps], m[Symbol("dvGridToStorage"*_n)][b, ts] == 0)
            else
                add_storage_size_constraints(m, p, b; _n=_n)
                add_storage_dispatch_constraints(m, p, b; _n=_n)
            end
        end

        if any(max_kw->max_kw > 0, (p.s.storage.max_kw[b] for b in p.s.storage.types))
            add_storage_sum_constraints(m, p; _n=_n)
        end
    
        add_production_constraints(m, p; _n=_n)
    
        if !isempty(p.techs.all)
            add_tech_size_constraints(m, p; _n=_n)
            if !isempty(p.techs.no_curtail)
                add_no_curtail_constraints(m, p; _n=_n)
            end
        end
    
        add_elec_load_balance_constraints(m, p; _n=_n)
    
        if !isempty(p.s.electric_tariff.export_bins)
            add_export_constraints(m, p; _n=_n)
        end
    
        if !isempty(p.s.electric_tariff.monthly_demand_rates)
            add_monthly_peak_constraint(m, p; _n=_n)
        end
    
        if !isempty(p.s.electric_tariff.tou_demand_ratchet_timesteps)
            add_tou_peak_constraint(m, p; _n=_n)
        end

		if !(p.s.electric_utility.allow_simultaneous_export_import) & !isempty(p.s.electric_tariff.export_bins)
			add_simultaneous_export_import_constraint(m, p; _n=_n)
		end

        if p.s.electric_tariff.demand_lookback_percent > 0
            add_demand_lookback_constraints(m, p; _n=_n)
        end

        if !isempty(p.s.electric_tariff.coincpeak_periods)
            add_coincident_peak_charge_constraints(m, p; _n=_n)
        end
    
    end
end


function add_objective!(m::JuMP.AbstractModel, ps::Array{REoptInputs})
	if !(any(p.s.settings.add_soc_incentive for p in ps))
		@objective(m, Min, sum(m[Symbol(string("Costs_", p.s.site.node))] for p in ps))
	else # Keep SOC high
		@objective(m, Min, sum(m[Symbol(string("Costs_", p.s.site.node))] for p in ps)
        - sum(sum(m[Symbol(string("dvStoredEnergy_", p.s.site.node))][:elec, ts] 
            for ts in p.time_steps) for p in ps) / (8760. / ps[1].hours_per_timestep))
	end  # TODO need to handle different hours_per_timestep?
	nothing
end


function run_reopt(m::JuMP.AbstractModel, ps::Array{REoptInputs})

	build_reopt!(m, ps)

	add_objective!(m, ps)

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
        @warn "REopt solved with " termination_status(m), ", returning the model."
        return m
	end
	@info "REopt solved with " termination_status(m)
	@info "Solving took $(opt_time) seconds."
    
	tstart = time()
	results = reopt_results(m, ps)
	time_elapsed = time() - tstart
	@info "Total results processing took $(round(time_elapsed, digits=3)) seconds."
	results["status"] = status
	results["solver_seconds"] = opt_time
	return results
end


function reopt_results(m::JuMP.AbstractModel, ps::Array{REoptInputs})
	# TODO address Warning: The addition operator has been used on JuMP expressions a large number of times.
	results = Dict{Union{Int, String}, Any}()
	for p in ps
		results[p.s.site.node] = reopt_results(m, p; _n=string("_", p.s.site.node))
	end
	return results
end

