export make_reproducer_types, make_substrate_types, make_species_ids, make_species_creators

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
    species_creators = [
        BasicSpeciesCreator(
            id = species_id,
            n_population = configuration.n_population,
            n_children = configuration.n_population,
            genotype_creator = genotype_creator,
            individual_creator = BasicIndividualCreator(),
            phenotype_creator = phenotype_creator,
            evaluator = evaluator,
            replacer = TruncationReplacer(n_truncate = configuration.n_population),
            selector = selector,
            recombiner = CloneRecombiner(),
            mutators = mutators,
        ) 
        for species_id in species_ids
    ]
    return species_creators
end
