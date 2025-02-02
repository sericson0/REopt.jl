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
    Financial

Financial data struct with inner constructor:
```julia
function Financial(;
    om_cost_escalation_pct::Float64 = 0.025,
    elec_cost_escalation_pct::Float64 = 0.023,
    boiler_fuel_cost_escalation_pct::Float64
    chp_fuel_cost_escalation_pct::Float64    
    offtaker_tax_pct::Float64 = 0.26,
    offtaker_discount_pct = 0.083,
    third_party_ownership::Bool = false,
    owner_tax_pct::Float64 = 0.26,
    owner_discount_pct::Float64 = 0.083,
    analysis_years::Int = 25,
    value_of_lost_load_per_kwh::Union{Array{R,1}, R} where R<:Real = 1.00,
    microgrid_upgrade_cost_pct::Float64 = 0.3,
    macrs_five_year::Array{Float64,1} = [0.2, 0.32, 0.192, 0.1152, 0.1152, 0.0576],  # IRS pub 946
    macrs_seven_year::Array{Float64,1} = [0.1429, 0.2449, 0.1749, 0.1249, 0.0893, 0.0892, 0.0893, 0.0446]
)
```

!!! note
    When `third_party_ownership` is `false` the offtaker's discount and tax percentages are used throughout the model:
    ```julia
        if !third_party_ownership
            owner_tax_pct = offtaker_tax_pct
            owner_discount_pct = offtaker_discount_pct
        end
    ```
"""
struct Financial
    om_cost_escalation_pct::Float64
    elec_cost_escalation_pct::Float64
    boiler_fuel_cost_escalation_pct::Float64
    chp_fuel_cost_escalation_pct::Float64
    offtaker_tax_pct::Float64
    offtaker_discount_pct
    third_party_ownership::Bool
    owner_tax_pct::Float64
    owner_discount_pct::Float64
    analysis_years::Int
    value_of_lost_load_per_kwh::Union{Array{R,1}, R} where R<:Real
    microgrid_upgrade_cost_pct::Float64
    macrs_five_year::Array{Float64,1}
    macrs_seven_year::Array{Float64,1}

    function Financial(;
        om_cost_escalation_pct::Float64 = 0.025,
        elec_cost_escalation_pct::Float64 = 0.023,
        boiler_fuel_cost_escalation_pct::Float64 = 0.034,
        chp_fuel_cost_escalation_pct::Float64 = 0.034,
        offtaker_tax_pct::Float64 = 0.26,
        offtaker_discount_pct = 0.083,
        third_party_ownership::Bool = false,
        owner_tax_pct::Float64 = 0.26,
        owner_discount_pct::Float64 = 0.083,
        analysis_years::Int = 25,
        value_of_lost_load_per_kwh::Union{Array{R,1}, R} where R<:Real = 1.00,
        microgrid_upgrade_cost_pct::Float64 = 0.3,
        macrs_five_year::Array{Float64,1} = [0.2, 0.32, 0.192, 0.1152, 0.1152, 0.0576],  # IRS pub 946
        macrs_seven_year::Array{Float64,1} = [0.1429, 0.2449, 0.1749, 0.1249, 0.0893, 0.0892, 0.0893, 0.0446]
    )
        if !third_party_ownership
            owner_tax_pct = offtaker_tax_pct
            owner_discount_pct = offtaker_discount_pct
        end

        return new(
            om_cost_escalation_pct,
            elec_cost_escalation_pct,
            boiler_fuel_cost_escalation_pct,
            chp_fuel_cost_escalation_pct,
            offtaker_tax_pct,
            offtaker_discount_pct,
            third_party_ownership,
            owner_tax_pct,
            owner_discount_pct,
            analysis_years,
            value_of_lost_load_per_kwh,
            microgrid_upgrade_cost_pct,
            macrs_five_year,
            macrs_seven_year
        )
    end
end