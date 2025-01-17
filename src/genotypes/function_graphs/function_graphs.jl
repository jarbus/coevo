"""
    FunctionGraphs

A module that provides functionality for creating, manipulating, and analyzing
function graphs, in the context of genetic programming within coevolutionary algorithms.

# Contents:
- Genotype representation of function graphs (`genotype.jl`).
- Equality testing for function graph genotypes (`equals.jl`).
- Minimization algorithms for function graph genotypes (`minimize.jl`).
- Display utilities for function graph genotypes (`show.jl`).
- Mapping between function symbols and their executable implementations (`function_map.jl`).
"""
module FunctionGraphs

import ..Genotypes: create_genotypes, get_size, minimize

using Base: @kwdef
using Random: AbstractRNG
using ..Genotypes: Genotype, GenotypeCreator
using ...Counters: Counter

include("function_map.jl")

include("genotype.jl")

include("equals.jl")

include("minimize.jl")

include("show.jl")

end