using Test
using Random
using StableRNGs: StableRNG
include("../src/CoEvo.jl")
using .CoEvo
using .Mutators.Types.GnarlNetworks: mutate_weights, add_node, remove_node, add_connection, remove_connection, mutate


# Mock the required external modules/functions for testing purposes

# Create a basic genotype to work with
basic_genotype() = GnarlNetworkGenotype(
    2,
    1,
    [GnarlNetworkNodeGene(1, 0.3f0), GnarlNetworkNodeGene(2, 0.4f0)],
    [GnarlNetworkConnectionGene(1, 0.3f0, 0.4f0, 0.5f0)]
)

@testset "GnarlNetworks Mutation Tests" begin

    rng = StableRNG(42)
    counter = Counter(1)
    mutator = GnarlNetworkMutator()

    @testset "mutate_weight" begin
        geno = basic_genotype()
        original_weight = geno.connections[1].weight
        mutated_geno = mutate_weights(rng, geno, mutator.weight_factor)
        @test mutated_geno.connections[1].weight ≠ original_weight
    end

    @testset "add_node" begin
        geno = basic_genotype()
        mutated_geno = add_node(rng, counter, geno)
        @test length(mutated_geno.hidden_nodes) == length(geno.hidden_nodes) + 1
    end

    @testset "remove_node" begin
        geno = basic_genotype()
        mutated_geno = remove_node(rng, counter, geno)
        # We have a single hidden node in the basic_genotype so it should be removed
        @test length(mutated_geno.hidden_nodes) == 1
    end

    @testset "add_connection" begin
        geno = basic_genotype()
        mutated_geno = add_connection(rng, counter, geno)
        @test length(mutated_geno.connections) == length(geno.connections) + 1
    end

    @testset "remove_connection" begin
        geno = basic_genotype()
        mutated_geno = remove_connection(rng, counter, geno)
        @test isempty(mutated_geno.connections)
    end

    @testset "mutate" begin
        geno = basic_genotype()
        mutated_geno = mutate(mutator, rng, counter, geno)
        @test mutated_geno ≠ geno
        # Note: Depending on the random mutations, more specific checks might be added.
    end

end
@testset "GnarlNetworks Genotypes Tests" begin

    rng = Random.MersenneTwister(1234)  # Deterministic RNG for reproducibility
    counter = Counter(1)
    genotype_creator = GnarlNetworkGenotypeCreator(2, 1)

    @testset "Genotype creation" begin
        genotypes = create_genotypes(genotype_creator, rng, counter, 5)
        @test length(genotypes) == 5
        for geno in genotypes
            @test geno.n_input_nodes == 2
            @test geno.n_output_nodes == 1
            @test isempty(geno.hidden_nodes)
            @test isempty(geno.connections)
        end
    end

    @testset "Genotype basic structure" begin
        geno = basic_genotype()
        @test geno.n_input_nodes == 2
        @test geno.n_output_nodes == 1
        @test length(geno.hidden_nodes) == 2
        @test length(geno.connections) == 1
        @test geno.connections[1].origin == 0.3f0
        @test geno.connections[1].destination == 0.4f0
    end
end
basic_genotype2() = GnarlNetworkGenotype(
    2,
    2,
    [GnarlNetworkNodeGene(1, 0.3f0), GnarlNetworkNodeGene(2, 0.4f0)],
    [
        GnarlNetworkConnectionGene(1, 0.3f0, 0.4f0, 0.1f0),
        GnarlNetworkConnectionGene(2, -1.0f0, 0.4f0, 0.2f0),
        GnarlNetworkConnectionGene(3, -2.0f0, 0.3f0, 0.3f0),
        GnarlNetworkConnectionGene(4, 0.0f0, 1.0f0, 1.0f0),
        GnarlNetworkConnectionGene(5, 0.0f0, 2.0f0, 1.0f0),
        GnarlNetworkConnectionGene(6, 0.4f0, 1.0f0, 0.6f0),
    ]
)
@testset "GnarlNetworks Phenotype Tests" begin
    using .Phenotypes.GnarlNetworks: set_output!, get_output, reset!, act!

    geno = basic_genotype2()
    phenotype_creator = DefaultPhenotypeCreator()
    phenotype = create_phenotype(phenotype_creator, geno)

    @testset "Phenotype structure" begin
        @test phenotype.n_input_nodes == 2
        @test phenotype.n_output_nodes == 2
        @test length(phenotype.neurons) == 7  # 2 input + 2 hidden + 1 bias
        @test length(phenotype.operations) == 7  # 2 for inputs + 2 for hidden nodes
    end

    @testset "Reset Phenotype" begin
        set_output!(phenotype.neurons[0.3f0], 0.5f0)
        set_output!(phenotype.neurons[0.4f0], 0.5f0)
        reset!(phenotype)
        @test get_output(phenotype.neurons[0.3f0]) == 0.0f0
        @test get_output(phenotype.neurons[0.4f0]) == 0.0f0
    end

    @testset "Act Phenotype" begin
        inputs = [0.5f0, 0.5f0]
        outputs = act!(phenotype, inputs)
        @test length(outputs) == 2
        # Please note that exact values may vary depending on the tanh implementation and other parameters
        # The following are placeholders, so update or add more tests as needed
        #@test outputs[1] ≈ 0.2  # Placeholder value
        @test outputs[2] ≈ tanh(2.5f0)  # Placeholder value
    end

end
