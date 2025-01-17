export create_environment, step!, get_outcome_set, is_active, observe!

function create_environment(
    environment_creator::EnvironmentCreator, 
    phenotypes::Vector{Phenotype},
) #where {P <: Phenotype}
    throw(ErrorException(
        "`create_environment` not implemented for $environment_creator and $phenotypes"
        )
    )
end

function observe!(environment::Environment, observer::Observer)
    error("`observe!`` not implemented for $(typeof(environment)), $(typeof(observer))")
end

function step!(environment::Environment)::Nothing
    throw(ErrorException(
        "`next!` not implemented for environment $environment"
        )
    )
end

function get_outcome_set(environment::Environment)::Vector{Float64}
    throw(ErrorException(
        "`get_outcomes` not implemented for environment $environment"
        )
    )
end

function is_active(environment::Environment)::Bool
    throw(ErrorException(
        "`is_active` not implemented for environment $environment"
        )
    )
end

function observe!(environment::Environment, observer::NullObserver)
    return nothing
end

