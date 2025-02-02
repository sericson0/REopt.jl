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
    add_electric_tariff_results(m::JuMP.AbstractModel, p::REoptInputs, d::Dict; _n="")

Adds the ElectricTariff results to the dictionary passed back from `run_reopt` using the solved model `m` and the `REoptInputs` for node `_n`.
Note: the node number is an empty string if evaluating a single `Site`.

ElectricTariff results:
- `lifecycle_energy_cost` lifecycle cost of energy from the grid in present value, after tax
- `year_one_energy_cost` cost of energy from the grid over the first year
- `lifecycle_demand_cost` lifecycle cost of power from the grid in present value, after tax
- `year_one_demand_cost` cost of power from the grid over the first year
- `lifecycle_fixed_cost` lifecycle fixed cost in present value, after tax
- `year_one_fixed_cost` fixed cost over the first year
- `lifecycle_min_charge_adder` lifecycle minimum charge in present value, after tax
- `year_one_min_charge_adder` minimum charge over the first year
- `year_one_bill` sum of `year_one_energy_cost`, `year_one_demand_cost`, `year_one_fixed_cost`, and `year_one_min_charge_adder`
- `lifecycle_export_benefit` lifecycle export credits in present value, after tax
- `year_one_export_benefit` export credits over the first year
- `lifecycle_coincident_peak_cost` lifecycle coincident peak charge in present value
- `year_one_coincident_peak_cost` coincident peak charge over the first year
"""
function add_electric_tariff_results(m::JuMP.AbstractModel, p::REoptInputs, d::Dict; _n="")
    r = Dict{String, Any}()
    m[Symbol("Year1UtilityEnergy"*_n)] = p.hours_per_timestep * 
        sum(m[Symbol("dvGridPurchase"*_n)][ts, tier] for ts in p.time_steps, tier in 1:p.s.electric_tariff.n_energy_tiers)

    r["lifecycle_energy_cost"] = round(value(m[Symbol("TotalEnergyChargesUtil"*_n)]) * (1 - p.s.financial.offtaker_tax_pct), digits=2)
    r["year_one_energy_cost"] = round(value(m[Symbol("TotalEnergyChargesUtil"*_n)]) / p.pwf_e, digits=2)

    r["lifecycle_demand_cost"] = round(value(m[Symbol("TotalDemandCharges"*_n)]) * (1 - p.s.financial.offtaker_tax_pct), digits=2)
    r["year_one_demand_cost"] = round(value(m[Symbol("TotalDemandCharges"*_n)]) / p.pwf_e, digits=2)
    
    r["lifecycle_fixed_cost"] = round(m[Symbol("TotalFixedCharges"*_n)] * (1 - p.s.financial.offtaker_tax_pct), digits=2)
    r["year_one_fixed_cost"] = round(m[Symbol("TotalFixedCharges"*_n)] / p.pwf_e, digits=0)

    r["lifecycle_min_charge_adder"] = round(value(m[Symbol("MinChargeAdder"*_n)]) * (1 - p.s.financial.offtaker_tax_pct), digits=2)
    r["year_one_min_charge_adder"] = round(value(m[Symbol("MinChargeAdder"*_n)]) / p.pwf_e, digits=2)

    r["year_one_bill"] = r["year_one_energy_cost"] + r["year_one_demand_cost"] +
                                    r["year_one_fixed_cost"]  + r["year_one_min_charge_adder"]
                                
    r["lifecycle_export_benefit"] = -1 * round(value(m[Symbol("TotalExportBenefit"*_n)]) * (1 - p.s.financial.offtaker_tax_pct), digits=2)
    r["year_one_export_benefit"] = -1 * round(value(m[Symbol("TotalExportBenefit"*_n)]) / p.pwf_e, digits=0)

    r["lifecycle_coincident_peak_cost"] = round(value(m[Symbol("TotalCPCharges"*_n)]), digits=2)
    r["year_one_coincident_peak_cost"] = round(r["lifecycle_coincident_peak_cost"] / p.pwf_e, digits=2)
    
    d["ElectricTariff"] = r
    nothing
end


function add_electric_tariff_results(m::JuMP.AbstractModel, p::MPCInputs, d::Dict; _n="")
    r = Dict{String, Any}()
    m[Symbol("energy_purchased"*_n)] = p.hours_per_timestep * 
        sum(m[Symbol("dvGridPurchase"*_n)][ts] for ts in p.time_steps)

    r["energy_cost"] = round(value(m[Symbol("TotalEnergyChargesUtil"*_n)]), digits=2)

    r["demand_cost"] = round(value(m[Symbol("TotalDemandCharges"*_n)]), digits=2)
                                
    r["export_benefit"] = -1 * round(value(m[Symbol("TotalExportBenefit"*_n)]), digits=0)
    
    d["ElectricTariff"] = r
    nothing
end