using Plots
using Plots: plot
using StatsBase
using Distributions
using DataFrames
using Measures
using Serialization
Plots.default(fontfamily = ("Times Roman"))# titlefont = ("Times Roman"), legendfont = ("Times Roman"))
gr()


struct LineSpec
    title::String
    label::String
    color::String
    sp::String
    ylim::Tuple{Float64, Float64}
end

function LineSpec(title::String, label::String, color::String, col::String)
    LineSpec(title, label, color, col, (0, 300))
end

FSIZE = 20


function plotspec(df::DataFrame, spec::LineSpec,
                  line_alpha::Float64, ribbon_alpha::Float64,
                  dolegend::Bool, p=nothing; kwargs...)
    label = dolegend ? spec.label : ""
    lows = df[!, "$(spec.sp)-lower"]
    meds = df[!, "$(spec.sp)-med"]
    ups  = df[!, "$(spec.sp)-upper"]

    graph_lows = Vector{Float64}()
    graph_meds = Vector{Float64}()
    graph_ups = Vector{Float64}()
    for (low, med, up) in zip(lows, meds, ups)
        push!(graph_lows, med - low)
        push!(graph_meds, med)
        push!(graph_ups, up - med)
    end
    if p === nothing
        plot(1:length(graph_meds), graph_meds, ribbon=(graph_lows, graph_ups),
              ylim=spec.ylim, xticks=([0, 12500, 25000]), label=label,
              ylabelfontsize=FSIZE,
              xlabelfontsize=FSIZE,
              tickfontsize=FSIZE - 4,
                 legendfontsize=FSIZE - 8,
                top_margin=0mm, 
                bottom_margin=0mm, 
                left_margin=0mm, 
                right_margin=0mm, 
              title = spec.title,
              titlefontsize=FSIZE+1,
              xformatter=:plain, color=spec.color,
              linealpha=line_alpha, fillalpha=ribbon_alpha, grid=true; kwargs...)
    else
        plot(p, 1:length(graph_meds), graph_meds, ribbon=(graph_lows, graph_ups),
              ylabelfontsize=FSIZE,
              xlabelfontsize=FSIZE,
              tickfontsize=FSIZE - 4,
                 legendfontsize=FSIZE - 8,
                top_margin=0mm, 
                bottom_margin=0mm, 
                left_margin=0mm, 
                right_margin=0mm, 
              title=spec.title, 
              titlefontsize=FSIZE + 1,
              ylim=spec.ylim, xticks=([0, 12500, 25000]), label=label,
              xformatter=:plain, color=spec.color,
              linealpha=line_alpha, fillalpha=ribbon_alpha, grid=true; kwargs...)
    end

end


function doplot(df::DataFrame, specs::Vector{LineSpec}; kwargs...)
    p = plotspec(df, specs[1], 0.0, 0.15, false, nothing; kwargs...)
    for spec in specs[2:end]
        p = plotspec(df, spec, 0.0, 0.15, false, p; kwargs...)
    end
    for spec in specs[1:end]
        p = plotspec(df, spec, 0.99, 0.0, true, p; kwargs...)
    end
    #annotate!(12500, specs[1].ylim[2] - 30, text(specs[1].title))
    p
end

function plot_eco_geno(
    df::DataFrame, linespecs::Vector{LineSpec},
    xticks::Vector{Int} = [0, 25000, 50000],
    yticks::Vector{Int} = [0, 50, 100, 150, 200, 250, 300]
)
    legend = :topleft
    xticks = (xticks)
    xlabel = "Generation"
    yticks = (yticks)
    ylabel = "Complexity"
    xformatter = :plain
    yformatter = :plain
    doplot(
        df, linespecs;
        legend = legend,
        xticks = xticks, yticks = yticks,
        xlabel = xlabel, ylabel = ylabel,
        xformatter = xformatter, yformatter = yformatter
    )
end

function plot_eco_mingeno(
    df::DataFrame, linespecs::Vector{LineSpec},
    xticks::Vector{Int} = [0, 25000, 50000],
    yticks::Vector{Int} = [0, 50, 100, 150, 200, 250, 300]
)

    legend = false
    xticks = (xticks)
    xlabel = "Generation"
    yticks = (yticks)
    ylabel = ""
    xformatter = :plain
    yformatter = (y) -> ""
    doplot(
        df, linespecs;
        legend = legend,
        xticks = xticks, yticks = yticks,
        xlabel = xlabel, ylabel = ylabel,
        xformatter = xformatter, yformatter = yformatter
    )
end

function plot_control()
    df = deserialize("counts/ctrl.jls")
    geno1 = LineSpec("Control-Geno", "ctrl1", "red", "ctrl1-geno")
    geno2 = LineSpec("Control-Geno", "ctrl2", "blue", "ctrl2-geno")
    geno = plot_eco_geno(df, [geno1, geno2])
    min1 = LineSpec("Control-Min ", "ctrl1", "red", "ctrl1-min")
    min2 = LineSpec("Control-Min ", "ctrl2", "blue", "ctrl2-min")
    mingeno = plot_eco_mingeno(df, [min1, min2])
    plot(geno, mingeno,
         size=(1025, 325), dpi=300,
         left_margin=8mm,right_margin=5mm, top_margin=5mm, bottom_margin=10mm)
    savefig("img/ctrl.png")
end

function plot_comp()
    df = deserialize("counts/comp.jls")
    geno1 = LineSpec("Comp-Geno", "host", "blue", "host-geno")
    geno2 = LineSpec("Comp-Geno", "parasite", "red", "parasite-geno")
    geno = plot_eco_geno(df, [geno1, geno2])
    min1 = LineSpec("Comp-Min ", "host", "blue", "host-min")
    min2 = LineSpec("Comp-Min ", "parasite", "red", "parasite-min")
    mingeno = plot_eco_mingeno(df, [min1, min2])
    plot(geno, mingeno,
         size=(1025, 325), dpi=300,
         left_margin=8mm,right_margin=5mm, top_margin=5mm, bottom_margin=10mm)
    savefig("img/comp.png")
end

function plot_coop()
    df = deserialize("counts/coop.jls")
    geno1 = LineSpec("Coop-Geno", "host", "blue", "host-geno")
    geno2 = LineSpec("Coop-Geno", "symbiote", "green", "symbiote-geno")
    geno = plot_eco_geno(df, [geno1, geno2])
    min1 = LineSpec("Coop-Min ", "host", "blue", "host-min")
    min2 = LineSpec("Coop-Min ", "symbiote", "green", "symbiote-min")
    mingeno = plot_eco_mingeno(df, [min1, min2])
    plot(geno, mingeno,
         size=(1025, 325), dpi=300,
         left_margin=8mm,right_margin=5mm, top_margin=5mm, bottom_margin=10mm)
    savefig("img/coop.png")
end

function plot_matchcoop()
    df = deserialize("counts/MatchCoop-MatchComp.jls")
    geno1 = LineSpec("MatchCoop-Geno", "host", "blue", "host-geno")
    geno2 = LineSpec("MatchCoop-Geno", "symbiote", "green", "symbiote-geno")
    geno3 = LineSpec("MatchCoop-Geno", "parasite", "red", "parasite-geno")
    geno = plot_eco_geno(df, [geno1, geno2, geno3])
    min1 = LineSpec("MatchCoop-Min", "host", "blue", "host-min")
    min2 = LineSpec("MatchCoop-Min", "symbiote", "green", "symbiote-min")
    min3 = LineSpec("MatchCoop-Min", "parasite", "red", "parasite-min")
    mingeno = plot_eco_mingeno(df, [min1, min2, min3])
    plot(geno, mingeno,
         size=(1025, 325), dpi=300,
         left_margin=8mm,right_margin=5mm, top_margin=5mm, bottom_margin=10mm)
    savefig("img/matchcoop.png")
end

function plot_mismatchcoop()
    df = deserialize("counts/MismatchCoop-MatchComp.jls")
    geno1 = LineSpec("MismatchCoop-Geno", "host", "blue", "host-geno")
    geno2 = LineSpec("MismatchCoop-Geno", "symbiote", "green", "symbiote-geno")
    geno3 = LineSpec("MismatchCoop-Geno", "parasite", "red", "parasite-geno")
    geno = plot_eco_geno(df, [geno1, geno2, geno3])
    min1 = LineSpec("MismatchCoop-Min", "host", "blue", "host-min")
    min2 = LineSpec("MismatchCoop-Min", "symbiote", "green", "symbiote-min")
    min3 = LineSpec("MismatchCoop-Min", "parasite", "red", "parasite-min")
    mingeno = plot_eco_mingeno(df, [min1, min2, min3])
    plot(geno, mingeno,
         size=(1025, 325), dpi=300,
         left_margin=8mm,right_margin=5mm, top_margin=5mm, bottom_margin=10mm)
    savefig("img/mismatchcoop.png")
end

function plot_mismatchcycle()
    df = deserialize("counts/mismatchcycle-counts.jls")
    geno1 = LineSpec("MismatchCycle-Geno", "X", "blue", "x-geno")
    geno2 = LineSpec("MismatchCycle-Geno", "Y", "green", "y-geno")
    geno3 = LineSpec("MismatchCycle-Geno", "Z", "red", "z-geno")
    geno = plot_eco_geno(df, [geno1, geno2, geno3])
    min1 = LineSpec("MismatchCoop-Min", "X", "blue", "x-min")
    min2 = LineSpec("MismatchCoop-Min", "Y", "green", "y-min")
    min3 = LineSpec("MismatchCoop-Min", "Z", "red", "z-min")
    mingeno = plot_eco_mingeno(df, [min1, min2, min3])
    plot(geno, mingeno,
         size=(1025, 325), dpi=300,
         left_margin=8mm,right_margin=5mm, top_margin=5mm, bottom_margin=10mm)
    savefig("img/mismatchcycle.png")
end

function plot_4MatchMix()
    df = deserialize("counts/4MatchMix-counts.jls")
    geno = plot_eco_geno(
        df, 
        [
            LineSpec("4MatchMix-Geno", "A", "blue", "A-geno"),
            LineSpec("4MatchMix-Geno", "B", "green", "B-geno"),
            LineSpec("4MatchMix-Geno", "C", "red", "C-geno"),
            LineSpec("4MatchMix-Geno", "D", "orange", "D-geno"),
        ], 
        [0, 250, 500]
    )
    mingeno = plot_eco_mingeno(
        df,
        [
            LineSpec("4MatchMix-Min", "A", "blue", "A-min"),
            LineSpec("4MatchMix-Min", "B", "green", "B-min"),
            LineSpec("4MatchMix-Min", "C", "red", "C-min"),
            LineSpec("4MatchMix-Min", "D", "orange", "D-min"),
        ],
        [0, 250, 500]
    )
    plot(geno, mingeno,
         size=(1025, 325), dpi=300,
         left_margin=8mm,right_margin=5mm, top_margin=5mm, bottom_margin=10mm)
    savefig("img/4MatchMix.png")
end

function doall()
    plot_control()
    plot_coop()
    plot_comp()
    plot_mix()
    plot_cycle()
    plot_compcycle()
    plot_fitness()
end


using StatsPlots

function raincloud(data)
    p = violin(data,
               side=:left,
               show_mean = true,
               show_median = true,
               quantiles = [0.25, 0.75],
               leg=false)

    for col in 1:size(data)[2]
        display(scatter!(col .+ 0.1 .+ 0.3 .* rand(size(data)[1]),
                data[:, col], color=col))
    end

end

# raincloud(rand(100, 5))