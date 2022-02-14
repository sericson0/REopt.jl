using Documenter, REopt, JuMP

makedocs(
    sitename="REopt.jl Documentation",
    pages = [
        "Home" => "index.md",
        "REopt" => Any[
            "reopt/examples.md",
            "reopt/inputs.md",
            "reopt/outputs.md",
            "reopt/methods.md"
        ],
        "Model Predictive Control" => Any[
            "mpc/examples.md",
            "mpc/inputs.md",
            "mpc/methods.md",
        ],
        "Developer" => Any[
            "developer/concept.md",
            "developer/organization.md",
            "developer/inputs.md",
            "developer/adding_tech.md"
        ]
    ],
    workdir = joinpath(@__DIR__, "..")
)

deploydocs(
    repo = "github.com/NREL/REopt.jl.git",
)
