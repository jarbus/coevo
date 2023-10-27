export get_individual_outcomes, get_observations

function get_individual_outcomes(result::Result)
    throw(ErrorException("`get_individual_outcomes` not implemented for $(typeof(result))"))
end

function get_observations(result::Result)
    throw(ErrorException("`get_observations` not implemented for $(typeof(result))"))
end

function get_individual_outcomes(results::Vector{Result})
    # Initialize a dictionary to store interaction outcomes between individuals
    # TODO: optimize this function
    # SortedDict takes up 10% of time
    # setindex! takes up 9% of runtime
    # setdiff! takes up 6% of runtime
    # get_individual_outcomes of Result{NullObservation{NullMetric} takes up 3.6% of time}
    # Total: 30% of runtime
    individual_outcomes = Dict{Int, Dict{Int, Float64}}()

    for result in results
        outcome_dict = get_individual_outcomes(result)
        for (id, outcome) in outcome_dict
            # The opposing individual's ID is the one not matching the current ID
            @inbounds opposing_id = result.individual_ids[1] == id ? result.individual_ids[2] : result.individual_ids[1]
            
            # If the key doesn't exist in `individual_outcomes`, initialize a new SortedDict 
            # and add the outcome
            get!(individual_outcomes, id, Dict{Int, Float64}())[opposing_id] = outcome
        end
    end
    # convert individual outcomes to sorteddict
    sorted_individual_outcomes = Dict{Int, SortedDict{Int, Float64}}()
    for (id, outcome_dict) in individual_outcomes
        sorted_individual_outcomes[id] = SortedDict(outcome_dict)
    end


    return sorted_individual_outcomes
end

function get_observations(results::Vector{Result})
    observations = vcat([get_observations(result) for result in results]...)
    return observations
end
