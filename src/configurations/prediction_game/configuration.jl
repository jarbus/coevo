export PredictionGameConfiguration

@kwdef mutable struct PredictionGameConfiguration <: Configuration
    substrate::Symbol = :function_graphs
    reproduction_method::Symbol = :disco
    game::Symbol = :continuous_prediction_game
    ecosystem_topology::Symbol = :three_species_mix
    trial::Int = 1
    seed::Int = 777
    random_number_generator::Union{AbstractRNG, Nothing} = nothing
    individual_id_counter_state::Int = 1
    gene_id_counter_state::Int = 1
    n_workers::Int = 1
    n_population::Int = 50
    communication_dimension::Int = 0
    n_nodes_per_output::Int = 4
    tournament_size::Int = 3
    max_clusters::Int = 5
    cohorts::Vector{Symbol} = [:population, :children]
    episode_length::Int = 16
    report_type::Symbol = :silent_test
end