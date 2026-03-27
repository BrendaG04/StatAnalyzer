module StatAnalyzerRoutes

using Genie, Genie.Router, Genie.Renderer.Json
using HTTP

function register_routes(base_dir::String, run_analysis_fn::Function)
    route("/") do
        raw = read(joinpath(base_dir, "public", "index.html"))
        HTTP.Response(200, ["Content-Type" => "text/html; charset=utf-8"], raw)
    end

    route("/css/app.css") do
        raw = read(joinpath(base_dir, "public", "css", "app.css"))
        HTTP.Response(200, ["Content-Type" => "text/css; charset=utf-8"], raw)
    end

    route("/js/app.js") do
        raw = read(joinpath(base_dir, "public", "js", "app.js"))
        HTTP.Response(200, ["Content-Type" => "application/javascript; charset=utf-8"], raw)
    end

    route("/analyze", method=POST) do
        files = Genie.Requests.filespayload()

        local filepath
        if haskey(files, "csvfile") && !isempty(files["csvfile"].data)
            tmp = tempname() * ".csv"
            write(tmp, files["csvfile"].data)
            filepath = tmp
        else
            filepath = joinpath(base_dir, "data", "mixed_test.csv")
        end

        try
            result = run_analysis_fn(filepath)
            json(result)
        catch e
            Genie.Requests.header("Content-Type", "application/json")
            json(Dict("error" => string(e)))
        end
    end

    route("/sample") do
        json(run_analysis_fn(joinpath(base_dir, "data", "mixed_test.csv")))
    end
end

export register_routes

end
