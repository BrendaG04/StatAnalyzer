# ============================================================
#  StatAnalyzer — Julia Web Dashboard
#  Powered by Genie.jl
# ============================================================

using Pkg

for pkg in ["Genie", "CSV", "DataFrames", "Statistics", "StatsBase",
            "Plots", "StatsPlots", "JSON3", "HTTP"]
    if !haskey(Pkg.project().dependencies, pkg)
        println("📦 Installing $pkg...")
        Pkg.add(pkg)
    end
end

using Genie, Genie.Router, Genie.Renderer.Html, Genie.Renderer.Json
using CSV, DataFrames, Statistics, StatsBase
using Plots, StatsPlots
using JSON3
using HTTP
using Base64
using Printf, Dates

gr()

const OUTPUT_DIR = joinpath(@__DIR__, "output")
mkpath(OUTPUT_DIR)

# ============================================================
#  CORE ANALYSIS LOGIC
# ============================================================

function load_df(filepath::String)
    CSV.read(filepath, DataFrame;
             missingstring = ["NA","N/A","","null","NULL","None"])
end

function col_overview(df::DataFrame)
    map(names(df)) do col
        T      = string(nonmissingtype(eltype(df[!, col])))
        n_miss = count(ismissing, df[!, col])
        pct    = round(n_miss / nrow(df) * 100; digits=1)
        Dict("name"=>col, "type"=>T, "missing"=>n_miss, "pct"=>pct)
    end
end

function numeric_cols(df::DataFrame)
    [c for c in names(df) if nonmissingtype(eltype(df[!, c])) <: Number &&
                            !(nonmissingtype(eltype(df[!, c])) <: Bool)]
end

function categorical_cols(df::DataFrame; max_levels::Int=20, max_ratio::Float64=0.30)
    cols = String[]
    for c in names(df)
        data = df[!, c]
        T = nonmissingtype(eltype(data))
        clean = collect(skipmissing(data))
        isempty(clean) && continue

        if T <: AbstractString || T <: Bool
            push!(cols, c)
        elseif T <: Number
            u = length(unique(clean))
            ratio = u / length(clean)
            if u >= 2 && u <= max_levels && ratio <= max_ratio
                push!(cols, c)
            end
        end
    end
    cols
end

function describe_col(data)
    clean = collect(Float64, skipmissing(data))
    n = length(clean)
    n == 0 && return nothing
    Dict(
        "n"       => n,
        "mean"    => round(mean(clean);       digits=4),
        "std"     => round(std(clean);        digits=4),
        "min"     => round(minimum(clean);    digits=4),
        "q1"      => round(quantile(clean,.25); digits=4),
        "median"  => round(median(clean);     digits=4),
        "q3"      => round(quantile(clean,.75); digits=4),
        "max"     => round(maximum(clean);    digits=4),
        "iqr"     => round(quantile(clean,.75)-quantile(clean,.25); digits=4),
        "skew"    => n>2 ? round(skewness(clean); digits=4) : "N/A",
        "kurt"    => n>3 ? round(kurtosis(clean); digits=4) : "N/A",
        "cv"      => round(std(clean)/abs(mean(clean))*100; digits=2)
    )
end

function describe_categorical_col(data)
    vals = String[]
    for v in skipmissing(data)
        if v isa AbstractString
            s = strip(String(v))
            isempty(s) && continue
            push!(vals, s)
        else
            push!(vals, string(v))
        end
    end

    n = length(vals)
    n == 0 && return nothing

    freq = countmap(vals)
    sorted = sort(collect(freq), by = x -> (-x[2], x[1]))
    top_pairs = first(sorted, min(10, length(sorted)))
    mode_value = first(sorted)[1]

    Dict(
        "n" => n,
        "unique" => length(freq),
        "unique_pct" => round(length(freq) / n * 100; digits=2),
        "mode" => mode_value,
        "top" => [
            Dict(
                "value" => v,
                "count" => cnt,
                "pct" => round(cnt / n * 100; digits=2)
            ) for (v, cnt) in top_pairs
        ]
    )
end

function build_cor_matrix(df, cols)
    n = length(cols)
    mat = Matrix{Float64}(undef, n, n)
    for i in 1:n, j in 1:n
        x = df[!, cols[i]]
        y = df[!, cols[j]]
        pairs = [(Float64(x[k]), Float64(y[k])) for k in eachindex(x)
                 if !ismissing(x[k]) && !ismissing(y[k])]
        m = length(pairs)
        if m > 1
            xv = first.(pairs)
            yv = last.(pairs)
            mat[i,j] = cor(xv, yv)
        else
            mat[i,j] = 0.0
        end
    end
    mat
end

function plot_to_b64(p)
    path = tempname() * ".png"
    savefig(p, path)
    data = read(path)
    rm(path)
    "data:image/png;base64," * base64encode(data)
end

function make_histogram(df, col, stats)
    clean = collect(skipmissing(df[!, col]))
    p = histogram(clean;
        title=col, xlabel=col, ylabel="Frequency",
        color=:steelblue, alpha=0.75, linecolor=:white,
        legend=:topright, label="",
        titlefontsize=13, size=(620,370))
    vline!([stats["mean"]]; color=:crimson, lw=2.5, ls=:dash, label="Mean")
    vline!([stats["median"]]; color=:orange, lw=2, ls=:dot, label="Median")
    plot_to_b64(p)
end

function make_boxplot(df, cols)
    vecs = [collect(skipmissing(df[!, c])) for c in cols]
    p = boxplot(cols, vecs;
        title="Box Plot — All Numeric Columns",
        ylabel="Value", color=:teal, alpha=0.7,
        legend=false, size=(max(600, 170*length(cols)), 420))
    plot_to_b64(p)
end

function make_heatmap(cor_mat, cols)
    labels = [c[1:min(10,length(c))] for c in cols]
    p = heatmap(labels, labels, cor_mat;
        title="Correlation Heatmap",
        color=:RdBu, clims=(-1,1),
        aspect_ratio=:equal, size=(520,490),
        xrotation=30, titlefontsize=13)
    plot_to_b64(p)
end

function make_scatter(df, cols)
    n = length(cols)
    grid_plots = []
    for i in 1:n, j in 1:n
        xi = Float64.(collect(skipmissing(df[!, cols[i]])))
        xj = Float64.(collect(skipmissing(df[!, cols[j]])))
        m  = min(length(xi), length(xj))
        if i == j
            push!(grid_plots,
                histogram(xi; xlabel=cols[i], ylabel="", legend=false,
                          color=:steelblue, alpha=0.6, title=cols[i],
                          titlefontsize=9))
        else
            push!(grid_plots,
                scatter(xi[1:m], xj[1:m];
                        xlabel=cols[i], ylabel=cols[j],
                        legend=false, color=:purple, alpha=0.5,
                        markersize=2.5))
        end
    end
    p = plot(grid_plots...; layout=(n,n),
             size=(260*n, 230*n))
    plot_to_b64(p)
end

function make_categorical_barplot(stat, col)
    top = stat["top"]
    vals = [item["value"] for item in top]
    counts = [item["count"] for item in top]
    labels = [length(v) > 22 ? string(first(v, 22), "...") : v for v in vals]

    p = bar(labels, counts;
        title="Category Frequency — $col", xlabel="Category", ylabel="Count",
        color=:teal, alpha=0.8, legend=false,
        xrotation=28, size=(620,370))
    plot_to_b64(p)
end

# ── Full analysis payload ─────────────────────────────────────
function run_analysis(filepath::String)
    df      = load_df(filepath)
    ncols   = numeric_cols(df)
    ccols   = categorical_cols(df)
    corr_cols = [c for c in ncols if !(c in ccols)]
    stats   = Dict(c => describe_col(df[!, c]) for c in ncols)
    cat_stats = Dict(c => describe_categorical_col(df[!, c]) for c in ccols)
    cor_mat = length(corr_cols) >= 2 ? build_cor_matrix(df, corr_cols) : nothing

    plots = Dict{String,String}()
    for c in ncols
        stats[c] !== nothing && (plots["hist_$c"] = make_histogram(df, c, stats[c]))
    end
    for c in ccols
        cat_stats[c] !== nothing && (plots["cat_$c"] = make_categorical_barplot(cat_stats[c], c))
    end
    length(ncols) >= 1 && (plots["boxplot"] = make_boxplot(df, ncols))
    if cor_mat !== nothing
        plots["heatmap"]  = make_heatmap(cor_mat, corr_cols)
        length(corr_cols) >= 2 && length(corr_cols) <= 6 &&
            (plots["scatter"] = make_scatter(df, corr_cols))
    end

    # Correlation table rows
    cor_rows = []
    if cor_mat !== nothing
        n = length(corr_cols)
        for i in 1:n, j in (i+1):n
            x = df[!, corr_cols[i]]
            y = df[!, corr_cols[j]]
            pair_n = count(k -> !ismissing(x[k]) && !ismissing(y[k]), eachindex(x))
            v = round(cor_mat[i,j]; digits=3)
            push!(cor_rows, Dict("a"=>corr_cols[i],"b"=>corr_cols[j],"r"=>v,
                "n" => pair_n,
                "strength" => abs(v)>=0.7 ? "Strong" :
                              abs(v)>=0.4 ? "Moderate" : "Weak",
                "dir"      => v>0 ? "Positive" : v<0 ? "Negative" : "None"))
        end
    end

    Dict(
        "rows"      => nrow(df),
        "cols"      => ncol(df),
        "overview"  => col_overview(df),
        "stats"     => stats,
        "numeric"   => ncols,
        "categorical" => ccols,
        "corr_numeric" => corr_cols,
        "cat_stats" => cat_stats,
        "cor_rows"  => cor_rows,
        "plots"     => plots,
        "filename"  => basename(filepath)
    )
end

# ============================================================
#  ROUTES
# ============================================================

route("/") do
    raw = read(joinpath(@__DIR__, "public", "index.html"))
    HTTP.Response(200, ["Content-Type" => "text/html; charset=utf-8"], raw)
end

# Upload + analyse endpoint
route("/analyze", method=POST) do
    files = Genie.Requests.filespayload()

    local filepath
    if haskey(files, "csvfile") && !isempty(files["csvfile"].data)
        tmp = tempname() * ".csv"
        write(tmp, files["csvfile"].data)
        filepath = tmp
    else
        filepath = joinpath(@__DIR__, "data", "mixed_test.csv")
    end

    try
        result = run_analysis(filepath)
        json(result)
    catch e
        Genie.Requests.header("Content-Type", "application/json")
        json(Dict("error" => string(e)))
    end
end

# Serve sample data directly
route("/sample") do
    json(run_analysis(joinpath(@__DIR__, "data", "mixed_test.csv")))
end

# ============================================================
#  START SERVER
# ============================================================

Genie.config.run_as_server = true
Genie.config.server_port   = 8080

println("\n" * "="^55)
println("  StatAnalyzer — Julia Statistical Dashboard")
println("  Open your browser: http://localhost:8080")
println("="^55 * "\n")

up(8080; async=false)
