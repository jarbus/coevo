module Basic

export BasicDomainReport, BasicDomainReporter

using ..Abstract: DomainReport, DomainReporter, Metric, Observation

import ...Interfaces: create_report

struct BasicDomainReport{
    O <: ObservationMetric, DOM <: DomainMetric, DATA <: Any, S <: StatisticalFeatureSet
} <: DomainReport
    gen::Int
    to_print::Bool
    to_save::Bool
    domain_id::String
    observation_metric::O
    domain_metric::DOM
    data::DATA
    stats::S
end

function Base.show(io::IO, report::BasicDomainReport{Any})
    println(io, "----------------------DOMAIN-------------------------------")
    println(io, "Generation $(report.gen)")
    println(io, "Domain ID: $(report.domain_id)")
    println(io, "Metric: $(report.metric)")
    println(io, "       Data: $(report.data)")
    
end

Base.@kwdef struct BasicDomainReporter{
    O <: ObservationMetric, D <: DomainMetric
} <: DomainReporter{D}
    domain_ids::Vector{String}
    observation_metrics::Vector{O}
    domain_metric::D
    print_interval::Int = 1
    save_interval::Int = 0
    n_round::Int = 3
    print_features::Vector{Symbol} = [:mean, :std, :minimum, :maximum]
    save_features::Vector{Symbol} = [:mean, :std, :minimum, :maximum]
end

function create_report(
    reporter::BasicDomainReporter{O, D},
    gen::Int,
    domain_id::String,
    observations::Vector{Observation}
) where {O <: ObservationMetric, D <: DomainMetric}
    to_print = reporter.print_interval > 0 && gen % reporter.print_interval == 0
    to_save = reporter.save_interval > 0 && gen % reporter.save_interval == 0
    get_observations = observation -> 
        typeof(observation.metric) == M1 && 
        domain_id == observation.domain_id
    observations = filter(get_observations, observations)
    report = create_report(reporter, gen, to_print, to_save, domain_id, observations)
    return report
end

end