export CoevConfig
export makevets

struct CoevConfig{O <: Order, S <: Spawner, L <: Logger}
    key::String
    trial::Int
    rng::AbstractRNG
    jobcfg::JobConfig
    orders::Set{O}
    spawners::Set{S}
    loggers::Set{L}
    jld2file::JLD2.JLDFile
    cache::Dict{Recipe, Outcome}
end

function CoevConfig(;
        key::String,
        trial::Int,
        seed::UInt64,
        rng::AbstractRNG,
        jobcfg::JobConfig, 
        orders::Set{<:Order},
        spawners::Set{<:Spawner},
        loggers::Set{<:Logger},
        logpath::String = "log.jld2",
        )
    jld2file = jldopen(logpath, "w")
    jld2file["key"] = key
    jld2file["trial"] = trial
    jld2file["seed"] = seed
    CoevConfig(key, trial, rng, jobcfg, orders, spawners,
        loggers, jld2file, Dict{Recipe, Outcome}())
end

function make_indivdict(sp::Species)
    Dict(indiv.iid => indiv for indiv in union(sp.pop, sp.children))
end

function makevet(
        indiv::Individual,
        allresults::Dict{IndivKey, R},
    ) where {R}
    rdict = Dict(ikey => r for (ikey, r) in allresults if ikey == indiv.ikey)

    Veteran(
        indiv,
        filter(((ikey, _),) -> ikey == indiv.ikey, allresults),
        indivdict
    )
end

function makeresdict(outcomes::Set{<:Outcome})
    resdict = Dict{IndivKey, Vector{Pair{TestKey, Any}}}()
    for outcome in outcomes
        for (ikey, r) in outcome.rdict
            tkey = TestKey(outcome.oid, setdiff(keys(outcome.rdict), Set([ikey])))
            pair = tkey => r
            if ikey in keys(resdict)
                push!(resdict[ikey], pair)
            else
                resdict[ikey] = [pair]
            end
        end
    end
    resdict
end

function makevets(
    indivs::Set{<:Individual}, resdict::Dict{IndivKey, Vector{Pair{TestKey, Any}}}
)
    Set(Veteran(indiv.ikey, indiv, Dict(pair for pair in resdict[indiv.ikey]))
    for indiv in indivs)
end

function makevets(allsp::Set{<:Species}, outcomes::Set{<:Outcome})
    resdict = makeresdict(outcomes)
    Set(Species(sp.spid, makevets(sp.pop, resdict), makevets(sp.children, resdict))
    for sp in allsp)
end

function prune!(cache::Dict{Recipe, Outcome}, recipes::Set{<:Recipe})
    filter!(((oldr, _),) -> oldr ∈ recipes, cache)
    filter(newr -> newr ∉ keys(cache), recipes), Set(values(cache))
end

function update!(cache::Dict{Recipe, Outcome}, outcomes::Set{<:Outcome})
    merge!(cache, Dict(Recipe(o.oid, keys(o.rdict)) => o for o in outcomes))
end

function archive!(
    gen::UInt16, c::CoevConfig, allvets::Set{<:Species{<:Veteran}},
    outcomes::Set{<:Outcome}
)
    gen_species = JLD2.Group(c.jld2file, string(gen))
    gen_species["rng"] = c.rng
    [logger(gen_species, allvets, outcomes) for logger in c.loggers]
end

function interact!(c::CoevConfig, allsp::Set{<:Species})
    recipes = makerecipes(c.orders, allsp)
    work_recipes, cached_outcomes = prune!(c.cache, recipes)
    work = c.jobcfg(allsp, c.orders, work_recipes)
    work_outcomes = perform(work)
    update!(c.cache, work_outcomes)
    makevets(allsp, union(cached_outcomes, work_outcomes)), work_outcomes
end

function(c::CoevConfig)(gen::UInt16, allsp::Set{<:Species})
    @time allvets, work_outcomes = interact!(c, allsp)
    @time archive!(gen, c, allvets, work_outcomes)
    Set(spawner(allvets) for spawner in c.spawners)
end

function(c::CoevConfig)()
    Set(spawner() for spawner in c.spawners)
end



