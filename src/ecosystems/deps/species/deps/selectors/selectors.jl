module Selectors

export IdentitySelector, FitnessProportionateSelector

"""
    Abstract Module

Provides foundational abstract functionalities for selector types and 
implements the default behavior for unimplemented selector types.
"""
module Abstract

using Random: AbstractRNG
using DataStructures: OrderedDict
using .....CoEvo.Abstract: Individual, Evaluation, Selector

"""
    (selector::Selector)(rng::AbstractRNG, new_pop_evals::OrderedDict{<:I, <:E})

Apply a selector strategy on the provided population. This function acts as 
a placeholder for custom selector implementations. If not overridden, 
it throws an error.

# Arguments
- `rng::AbstractRNG`: A random number generator.
- `new_pop_evals::OrderedDict{<:I, <:E}`: An ordered dictionary of the new population's 
                                          individuals and their evaluations.

# Returns
- `OrderedDict{<:Individual, <:Evaluation}`: A new ordered dictionary representing the 
                                            selected population after the selection process.

# Errors
- Throws an `ErrorException` if the selector type is not implemented for the provided 
  individual and evaluation types.
"""
function(selector::Selector)(
    rng::AbstractRNG, 
    new_pop_evals::OrderedDict{<:I, <:E}, 
)::OrderedDict{<:Individual, <:Evaluation} where {I <: Individual, E <: Evaluation}
    throw(ErrorException(
        "Selector $S not implemented for individual type $I and evaluation type $E")
    )
end

end # end of Abstract module

using .Abstract
include("types/identity.jl")
include("types/fitness_proportionate.jl")
# include("types/tournament.jl")

end # end of Selectors module
