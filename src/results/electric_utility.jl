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
    add_electric_utility_results(m::JuMP.AbstractModel, p::REoptInputs, d::Dict; _n="")

Adds the ElectricUtility results to the dictionary passed back from `run_reopt` using the solved model `m` and the `REoptInputs` for node `_n`.
Note: the node number is an empty string if evaluating a single `Site`.

ElectricUtility results:
- `year_one_energy_supplied_kwh` Total energy supplied from the grid in year one.
- `year_one_to_load_series_kw` Vector of powers drawn from the grid to serve load in year one.
- `year_one_to_battery_series_kw` Vector of powers drawn from the grid to charge the battery in year one.
"""
function add_electric_utility_results(m::JuMP.AbstractModel, p::AbstractInputs, d::Dict; _n="")
    r = Dict{String, Any}()

    Year1UtilityEnergy = p.hours_per_timestep * sum(m[Symbol("dvGridPurchase"*_n)][ts, tier] 
        for ts in p.time_steps, tier in p.s.electric_tariff.n_energy_tiers)
    r["year_one_energy_supplied_kwh"] = round(value(Year1UtilityEnergy), digits=2)

    GridToLoad = (sum(m[Symbol("dvGridPurchase"*_n)][ts, tier] for tier in p.s.electric_tariff.n_energy_tiers) 
                  - sum(m[Symbol("dvGridToStorage"*_n)][b, ts] for b in p.s.storage.types) 
                  for ts in p.time_steps)
    r["year_one_to_load_series_kw"] = round.(value.(GridToLoad), digits=3)

    GridToBatt = (sum(m[Symbol("dvGridToStorage"*_n)][b, ts] for b in p.s.storage.types) 
				  for ts in p.time_steps)
    r["year_one_to_battery_series_kw"] = round.(value.(GridToBatt), digits=3)

    d["ElectricUtility"] = r
    nothing
end


function add_electric_utility_results(m::JuMP.AbstractModel, p::MPCInputs, d::Dict; _n="")
    r = Dict{String, Any}()

    Year1UtilityEnergy = p.hours_per_timestep * 
        sum(m[Symbol("dvGridPurchase"*_n)][ts, tier] for ts in p.time_steps, 
                                                         tier in p.s.electric_tariff.n_energy_tiers)
    r["energy_supplied_kwh"] = round(value(Year1UtilityEnergy), digits=2)

    if p.s.storage.size_kw[:elec] > 0
        GridToBatt = @expression(m, [ts in p.time_steps], 
            sum(m[Symbol("dvGridToStorage"*_n)][b, ts] for b in p.s.storage.types) 
		)
        r["to_battery_series_kw"] = round.(value.(GridToBatt), digits=3).data
    else
        GridToBatt = zeros(length(p.time_steps))
    end
    GridToLoad = @expression(m, [ts in p.time_steps], 
        sum(m[Symbol("dvGridPurchase"*_n)][ts, tier] for tier in p.s.electric_tariff.n_energy_tiers) - 
        GridToBatt[ts]
    )
    r["to_load_series_kw"] = round.(value.(GridToLoad), digits=3).data

    d["ElectricUtility"] = r
    nothing
end