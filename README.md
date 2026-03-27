# StatAnalyzer — Julia Statistical Dashboard
### CSC321 Industry-Level Project (with Web GUI)

A full statistical analysis tool written in **Julia** with a professional browser-based GUI powered by **Genie.jl**. Upload any CSV, click Analyze, and instantly see statistics, correlations, and 5 chart types — all in a clean dashboard.

---

## What It Looks Like

A dark-navy dashboard that opens in your browser with:
- **KPI cards** at the top (rows, columns, missing count)
- **4 tabs**: Overview · Statistics · Correlation · Charts
- Clean data tables, color-coded badges, correlation bar indicators
- Inline charts rendered by Julia's Plots.jl

---

## Features

| Feature | Details |
|---|---|
| **File Upload** | Upload any CSV directly from the browser |
| **Sample Data** | One-click load of included student dataset |
| **Overview Tab** | Column types, missing value badges (Clean / Warning / Error) |
| **Statistics Tab** | Mean, Std Dev, Min, Q1, Median, Q3, Max, IQR, Skewness, Kurtosis, CV |
| **Correlation Tab** | Pairwise r values with visual bar indicators + Strength/Direction labels |
| **Charts Tab** | Histograms (w/ mean + median lines), Box plot, Heatmap, Scatter matrix |

---

## Project Structure

```
StatAnalyzer/
├── app.jl                 ← Julia backend (Genie server + all analysis logic)
├── public/
│   └── index.html         ← Frontend dashboard (HTML + CSS + JS, no frameworks)
├── data/
│   └── sample_data.csv    ← 60-row student performance dataset
|   └── mixed_test.csv.    ← Categorical and Numerical dataset
├── output/                ← Auto-created when analysis runs
└── README.md
```

---

## Requirements

- **Julia 1.8+** — https://julialang.org/downloads/
- A modern web browser (Chrome, Firefox, Edge, Safari)

All Julia packages install automatically on first run.

---

## How to Run

```bash
julia app.jl
```

Then open your browser to:
```
http://localhost:8080
```

> ⚠️ **First run** downloads and precompiles packages — takes 3–5 minutes.  
> Subsequent runs start in under 10 seconds.

---

## How to Use

1. Run `julia app.jl` and open `http://localhost:8080`
2. Either click **"Load Sample Data"** to instantly demo the tool, or
3. Click **"Choose CSV file…"** → select your file → click **"Analyze"**
4. Browse the 4 tabs to explore your data

---

## Julia Packages Used

| Package | Purpose |
|---|---|
| `Genie.jl` | Web server, routing, HTTP handling |
| `CSV.jl` | Reading CSV files |
| `DataFrames.jl` | Tabular data manipulation |
| `Statistics` | Built-in: mean, std, median, cor |
| `StatsBase.jl` | Skewness, kurtosis |
| `Plots.jl` + `StatsPlots.jl` | All chart generation |
| `JSON3.jl` | JSON serialization for API responses |
| `Base64` | Encoding plots as inline images |

---

## Why Julia for This?

- **Genie.jl** is a full production web framework 
- Julia's numeric performance means analysis on large CSVs is fast
- `Plots.jl` generates publication-quality charts in a few lines
- The entire backend (server + analysis + plotting) is ~200 lines of clean Julia

---

## Julia Language Features Demonstrated

| Feature | Where |
|---|---|
| Multiple dispatch | `describe_col` accepts any numeric vector type |
| Type annotations | `::String`, `::DataFrame`, `::Matrix{Float64}` |
| Named tuples | Stats returned as structured Dicts |
| Comprehensions | `[c for c in names(df) if ...]` |
| `do` blocks | Route handlers, file I/O |
| String interpolation | Throughout all output formatting |
| Broadcasting | `skipmissing.()`, `Float64.(...)` |
| Macros | Genie's `route()`, `json()`, `html()` |
