"""
    Recombiners

This module provides recombination strategies for individuals during the evolution process.
Currently, it implements the `CloneRecombiner`, which creates new individuals by cloning the parents.

# Usage
Use `CloneRecombiner` to create offspring by directly copying the genotype of parents.
"""
module Recombiners

export CloneRecombiner

using Random: AbstractRNG
using DataStructures: OrderedDict
using ....CoEvo.Abstract: Recombiner, Individual, Evaluation
using ....CoEvo.Utilities.Counters: Counter, next!

"""
    CloneRecombiner

Represents a recombination strategy that creates offspring by directly copying the genotype 
of the parents without any genetic crossover or mutation.

# Usage
Create instances of this struct and use them with the recombination function to produce offspring.
"""
Base.@kwdef struct CloneRecombiner <: Recombiner end

"""
    (recombiner::CloneRecombiner)(rng::AbstractRNG, indiv_id_counter::Counter, parents::Vector{I})

Creates offspring by directly copying the genotype of the parents.

# Arguments
- `rng::AbstractRNG`: A random number generator (unused in this recombiner but maintained for a consistent interface).
- `indiv_id_counter::Counter`: A counter object used to assign unique IDs to the newly created individuals.
- `parents::Vector{I}`: Vector of parent individuals.

# Returns
- `Vector{Individual}`: A list of cloned offspring individuals.
"""
function(recombiner::CloneRecombiner)(
    ::AbstractRNG, 
    indiv_id_counter::Counter, 
    parents::Vector{I}
) where {I <: Individual}
    [I(next!(indiv_id_counter), parent.geno, parent.id) for parent in parents]
end

end
