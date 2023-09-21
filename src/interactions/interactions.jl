"""
    Interactions

Module that encapsulates the functionalities related to interactions within ecosystems.
It provides infrastructure for defining interaction domains, matching entities, capturing 
interaction observations, and executing interaction jobs.
"""

module Interactions

export DomainCfg
export JobCfg
export InteractionResult

include("matchmakers/matchmakers.jl")
include("observations/observations.jl")

using ..CoEvo: Job, JobConfiguration, PhenotypeConfiguration
using ..CoEvo: Ecosystem, Observation, get_pheno_dict, interact
using .Observations: NullObs

"""
    InteractionRecipe

Defines a template for an interaction. 

# Fields
- `domain_id::Int`: Identifier for the interaction domain.
- `indiv_ids::Vector{Int}`: Identifiers of individuals participating in the interaction.
"""
struct InteractionRecipe
    domain_id::Int
    indiv_ids::Vector{Int}
end

"""
    InteractionResult{O <: Observation}

Captures the result of an interaction.

# Fields
- `domain_id::Int`: Identifier for the interaction domain.
- `indiv_ids::Vector{Int}`: Identifiers of individuals participating in the interaction.
- `outcome_set::Vector{Float64}`: Set of outcomes from the interaction.
- `observation::O`: Observation captured during the interaction.
"""
struct InteractionResult{O <: Observation}
    domain_id::Int
    indiv_ids::Vector{Int}
    outcome_set::Vector{Float64}
    observation::O
end

# Constructor for InteractionResult with a default observation type.
InteractionResult(domain_id::Int, indiv_ids::Vector{Int}, outcome_set::Vector{Float64}) =
    InteractionResult(domain_id, indiv_ids, outcome_set, NullObs())

include("domains/domains.jl")
using .Domains: DomainConfiguration, DomainCfg

"""
    JobCfg{D <: DomainConfiguration} <: JobConfiguration

Configuration for an interaction job.

# Fields
- `domain_cfgs::Vector{D}`: Configurations for interaction domains.
- `n_workers::Int`: Number of workers to perform the interactions.
"""
struct JobCfg{D <: DomainConfiguration} <: JobConfiguration
    domain_cfgs::Vector{D} 
    n_workers::Int
end

# Constructor for JobCfg with a default number of workers.
function JobCfg(domain_cfgs::Vector{<: DomainConfiguration})
    return JobCfg(domain_cfgs, 1)
end

"""
    InteractionJob{D <: DomainConfiguration, T} <: Job

Defines a job that orchestrates a set of interactions.

# Fields
- `domain_cfgs::Vector{D}`: Configurations for interaction domains.
- `pheno_dict::Dict{Int, T}`: Dictionary mapping individual IDs to their phenotypes.
- `recipes::Vector{InteractionRecipe}`: Interaction recipes to be executed in this job.
"""
struct InteractionJob{D <: DomainConfiguration, T} <: Job
    domain_cfgs::Vector{D}
    pheno_dict::Dict{Int, T}
    recipes::Vector{InteractionRecipe}
end

"""
    perform(job::InteractionJob) -> Vector{InteractionResult}

Execute the given `job`, which contains various interaction recipes. Each recipe denotes 
specific entities to interact in a domain. The function processes these interactions and 
returns a list of their results.

# Arguments
- `job::InteractionJob`: The job containing details about the interactions to be performed.

# Returns
- A `Vector` of `InteractionResult` instances, each detailing the outcome of an interaction.
"""
function perform(job::InteractionJob)
    interaction_results = InteractionResult[]
    for recipe in job.recipes
        domain = job.domains[recipe.domain_id]
        phenos = [job.pheno_dict[indiv_id] for indiv_id in recipe.indiv_ids]
        result = interact(domain.problem, domain.obs_cfg, recipe.indiv_ids..., phenos...)
        push!(interaction_results, result)
    end
    return interaction_results
end

"""
    make_interaction_recipes(domain_id::Int, cfg::DomainCfg, eco::Ecosystem) -> Vector{InteractionRecipe}

Construct interaction recipes for a given domain based on its configuration and an ecosystem.

# Arguments
- `domain_id::Int`: ID of the domain for which the recipes are being generated.
- `cfg::DomainCfg`: The configuration of the domain.
- `eco::Ecosystem`: The ecosystem from which entities are sourced for interactions.

# Returns
- A `Vector` of `InteractionRecipe` instances, detailing pairs of entities to interact.

# Throws
- Throws an `ArgumentError` if the number of entities in the domain configuration isn't 2.
"""
function make_interaction_recipes(domain_id::Int, cfg::DomainCfg, eco::Ecosystem)
    if length(cfg.entities) != 2
        throw(ArgumentError("Only two-entity interactions are supported for now."))
    end
    species1 = eco.species[cfg.pheno_ids[1]]
    species2 = eco.species[cfg.pheno_ids[2]]
    interaction_ids = cfg.matchmaker(species1, species2)
    interaction_recipes = [
        InteractionRecipe(domain_id, [id1, id2]) for (id1, id2) in interaction_ids
    ]
    return interaction_recipes
end

"""
    (cfg::JobCfg)(eco::Ecosystem) -> Vector{InteractionResult}

Using the given job configuration, construct and execute interaction jobs based on the ecosystem. 
Results from all interactions are aggregated and returned.

# Arguments
- `cfg::JobCfg`: The job configuration detailing domains and number of workers.
- `eco::Ecosystem`: The ecosystem providing entities for interaction.

# Returns
- A `Vector` of `InteractionResult` detailing outcomes of all interactions executed.
"""
function(cfg::JobCfg)(eco::Ecosystem)
    recipes = vcat(
        [
            make_interaction_recipes(domain_id, domain_cfg, eco) 
            for (domain_id, domain_cfg) in enumerate(cfg.domain_cfgs)
        ]...
    )
    recipe_partitions = divvy(recipes, cfg.n_workers)
    pheno_dict = get_pheno_dict(eco)
    jobs = [
        InteractionJob(cfg.domain_cfgs, pheno_dict, recipe_partition)
        for recipe_partition in recipe_partitions
    ]
    if length(jobs) == 1
        interaction_results = perform(jobs[1])
    else
        futures = [remotecall(perform, i, job) for (i, job) in enumerate(jobs)]
        interaction_results = [fetch(f) for f in futures]
    end
    return vcat(interaction_results...)
end


end