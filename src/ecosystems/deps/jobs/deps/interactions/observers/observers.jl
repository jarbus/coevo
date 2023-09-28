"""
    Observations

The `Observations` module provides utilities to observe, track, and store outcomes resulting 
from interactions or evaluations in a coevolutionary process. It defines specific observation 
types, such as [`OutcomeObservation`](@ref), and corresponding configurations, 
like [`ScalarOutcomeObserver`](@ref).

# Key Types
- [`OutcomeObservation`](@ref): A structured type that captures the observed outcomes from interactions.
- [`ScalarOutcomeObserver`](@ref): A configuration type that specifies how outcomes should be observed and tracked.

# Dependencies
This module includes and depends on the `types/outcome.jl` file, which contains 
definitions related to outcomes, and the `methods/methods.jl` file that includes utility methods
for handling observations.

# Usage
Use this module when you want to define how outcomes are observed, tracked, and stored in your 
coevolutionary framework.

# Exports
The module exports: `OutcomeObservation`, `ScalarOutcomeObserver`, and `get_outcomes`.

# Files
- `types/outcome.jl`: Contains type definitions related to outcomes.
- `methods/methods.jl`: Contains utility methods for handling and processing observations.
"""
module Observers

export Abstract
export MaximumSumObservation, MaximumSumObserver, make_observation

module Abstract

export Observation, Observer, make_observation

abstract type Observation end

abstract type Observer end

function observe!(observer::Observer, observation::Observation)
    throw(ErrorException("Default watching behavior for $observer not implemented."))
end

function make_observation(observer::Observer)
    throw(ErrorException("Default observation retrieval for $observer not implemented."))
end

end

using .....Ecosystems.Abstract: Metric
using ..Domains.NumbersGame: NumbersGameDomain
using .Abstract: Observation, Observer

import .Abstract: make_observation

mutable struct BasicObserver{M <: Metric, S <: Any} <: Observer
    metric::M
    state::S
end

struct BasicObservation{M <: Metric, D} <: Observation
    metric::M
    domain_id::String
    indiv_ids::Vector{Int}
    data::D
end

function observe!(observer::MaximumSumObserver, domain::NumbersGameDomain)
    observer.sum = maximum([sum(entity) for entity in domain.entities])
end

function make_observation(observer::MaximumSumObserver)
    MaximumSumObservation("1", [1, 2], observer.sum)
end

end