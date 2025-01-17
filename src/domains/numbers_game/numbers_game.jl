module NumbersGame

export NumbersGameDomain, Control, Sum, Gradient, Focusing, Relativism

import ..Domains: measure

using Base: @kwdef
using ...Metrics: Metric
using ..Domains: Domain

struct NumbersGameDomain{M <: Metric} <: Domain{M}
    outcome_metric::M
end

function outcome_decision(result::Bool)
    return result ? [1.0, 0.0] : [0.0, 1.0]
end

@kwdef struct Control <: Metric 
    name::String = "Control"
end

function measure(::NumbersGameDomain{Control}, A::Vector{<:Real}, B::Vector{<:Real})
    return [1.0, 1.0]
end

@kwdef struct Sum <: Metric 
    name::String = "Sum"
end

function measure(::NumbersGameDomain{Sum}, A::Vector{<:Real}, B::Vector{<:Real})
    sumA, sumB = sum(A), sum(B)
    return outcome_decision(sumA > sumB)
end

@kwdef struct Gradient <: Metric 
    name::String = "Gradient"
end

function measure(::NumbersGameDomain{Gradient}, A::Vector{<:Real}, B::Vector{<:Real})
    compare_results = [v1 > v2 for (v1, v2) in zip(A, B)]
    return outcome_decision(sum(compare_results) > length(A) / 2)
end

@kwdef struct Focusing <: Metric 
    name::String = "Focusing"
end

function measure(::NumbersGameDomain{Focusing}, A::Vector{<:Real}, B::Vector{<:Real})
    idx = findmax(abs.(A - B))[2]
    return outcome_decision(A[idx] > B[idx])
end

@kwdef struct Relativism <: Metric 
    name::String = "Relativism"
end

function measure(::NumbersGameDomain{Relativism}, A::Vector{<:Real}, B::Vector{<:Real})
    idx = findmin(abs.(A - B))[2]
    return outcome_decision(A[idx] > B[idx])
end

# if metric == :Control, this evaluates to NumbersGameDomain(Control())
# same for Sum, Gradient, Focusing, Relativism, and any other metric
NumbersGameDomain(metric::Symbol) =  NumbersGameDomain(eval(Expr(:call, metric)))

end
