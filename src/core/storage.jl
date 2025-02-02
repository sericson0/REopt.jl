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
    Storage

Currently only electric storage is modeled but thermal storage will be added soon.

TODO update this doc string and perhaps the way we define arbitrary storage.

```julia
Base.@kwdef struct ElecStorage <: AbstractStorage
    min_kw::Float64 = 0.0
    max_kw::Float64 = 1.0e4
    min_kwh::Float64 = 0.0
    max_kwh::Float64 = 1.0e6
    internal_efficiency_pct::Float64 = 0.975
    inverter_efficiency_pct::Float64 = 0.96
    rectifier_efficiency_pct::Float64 = 0.96
    soc_min_pct::Float64 = 0.2
    soc_init_pct::Float64 = 0.5
    can_grid_charge::Bool = true
    installed_cost_per_kw::Float64 = 840.0
    installed_cost_per_kwh::Float64 = 420.0
    replace_cost_per_kw::Float64 = 410.0
    replace_cost_per_kwh::Float64 = 200.0
    inverter_replacement_year::Int = 10
    battery_replacement_year::Int = 10
    macrs_option_years::Int = 7
    macrs_bonus_pct::Float64 = 1.0
    macrs_itc_reduction::Float64 = 0.5
    total_itc_pct::Float64 = 0.0
    total_rebate_per_kw::Float64 = 0.0
    total_rebate_per_kwh::Float64 = 0.0
end
```
"""
Base.@kwdef struct ElecStorage <: AbstractStorage
    min_kw::Float64 = 0.0
    max_kw::Float64 = 1.0e4
    min_kwh::Float64 = 0.0
    max_kwh::Float64 = 1.0e6
    internal_efficiency_pct::Float64 = 0.975
    inverter_efficiency_pct::Float64 = 0.96
    rectifier_efficiency_pct::Float64 = 0.96
    soc_min_pct::Float64 = 0.2
    soc_init_pct::Float64 = 0.5
    can_grid_charge::Bool = true
    installed_cost_per_kw::Float64 = 840.0
    installed_cost_per_kwh::Float64 = 420.0
    replace_cost_per_kw::Float64 = 410.0
    replace_cost_per_kwh::Float64 = 200.0
    inverter_replacement_year::Int = 10
    battery_replacement_year::Int = 10
    macrs_option_years::Int = 7
    macrs_bonus_pct::Float64 = 1.0
    macrs_itc_reduction::Float64 = 0.5
    total_itc_pct::Float64 = 0.0
    total_rebate_per_kw::Float64 = 0.0
    total_rebate_per_kwh::Float64 = 0.0
end


struct Storage <: AbstractStorage
    types::Array{Symbol,1}
    raw_inputs::Dict{Symbol, AbstractStorage}
    min_kw::Dict{Symbol, Float64}
    max_kw::Dict{Symbol, Float64}
    min_kwh::Dict{Symbol, Float64}
    max_kwh::Dict{Symbol, Float64}
    charge_efficiency::Dict{Symbol, Float64}
    discharge_efficiency::Dict{Symbol, Float64}
    soc_min_pct::Dict{Symbol, Float64}
    soc_init_pct::Dict{Symbol, Float64}
    installed_cost_per_kw::Dict{Symbol, Float64}
    installed_cost_per_kwh::Dict{Symbol, Float64}
    can_grid_charge::Array{Symbol,1}
    grid_charge_efficiency::Dict{Symbol, Float64}
end


"""
    # function Storage(d::Dict{Symbol,Dict}, f::Financial)

Construct Storage struct from Dict with keys for each storage type (eg. :elec) and values with
    input dicts for each storage type. Note that the REopt inputs are indexed on the storage type.
"""
function Storage(d::Dict, f::Financial)  # nested dict
    types = Symbol[]
    can_grid_charge = Symbol[]
    raw_vals = Dict(zip(fieldnames(Storage), [Any[] for _ in range(1, stop=fieldcount(Storage))]))
    # raw_vals has keys = fieldnames(Storage) and values = arrays of values for each type in types

    for (storage_type, input_dict) in d

        push!(types, storage_type)
        struct_name = string(titlecase(string(storage_type)) * "Storage")  # eg. ElecStorage
        storage_instance = eval(Meta.parse(struct_name * "(;$input_dict...)"))

        if storage_instance.can_grid_charge
            push!(can_grid_charge, storage_type)
        end
        fill_storage_vals!(raw_vals, storage_instance, f)
    end

    storage_args = Dict(
        :types => types, 
        :can_grid_charge => can_grid_charge, 
    )
    d2 = Dict()  # Julia won't let me use storage_args: "unable to check bounds for indices of type Symbol"
    for k in keys(raw_vals)
        d2[k] = Dict(zip(types, raw_vals[k]))
    end

    grid_charge_efficiency = Dict(:elec => convert(Float64, d2[:charge_efficiency][:elec]))

    return Storage(
        storage_args[:types],
        d2[:raw_inputs],
        d2[:min_kw],
        d2[:max_kw],
        d2[:min_kwh],
        d2[:max_kwh],
        d2[:charge_efficiency],
        d2[:discharge_efficiency],
        d2[:soc_min_pct],
        d2[:soc_init_pct],
        d2[:installed_cost_per_kw],
        d2[:installed_cost_per_kwh],
        storage_args[:can_grid_charge],
        grid_charge_efficiency
    )
    # TODO expand for smart thermostat
end


"""
    fill_storage_vals!(d::Dict, s::AbstractStorage, f::Financial)

Fill `d`'s values using `s` and `f`. The dict `d` must have keys equivalent to the fieldnames(Storage)
"""
function fill_storage_vals!(d::Dict, s::AbstractStorage, f::Financial)
    push!(d[:raw_inputs], s)
    push!(d[:min_kw], s.min_kw)
    push!(d[:max_kw], s.max_kw)
    push!(d[:min_kwh], s.min_kwh)
    push!(d[:max_kwh], s.max_kwh)
    push!(d[:soc_min_pct], s.soc_min_pct)
    push!(d[:soc_init_pct], s.soc_init_pct)

    push!(d[:charge_efficiency], s.rectifier_efficiency_pct * s.internal_efficiency_pct^0.5)
    push!(d[:discharge_efficiency], s.inverter_efficiency_pct * s.internal_efficiency_pct^0.5)

    push!(d[:installed_cost_per_kw], effective_cost(;
        itc_basis=s.installed_cost_per_kw,
        replacement_cost=s.replace_cost_per_kw,
        replacement_year=s.inverter_replacement_year,
        discount_rate=f.owner_discount_pct,
        tax_rate=f.owner_tax_pct,
        itc=s.total_itc_pct,
        macrs_schedule = s.macrs_option_years == 7 ? f.macrs_seven_year : f.macrs_five_year,
        macrs_bonus_pct=s.macrs_bonus_pct,
        macrs_itc_reduction = s.macrs_itc_reduction,
        rebate_per_kw = s.total_rebate_per_kw
    ))
    push!(d[:installed_cost_per_kwh], effective_cost(;
        itc_basis=s.installed_cost_per_kwh,
        replacement_cost=s.replace_cost_per_kwh,
        replacement_year=s.inverter_replacement_year,
        discount_rate=f.owner_discount_pct,
        tax_rate=f.owner_tax_pct,
        itc=s.total_itc_pct,
        macrs_schedule=s.macrs_option_years == 7 ? f.macrs_seven_year : f.macrs_five_year,
        macrs_bonus_pct=s.macrs_bonus_pct,
        macrs_itc_reduction = s.macrs_itc_reduction
    ))
    d[:installed_cost_per_kwh][end] -= s.total_rebate_per_kwh
end
