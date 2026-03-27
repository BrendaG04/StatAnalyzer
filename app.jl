# ============================================================
#  StatAnalyzer — Julia Web Dashboard
#  Powered by Genie.jl
# ============================================================

using Pkg

for pkg in ["Genie", "CSV", "DataFrames", "Statistics", "StatsBase",
            "Plots", "StatsPlots", "HTTP"]
    if !haskey(Pkg.project().dependencies, pkg)
        println("📦 Installing $pkg...")
        Pkg.add(pkg)
    end
end

using Genie

include(joinpath(@__DIR__, "src", "analysis.jl"))
include(joinpath(@__DIR__, "src", "routes.jl"))

using .StatAnalyzerAnalysis
using .StatAnalyzerRoutes

register_routes(@__DIR__, run_analysis)

Genie.config.run_as_server = true
Genie.config.server_port   = 8080

println("\n" * "="^55)
println("  StatAnalyzer — Julia Statistical Dashboard")
println("  Open your browser: http://localhost:8080")
println("="^55 * "\n")

up(8080; async=false)
