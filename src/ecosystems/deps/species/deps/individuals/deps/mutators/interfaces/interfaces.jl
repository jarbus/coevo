module Interfaces 

export mutate

using ......Ecosystems.Utilities.Counters: Counter
using ..Abstract: Mutator, Genotype, AbstractRNG

"""
    Generic mutation function for `Individual`.

Mutate the genotype of an `Individual` using a given mutation strategy.
"""
function mutate(
    ::Mutator, ::AbstractRNG, ::Counter, geno::Genotype
)::Genotype
    throw(ErrorException("Default mutation for genotype $geno not implemented."))
end

end