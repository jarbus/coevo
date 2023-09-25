"""
    TournamentSelector

Represents a selection strategy that chooses individuals based on a tournament approach.
A subset of individuals is chosen randomly, and a "tournament" is held among them.
The winner of each tournament is then selected as a parent.

# Fields
- `μ::Int`: Number of parents to select.
- `tournament_size::Int`: The size of the tournament or the number of individuals to compete.
- `selection_func::Function`: A function to select the winner of the tournament. By default, `argmax` is used 
                              which selects the individual with the maximum fitness.
"""
Base.@kwdef struct TournamentSelector <: Selector
    μ::Int # number of parents to select
    tournament_size::Int # tournament size
    selection_func::Function = argmax # function to select the winner of the tournament
end

"""
    (s::TournamentSelector)(rng::AbstractRNG, pop::Vector{<:Individual}, evals::Dict{Int, ScalarFitnessEval})

Executes the tournament selection strategy.

# Arguments
- `rng::AbstractRNG`: A random number generator.
- `pop::Vector{<:Individual}`: Vector of individuals in the population.
- `evals::Dict{Int, ScalarFitnessEval}`: A dictionary mapping individual IDs to their evaluations.

# Returns
- `Vector{Individual}`: A list of selected parent individuals.
"""
function(s::TournamentSelector)(
    rng::AbstractRNG, 
    pop::Vector{<:Individual}, 
    evals::Dict{Int, ScalarFitnessEval}
)
    fitnesses = map(i -> evals[i.id].fitness, pop) 
    parent_idxs = Array{Int}(undef, s.μ)
    for i in 1:s.μ
        tournament_idxs = sample(rng, 1:length(pop), s.tournament_size, replace=false)
        parent_idxs[i] = tournament_idxs[s.selection_func(fitnesses[tournament_idxs])]
    end
    return pop[parent_idxs]
end
