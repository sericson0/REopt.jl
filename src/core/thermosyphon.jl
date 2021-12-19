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
    Thermosyphon
struct with inner constructor:
```julia
function Thermosyphon(;
    ground_temp_degF::Real=25,
    effective_conductance_btu_per_degF::Real=141,
    design_active_cooling_rate_kw::Real=0.197,
    structure_heat_to_ground_mmbtu_per_year::Real=5.9
)
```
"""
struct Thermosyphon <: AbstractTech
    ground_temp_degF
    effective_conductance_btu_per_degF
    design_active_cooling_rate_kw
    structure_heat_to_ground_mmbtu_per_year

    function Thermosyphon(;
        ground_temp_degF::Real=25,
        effective_conductance_btu_per_degF::Real=141,
        design_active_cooling_rate_kw::Real=0.197,
        structure_heat_to_ground_mmbtu_per_year::Real=5.9,
        )

        # validate inputs
        invalid_args = String[]
        if !(0 <= effective_conductance_btu_per_degF)
            push!(invalid_args, "effective_conductance_btu_per_degF must satisfy 0 <= effective_conductance_btu_per_degF, got $(effective_conductance_btu_per_degF)")
        end
        if !(0 <= design_active_cooling_rate_kw)
            push!(invalid_args, "design_active_cooling_rate_kw must satisfy 0 <= design_active_cooling_rate_kw, got $(design_active_cooling_rate_kw)")
        end
        if !(0 <= structure_heat_to_ground_mmbtu_per_year)
            push!(invalid_args, "structure_heat_to_ground_mmbtu_per_year must satisfy 0 <= structure_heat_to_ground_mmbtu_per_year, got $(structure_heat_to_ground_mmbtu_per_year)")
        end
        if length(invalid_args) > 0
            error("Invalid argument values: $(invalid_args)")
        end

        new(
            ground_temp_degF,
            effective_conductance_btu_per_degF,
            design_active_cooling_rate_kw,
            structure_heat_to_ground_mmbtu_per_year
        )
    end
end
