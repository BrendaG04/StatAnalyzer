# StatAnalyzer - Julia Statistical Dashboard

StatAnalyzer is a browser-based statistical analysis app built with Julia and Genie.jl.
Upload a CSV file (or load the built-in sample) to get descriptive stats, association metrics, and plots in a multi-tab dashboard.

## Current Features

- CSV upload from the UI (`/analyze` route)
- One-click sample analysis (`/sample` route, uses `data/mixed_test.csv`)
- Overview table with inferred column type + missing-value percentage/status
- Numeric descriptive statistics:
	count, mean, std dev, min, q1, median, q3, max, iqr, skewness, kurtosis, cv
- Categorical descriptive statistics:
	count, unique count, uniqueness %, mode, top category frequencies
- Association analysis:
	Pearson r (numeric x numeric), Cramer's V (categorical x categorical), correlation ratio eta/eta2 (categorical x numeric)
- Plot generation:
	histogram per numeric column, category-frequency bar plot per categorical column, combined numeric box plot, correlation heatmap, scatter matrix (up to 6 numeric columns)

## Project Structure

```
StatAnalyzerCSC321/
|- app.jl
|- README.md
|- data/
|  |- mixed_test.csv
|  |- sample_data.csv
|- output/
|- public/
|  |- index.html
|  |- css/
|  |  |- app.css
|  |- js/
|     |- app.js
|- src/
|  |- analysis.jl
|  |- routes.jl
```

## Backend Modules

- `app.jl`
	App entrypoint. Ensures required packages are installed, loads modules, registers routes, and starts Genie on port 8080.
- `src/analysis.jl`
	Data loading, column typing, numeric/categorical summaries, association metrics, and plot creation.
- `src/routes.jl`
	HTTP routes for serving static assets and analysis endpoints.

## Requirements

- Julia 1.8+
- A modern browser

Required Julia packages are auto-installed on first run.

## Run

```bash
julia app.jl
```

Then open:

```text
http://localhost:8080
```

## How to Use

1. Start the app with `julia app.jl`.
2. Open `http://localhost:8080`.
3. Choose one of:
	 - Click `Load Sample Data`, or
	 - Select a CSV file and click `Analyze`.
4. Review results in `Overview`, `Statistics`, `Correlation`, and `Charts`.

## Notes

- Missing values are interpreted from values such as `NA`, `N/A`, empty string, `null`, `NULL`, and `None`.
- On first run, package installation and precompilation may take a few minutes.
