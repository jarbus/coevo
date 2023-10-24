module Phenotypes

export Abstract, Interfaces
export Defaults, Vectors, GnarlNetworks, FiniteStateMachines, FunctionGraphs

include("abstract/abstract.jl")
using .Abstract: Abstract

include("interfaces/interfaces.jl")
using .Interfaces: Interfaces

include("defaults/defaults.jl")
using .Defaults: Defaults, DefaultPhenotypeCreator

#include("genetic_programs/genetic_programs.jl")

include("vectors/vectors.jl")
using .Vectors: Vectors

include("gnarl/gnarl.jl")
using .GnarlNetworks: GnarlNetworks

include("fsms/fsms.jl")
using .FiniteStateMachines: FiniteStateMachines

include("function_graphs/function_graphs.jl")
using .FunctionGraphs: FunctionGraphs

end