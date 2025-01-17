module Null

export NullObservation

import ..Observers: create_observation

using ...Metrics: Metric
using ...Metrics.Common: NullMetric
using ..Observers: Observation, Observer

Base.@kwdef struct NullObserver{M <: Metric} <: Observer{M}
    metric::M = NullMetric()
end

Base.@kwdef struct NullObservation{O, D} <: Observation{O, D}
    metric::O = NullMetric()
    interaction_id::String = ""
    individual_ids::Vector{Int} = Int[]
    data::D = nothing
end

function create_observation(::NullObserver)
    return NullObservation()
end

end