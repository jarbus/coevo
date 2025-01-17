module ScalarFitness

export ScalarFitnessEvaluation, ScalarFitnessEvaluator, ScalarFitnessRecord

import ...Evaluators: evaluate

using Random: AbstractRNG
using DataStructures: SortedDict
using StatsBase: mean
using ...Species: AbstractSpecies
using ...Individuals: Individual
using ..Evaluators: Evaluation, Evaluator

struct ScalarFitnessRecord
    id::Int
    fitness::Float64
end

struct ScalarFitnessEvaluation <: Evaluation
    species_id::String
    records::Vector{ScalarFitnessRecord}
end

Base.@kwdef struct ScalarFitnessEvaluator <: Evaluator 
    maximize::Bool = true
    epsilon::Float64 = 1e-6
end

function evaluate(
    evaluator::ScalarFitnessEvaluator,
    random_number_generator::AbstractRNG,
    species::AbstractSpecies,
    outcomes::Dict{Int, SortedDict{Int, Float64}}
) 
    individuals = [species.population ; species.children]
    filter!(individual -> individual.id in keys(outcomes), individuals)
    ids = [individual.id for individual in individuals]
    outcome_means = [mean(values(outcomes[id])) for id in ids]
    fitnesses = evaluator.maximize ? outcome_means : -outcome_means
    min_fitness = minimum(fitnesses)
    shift_value = (min_fitness <= 0) ? abs(min_fitness) + evaluator.epsilon : 0
    fitnesses .+= shift_value

    records = [ScalarFitnessRecord(id, fitness) for (id, fitness) in zip(ids, fitnesses)]
    sort!(records, by = x -> (x.fitness, rand(random_number_generator)), rev = true)

    evaluation = ScalarFitnessEvaluation(species.id, records)
    return evaluation
end

end
