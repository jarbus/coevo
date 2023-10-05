module FiniteStateMachines

export FiniteStateMachinePhenotype

using ..Phenotypes.Abstract: Phenotype, PhenotypeCreator
using ...Genotypes.FiniteStateMachines: FiniteStateMachineGenotype

import ..Phenotypes.Interfaces: create_phenotype

struct FiniteStateMachinePhenotype{T} <: Phenotype
    start::Tuple{T, Bool}
    links::Dict{Tuple{T, Bool}, Tuple{T, Bool}}
end

function create_phenotype(
    ::PhenotypeCreator, geno::FiniteStateMachineGenotype
)
    new_links = Dict(
        ((source, bit) => (target, target in geno.ones))
        for ((source, bit), target) in geno.links
    )
    phenotype = FiniteStateMachinePhenotype(
        (geno.start, geno.start in geno.ones),
        new_links
    )
    return phenotype
end

end