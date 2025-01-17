module PredictionGame

export PredictionGameDomain, Control, Adversarial, Affinitive, Avoidant

import ..Domains: measure

using Base: @kwdef
using ...Metrics: Metric
using ..Domains: Domain

struct PredictionGameDomain{M <: Metric} <: Domain{M}
    outcome_metric::M
end

@kwdef struct Control <: Metric
    name::String = "Control"
end

function measure(::PredictionGameDomain{Control}, ::Float64)
    outcome_set = [1.0, 1.0]
    return outcome_set
end

@kwdef struct Adversarial <: Metric
    name::String = "Adversarial"
end

function measure(::PredictionGameDomain{Adversarial}, distance_score::Float64)
    outcome_set = [1 - distance_score, distance_score]
    return outcome_set
end

@kwdef struct Affinitive <: Metric
    name::String = "Affinitive"
end

function measure(::PredictionGameDomain{Affinitive}, distance_score::Float64)
    outcome_set = [1 - distance_score, 1 - distance_score]
    return outcome_set
end

@kwdef struct Avoidant <: Metric
    name::String = "Avoidant"
end

function measure(::PredictionGameDomain{Avoidant}, distance_score::Float64)
    outcome_set = [distance_score, distance_score]
    return outcome_set
end

function PredictionGameDomain(metric::Symbol)
    symbol_to_metric = Dict(
        :Control => Control,
        :Adversarial => Adversarial,
        :Affinitive => Affinitive,
        :Avoidant => Avoidant,
    )
    metric = symbol_to_metric[metric]()
    domain = PredictionGameDomain(metric)
    return domain
end

end