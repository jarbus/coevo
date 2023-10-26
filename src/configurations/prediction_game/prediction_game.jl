module PredictionGame

export make_ecosystem_creator, PredictionGameConfiguration

import ...Configurations: make_ecosystem_creator

using Distributed
using Base: @kwdef
using Random: AbstractRNG
using StableRNGs: StableRNG
using ...Genotypes.GnarlNetworks: GnarlNetworkGenotypeCreator
using ...Genotypes.FunctionGraphs: FunctionGraphGenotypeCreator
using ...Individuals.Basic: BasicIndividualCreator
using ...Phenotypes.FunctionGraphs.Linearized: LinearizedFunctionGraphPhenotypeCreator
using ...Phenotypes.Defaults: DefaultPhenotypeCreator
using ...Evaluators.NSGAII: NSGAIIEvaluator
using ...Evaluators.ScalarFitness: ScalarFitnessEvaluator
using ...Mutators.FunctionGraphs: FunctionGraphMutator
using ...Mutators.GnarlNetworks: GnarlNetworkMutator
using ...Selectors.Tournament: TournamentSelector
using ...Selectors.FitnessProportionate: FitnessProportionateSelector
using ...Selectors.Tournament: TournamentSelector
using ...SpeciesCreators.Basic: BasicSpeciesCreator
using ...Domains.PredictionGame: PredictionGameDomain
using ...Domains.PredictionGame: Control, Adversarial, Affinitive, Avoidant
using ...Environments.ContinuousPredictionGame: ContinuousPredictionGameEnvironmentCreator
using ...Environments.CollisionGame: CollisionGameEnvironmentCreator
using ...Interactions.Basic: BasicInteraction
using ...Jobs.Basic: BasicJobCreator
using ...Reporters: Reporter
using ...Reporters.Basic: BasicReporter
using ...Reporters.Runtime: RuntimeReporter
using ...Metrics.Common: AllSpeciesIdentity
using ...Metrics.Genotypes: GenotypeSize
using ...Metrics.Evaluations: AllSpeciesFitness
using ...Archivers.Basic: BasicArchiver
using ...States.Basic: BasicCoevolutionaryStateCreator
using ...Ecosystems.Basic: BasicEcosystemCreator
using ..Configurations: Configuration, make_counters, make_random_number_generator
using ..Configurations: make_recombiner, make_replacer, make_matchmaker, make_performer

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
    n_children::Int = n_population
    communication_dimension::Int = 1
    n_nodes_per_output::Int = 4
    n_truncate::Int = n_population
    replacer::Symbol = :truncation
    recombiner::Symbol = :clone
    selector::Symbol = :disco
    tournament_size::Int = 3
    max_clusters::Int = 5
    cohorts::Vector{Symbol} = [:population, :children]
    matchmaker::Symbol = :all_vs_all
    episode_length::Int = 32
    report_type::Symbol = :silent_test
    state_creator::Symbol = :basic_coevolutionary
    performer::Symbol = :cache
end

function make_interaction_pairs(configuration::PredictionGameConfiguration)
    INTERACTION_PAIR_DICT = Dict(
        :two_species_control => [["A", "B"]],
        :two_species_cooperative => [["Host", "Mutualist"]],
        :two_species_competitive => [["Host", "Parasite"]],
        :three_species_control => [["A", "B"],["B", "C"], ["C", "A"]],
        :three_species_mix => [
            ["Host", "Mutualist"], ["Parasite", "Host"], ["Mutualist", "Parasite"]
        ],
        :three_species_cooperative => [["A", "B"], ["C", "A"], ["B", "C"]],
        :three_species_competitive => [["A", "B"], ["B", "C"], ["C", "A"]],
    )
    ecosystem_topology = configuration.ecosystem_topology
    if ecosystem_topology ∉ keys(INTERACTION_PAIR_DICT)
        throw(ArgumentError("Unrecognized ecosystem topology: $ecosystem_topology"))
    end
    interaction_pairs = INTERACTION_PAIR_DICT[ecosystem_topology]
    return interaction_pairs
end

function make_domains(configuration::PredictionGameConfiguration)
    DOMAIN_DICT = Dict(
        :two_species_control => [:Control],
        :two_species_cooperative => [:Affinitive],
        :two_species_competitive => [:Adversarial],
        :three_species_control => [:Control, :Control, :Control],
        :three_species_mix => [:Affinitive, :Adversarial, :Avoidant],
        :three_species_cooperative => [:Affinitive, :Affinitive, :Avoidant],
        :three_species_competitive => [:Adversarial, :Adversarial, :Adversarial],
    )
    ecosystem_topology = configuration.ecosystem_topology
    if ecosystem_topology ∉ keys(DOMAIN_DICT)
        throw(ArgumentError("Unrecognized ecosystem topology: $ecosystem_topology"))
    end
    domains = [PredictionGameDomain(domain) for domain in DOMAIN_DICT[ecosystem_topology]]
    return domains
end

function make_reporters(configuration::PredictionGameConfiguration)
    reporters = Reporter[]
    report_type = configuration.report_type
    print_interval = 0
    save_interval = 0
    if report_type == :silent_test
        runtime_reporter = RuntimeReporter(print_interval = 0)
        return runtime_reporter, reporters
    elseif report_type == :verbose_test
        print_interval = 1
        save_interval = 0
    elseif report_type == :deploy
        print_interval = 25
        save_interval = 1
    else
        throw(ArgumentError("Unrecognized report type: $report_type"))
    end
    runtime_reporter = RuntimeReporter(print_interval = print_interval)
    reporters = Reporter[
        BasicReporter(
            metric = GenotypeSize(), 
            save_interval = save_interval, 
            print_interval = print_interval
        ),
        BasicReporter(
            metric = GenotypeSize(name = "MinimizedGenotypeSize", minimize = true),
            save_interval = save_interval,
            print_interval = print_interval
        ),
        BasicReporter(
            metric = AllSpeciesFitness(), 
            save_interval = save_interval, 
            print_interval = print_interval
        ),
        BasicReporter(
            metric = AllSpeciesIdentity(), 
            save_interval = save_interval, 
            print_interval = 0
        ),
    ]
    return runtime_reporter, reporters
end

function make_reproducer_types(configuration::PredictionGameConfiguration)
    reproduction_method = configuration.reproduction_method
    if reproduction_method == :roulette
        evaluator = ScalarFitnessEvaluator()
        selector = FitnessProportionateSelector(n_parents = configuration.n_population)
    elseif reproduction_method == :disco
        evaluator = NSGAIIEvaluator(
            maximize = true, perform_disco = true, max_clusters = configuration.max_clusters,
        )
        selector = TournamentSelector(
            n_parents = configuration.n_population, 
            tournament_size = configuration.tournament_size
        )
    else
        throw(ArgumentError("Unrecognized reproduction method: $reproduction_method"))
    end
    return evaluator, selector
end

function make_substrate_types(configuration::PredictionGameConfiguration)
    substrate = configuration.substrate
    communication_dimension = configuration.communication_dimension
    if substrate == :function_graphs
        genotype_creator = FunctionGraphGenotypeCreator(
            n_inputs = 2 + communication_dimension, 
            n_bias = 1,
            n_outputs = 1 + communication_dimension,
            n_nodes_per_output = configuration.n_nodes_per_output,
        )
        phenotype_creator = LinearizedFunctionGraphPhenotypeCreator()
        mutators = [FunctionGraphMutator()]
    elseif substrate == :gnarl_networks
        genotype_creator = GnarlNetworkGenotypeCreator(
            n_input_nodes = 1 + communication_dimension, 
            n_output_nodes = 1 + communication_dimension
        )
        phenotype_creator = DefaultPhenotypeCreator()
        mutators = [GnarlNetworkMutator()]
    else
        throw(ArgumentError("Unrecognized substrate: $substrate"))
    end
    return genotype_creator, phenotype_creator, mutators
end


function make_species_ids(configuration::PredictionGameConfiguration)
    SPECIES_ID_DICT = Dict(
        :two_species_control => ["A", "B"],
        :two_species_cooperative => ["Host", "Mutualist"],
        :two_species_competitive => ["Host", "Parasite"],
        :three_species_control => ["A", "B", "C"],
        :three_species_mix => ["Host", "Mutualist", "Parasite"],
        :three_species_cooperative => ["A", "B", "C"],
        :three_species_competitive => ["A", "B", "C"],
    )
    ecosystem_topology = configuration.ecosystem_topology
    if ecosystem_topology ∉ keys(SPECIES_ID_DICT)
        throw(ArgumentError("Unrecognized ecosystem topology: $ecosystem_topology"))
    end
    species_ids = SPECIES_ID_DICT[ecosystem_topology]
    return species_ids
end

function make_species_creators(configuration::PredictionGameConfiguration)
    species_ids = make_species_ids(configuration)
    genotype_creator, phenotype_creator, mutators = make_substrate_types(configuration)
    evaluator, selector = make_reproducer_types(configuration)
    replacer = make_replacer(configuration)
    recombiner = make_recombiner(configuration)
    individual_creator = BasicIndividualCreator()
    species_creators = [
        BasicSpeciesCreator(
            id = species_id,
            n_population = configuration.n_population,
            n_children = configuration.n_children,
            genotype_creator = genotype_creator,
            individual_creator = individual_creator,
            phenotype_creator = phenotype_creator,
            evaluator = evaluator,
            replacer = replacer,
            selector = selector,
            recombiner = recombiner,
            mutators = mutators,
        ) 
        for species_id in species_ids
    ]
    return species_creators
end

function make_environment_creators(configuration::PredictionGameConfiguration)
    domains = make_domains(configuration)
    episode_length = configuration.episode_length
    communication_dimension = configuration.communication_dimension
    game = configuration.game
    if game == :continuous_prediction_game
        environment_creator_type = ContinuousPredictionGameEnvironmentCreator
    elseif game == :collision_game
        environment_creator_type = CollisionGameEnvironmentCreator
    else
        throw(ArgumentError("Unrecognized game: $game"))
    end
    environment_creators = [
        environment_creator_type(
            domain = domain,
            episode_length = episode_length,
            communication_dimension = communication_dimension
        )
        for domain in domains
    ]
    return environment_creators
end

function make_interactions(configuration::PredictionGameConfiguration)
    interaction_pairs = make_interaction_pairs(configuration)
    matchmaker = make_matchmaker(configuration)
    environment_creators = make_environment_creators(configuration)
    outcome_metrics = [
        environment_creator.domain.outcome_metric.name
        for environment_creator in environment_creators
    ]
    ids = [
        join([outcome_metric, interaction_pair...], "-") 
        for (interaction_pair, outcome_metric) in zip(interaction_pairs, outcome_metrics)
    ]
    interactions = [
        BasicInteraction(
            id = id,
            environment_creator = environment_creator,
            species_ids = interaction_pair,
            matchmaker = matchmaker,
        ) 
        for (id, environment_creator, interaction_pair) in 
            zip(ids, environment_creators, interaction_pairs)
    ]
    return interactions
end

function make_job_creator(configuration::PredictionGameConfiguration)
    interactions = make_interactions(configuration)
    job_creator = BasicJobCreator(
        n_workers = configuration.n_workers, interactions = interactions
    )
    return job_creator
end


function make_ecosystem_id(configuration::PredictionGameConfiguration)
    substrate = configuration.substrate
    reproduction_method = configuration.reproduction_method
    game = configuration.game
    ecosystem_topology = configuration.ecosystem_topology
    n_population = configuration.n_population
    trial = configuration.trial
    id = join(
        [substrate, reproduction_method, game, ecosystem_topology, n_population, trial], "-"
    )
    return id
end

function make_archive_path(configuration::PredictionGameConfiguration)
    substrate = configuration.substrate
    reproduction_method = configuration.reproduction_method
    game = configuration.game
    ecosystem_topology = configuration.ecosystem_topology
    trial = configuration.trial
    jld2_path = "trials/$substrate/$reproduction_method/$game/$ecosystem_topology/$trial.jld2"
    return jld2_path
end

function make_archiver(configuration::PredictionGameConfiguration)
    archive_path = make_archive_path(configuration)
    archiver = BasicArchiver(archive_path = archive_path)
    return archiver
end

function make_state_creator(configuration::PredictionGameConfiguration)
    state_creator = configuration.state_creator
    if state_creator == :basic_coevolutionary
        state_creator = BasicCoevolutionaryStateCreator()
    else
        throw(ArgumentError("Unrecognized state creator: $state_creator"))
    end
    return state_creator
end

function make_ecosystem_creator(
    configuration::PredictionGameConfiguration = PredictionGameConfiguration()
)
    id = make_ecosystem_id(configuration)
    trial = configuration.trial
    random_number_generator = make_random_number_generator(configuration)
    species_creators = make_species_creators(configuration)
    job_creator = make_job_creator(configuration)
    performer = make_performer(configuration)
    state_creator = make_state_creator(configuration)
    runtime_reporter, reporters = make_reporters(configuration)
    archiver = make_archiver(configuration)
    individual_id_counter, gene_id_counter = make_counters(configuration)

    ecosystem_creator = BasicEcosystemCreator(
        id = id,
        trial = trial,
        random_number_generator = random_number_generator,
        species_creators = species_creators,
        job_creator = job_creator,
        performer = performer,
        state_creator = state_creator,
        reporters = reporters,
        archiver = archiver,
        individual_id_counter = individual_id_counter,
        gene_id_counter = gene_id_counter,
        runtime_reporter = runtime_reporter,
    )
    return ecosystem_creator
end

end