module Generational

export GenerationalReplacer

using DataStructures: OrderedDict

using Random: AbstractRNG
using ....Species.Replacers.Abstract: Replacer
using ....Species.Individuals: Individual
using ....Species.Abstract: AbstractSpecies
using ....Species.Evaluators.Types.ScalarFitness: ScalarFitnessEvaluation

import ...Interfaces: replace


Base.@kwdef struct GenerationalReplacer <: Replacer
    n_elite::Int = 0
end

function replace(
    replacer::GenerationalReplacer,
    ::AbstractRNG, 
    species::AbstractSpecies,
    evaluation::ScalarFitnessEvaluation
)
    if isempty(species.children)
        return species.pop
    end

    eval_ids = collect(keys(evaluation.fitnesses))
    pop_ids = [indiv_id for indiv_id in eval_ids if indiv_id in keys(species.pop)]
    children_ids = [indiv_id for indiv_id in eval_ids if indiv_id in keys(species.children)]
    elite_ids = pop_ids[1:replacer.n_elite]
    n_children = length(species.pop) - replacer.n_elite
    children_ids = children_ids[1:n_children]
    new_pop = Dict(
        id => indiv for (id, indiv) in merge(species.pop, species.children) 
        if id in Set([elite_ids ; children_ids])
    )

    return new_pop
end

end