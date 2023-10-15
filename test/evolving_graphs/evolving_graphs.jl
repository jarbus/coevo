using Test
using Base: @kwdef
#using CoEvo
using Random: AbstractRNG
using StableRNGs: StableRNG
using StatsBase: sample, Weights

import Base: ==
# Define a map for function symbols to actual functions
using Random  # For StableRNG

using .FunctionGraphMutators: add_function, remove_function, swap_function, redirect_connection
using .FunctionGraphMutators: inject_noise!
using .FunctionGraphMutators: select_function_with_same_arity, get_genotype_after_swapping_functions
using .FunctionGraphMutators: get_all_substitutions, ConnectionRedirectionSpecification
using .Phenotypes.Interfaces: create_phenotype, act!, reset!

println("Starting tests for FunctionGraphs...")

@testset "Add Node Tests" begin
    rng = StableRNG(42)
    gene_id_counter = Counter(6)

    genotype = FunctionGraphGenotype(
        input_node_ids = [1],
        bias_node_ids = [2],
        hidden_node_ids = [3, 4],
        output_node_ids = [5],
        nodes = Dict(
            1 => FunctionGraphNode(1, :INPUT, []),
            2 => FunctionGraphNode(2, :BIAS, []),
            3 => FunctionGraphNode(3, :ADD, [
                FunctionGraphConnection(1, 0.5, false),
                FunctionGraphConnection(2, 0.5, false)
            ]),
            4 => FunctionGraphNode(4, :MULTIPLY, [
                FunctionGraphConnection(3, 0.5, true),
                FunctionGraphConnection(2, 0.5, false)
            ]),
            5 => FunctionGraphNode(5, :OUTPUT, [
                FunctionGraphConnection(4, 1.0, false)
            ]),
        )
    )
    # Create an initial `genotype` object here for testing.

    @testset "Node addition" begin
        new_genotype = add_function(rng, gene_id_counter, genotype)
        @test length(new_genotype.nodes) == length(genotype.nodes) + 1
        @test length(new_genotype.hidden_node_ids) == length(genotype.hidden_node_ids) + 1
    end
    
    @testset "Function selection" begin
        new_genotype = add_function(rng, gene_id_counter, genotype)
        new_id = maximum(keys(new_genotype.nodes))  # Assuming monotonic ids
        new_func = new_genotype.nodes[new_id].func
        @test new_func ∉ [:INPUT, :BIAS, :OUTPUT]
    end

    @testset "Input connections" begin
        new_genotype = add_function(rng, gene_id_counter, genotype)
        new_id = maximum(keys(new_genotype.nodes))
        new_node = new_genotype.nodes[new_id]
        # Test that connections are valid
        for conn in new_node.input_connections
            @test conn.input_node_id in [new_genotype.input_node_ids; new_genotype.bias_node_ids; new_genotype.hidden_node_ids]
            @test conn.weight == 0.0  # If you modify weight initialization, adjust accordingly
            @test conn.is_recurrent == true
        end
    end
end


@testset "Test Node Removal" begin
    rng = StableRNG(42)
    gene_id_counter = Counter()

    genotype = FunctionGraphGenotype(
        input_node_ids = [1, 2], 
        bias_node_ids = [3],
        hidden_node_ids = [4, 5],
        output_node_ids = [6],
        nodes = Dict(
            1 => FunctionGraphNode(1, :INPUT, []),
            2 => FunctionGraphNode(2, :INPUT, []),
            3 => FunctionGraphNode(3, :BIAS, []),
            4 => FunctionGraphNode(4, :ADD, [
                FunctionGraphConnection(1, 1.0, false), 
                FunctionGraphConnection(3, 1.0, false)
            ]),
            5 => FunctionGraphNode(5, :ADD, [
                FunctionGraphConnection(2, 1.0, false), 
                FunctionGraphConnection(4, 1.0, false)
            ]),
            6 => FunctionGraphNode(6, :OUTPUT, [
                FunctionGraphConnection(5, 1.0, false)
            ])
        )
    )

    @testset "Test Deterministic Removal" begin
        # Test deterministic removal
        substitutions = [
            ConnectionRedirectionSpecification(5, 2, 2)
        ]
        new_genotype = remove_function(genotype, 4, substitutions)

        @test !haskey(new_genotype.nodes, 4) # node 4 should be removed
        @test new_genotype.hidden_node_ids == [5] # Only node 5 should be left
        @test new_genotype.nodes[5].input_connections[2].input_node_id == 2 # node 5 should now connect to node 2, not 4
    end

    @testset "Test Illegal Node Removal" begin
        # Trying to remove an input node should throw an error
        @test_throws ErrorException remove_function(genotype, 1, ConnectionRedirectionSpecification[])
    end

    @testset "Test Self-loop Handling" begin
        # Removing node 4 without available redirection options should create a self-loop
        substitutions = [
            ConnectionRedirectionSpecification(5, 2, 5)
        ]
        new_genotype = remove_function(genotype, 4, substitutions)
        
        @test new_genotype.nodes[5].input_connections[end].input_node_id == 5 # self-loop should be created
    end

    @testset "Test Stochastic Removal with Known RNG" begin
        new_genotype = remove_function(rng, gene_id_counter, genotype, FUNCTION_MAP)
    
        # Add specific tests depending on predictable random behavior from the seed
        # Note: You will need to determine the expected behavior based on the RNG seed
        @test !haskey(new_genotype.nodes, 4) || !haskey(new_genotype.nodes, 5)
    end
end

@testset "Test Node Removal" begin
    rng = StableRNG(42)
    gene_id_counter = Counter()
    geno = FunctionGraphGenotype(
        input_node_ids = [0],
        bias_node_ids = Int[],
        hidden_node_ids = [1, 2, 3, 4, 5],
        output_node_ids = [6],
        nodes = Dict(
            0 => FunctionGraphNode(0, :INPUT, []),
            1 => FunctionGraphNode(1, :IDENTITY, [
                FunctionGraphConnection(0, 1.0, false)
            ]),
            2 => FunctionGraphNode(2, :IDENTITY, [
                FunctionGraphConnection(1, 1.0, true)
            ]),
            3 => FunctionGraphNode(3, :MAXIMUM, [
                FunctionGraphConnection(1, 1.0, false),
                FunctionGraphConnection(5, 1.0, true), 
            ]),
            4 => FunctionGraphNode(4, :MULTIPLY, [
                FunctionGraphConnection(2, 1.0, true), 
                FunctionGraphConnection(3, 1.0, true)
            ]),
            5 => FunctionGraphNode(5, :ADD, [
                FunctionGraphConnection(3, 1.0, false), 
                FunctionGraphConnection(4, 1.0, false)
            ]),
            6 => FunctionGraphNode(6, :OUTPUT, [
                FunctionGraphConnection(5, 1.0, false)
            ]),
        )
    )

    @test length(keys(geno.nodes)) == 7

    @testset "Removing Nodes and Validating Connections" begin
        # Assuming remove_function is the refactored function to remove a node deterministically
        # and it uses ConnectionRedirectionSpecification for reconnection logic
        
        # Removing Node 2
        # You need to determine what happens to connections of node 2, and create appropriate ConnectionRedirectionSpecification
        node_to_remove_id = 2

        link_sub_spec_2 = [
            ConnectionRedirectionSpecification(
                node_id = 4, 
                input_connection_index = 1, 
                new_input_node_id = 1
            ),
        ]  # Example: redirect the connection from 2 to 3
        substitutions = get_all_substitutions(geno, node_to_remove_id, rng)

        @test Set(substitutions) == Set(link_sub_spec_2)
        mutant = remove_function(geno, node_to_remove_id, link_sub_spec_2)
        
        @test length(keys(mutant.nodes)) == 6
        @test all(connection.input_node_id != node_to_remove_id for connection in mutant.nodes[4].input_connections)
        @test mutant.nodes[4].input_connections[1].input_node_id == 1 # node 4 should now connect to node 1, not 2

        node_to_remove_id = 1
        link_sub_spec_1 = [
            ConnectionRedirectionSpecification(
                node_id = 3, 
                input_connection_index = 1, 
                new_input_node_id = 0
            ),
            ConnectionRedirectionSpecification(
                node_id = 4, 
                input_connection_index = 1, 
                new_input_node_id = 0
            ),
        ]  # Example: redirect the connection from 1 to 0

        substitutions = get_all_substitutions(mutant, node_to_remove_id, rng)

        @test Set(substitutions) == Set(link_sub_spec_1)


        mutant = remove_function(mutant, node_to_remove_id, link_sub_spec_1)
        @test length(keys(mutant.nodes)) == 5

        @test all(
            connection.input_node_id != node_to_remove_id 
            for connection in mutant.nodes[3].input_connections
        )
        @test mutant.nodes[3].input_connections[1].input_node_id == 0 # node 3 should now connect to node 0, not 1
        @test all(
            connection.input_node_id != node_to_remove_id 
            for connection in mutant.nodes[4].input_connections
        )
        @test mutant.nodes[4].input_connections[1].input_node_id == 0 # node 4 should now connect to node 0, not 1
        
        # Similar steps for nodes 1, 3, 4, and 5 with appropriate ConnectionRedirectionSpecification objects
        # ...


        node_to_remove_id = 3
        possible_link_substitution_specifications = [
            ConnectionRedirectionSpecification(
                node_id = 5, 
                input_connection_index = 1, 
                new_input_node_id = 0,
            ),
            ConnectionRedirectionSpecification(
                node_id = 5, 
                input_connection_index = 1, 
                new_input_node_id = 5,
            ),
            ConnectionRedirectionSpecification(
                node_id = 4, 
                input_connection_index = 2, 
                new_input_node_id = 0,
            ),
            ConnectionRedirectionSpecification(
                node_id = 4, 
                input_connection_index = 2, 
                new_input_node_id = 5,
            ),
        ]  # Example: redirect the connection from 3 to 0
        for _ in 1:10
            actual_substitutions = get_all_substitutions(mutant, node_to_remove_id, rng)
            @test issubset(Set(actual_substitutions), Set(possible_link_substitution_specifications), )
        end
    end
    
    @testset "Error Handling for Invalid Node Removal" begin
        # Attempting to remove input and output nodes - should throw an error
        @test_throws ErrorException remove_function(geno, 0, ConnectionRedirectionSpecification[])
        @test_throws ErrorException remove_function(geno, 6, ConnectionRedirectionSpecification[])
    end
end


@testset "Swap Function Tests" begin
    rng = StableRNG(42)
    gene_id_counter = Counter()

    genotype_example = FunctionGraphGenotype(
        [1], 
        [2], 
        [3, 4],
        [5],
        Dict(
            1 => FunctionGraphNode(1, :INPUT, []),
            2 => FunctionGraphNode(2, :BIAS, []),
            3 => FunctionGraphNode(3, :ADD, [FunctionGraphConnection(1, 1.0, false)]),
            4 => FunctionGraphNode(4, :SUBTRACT, [FunctionGraphConnection(2, 1.0, false)]),
            5 => FunctionGraphNode(5, :OUTPUT, [FunctionGraphConnection(3, 1.0, false)])
        )
    )
    
    @testset "select_function_with_same_arity" begin
        old_function = :ADD  # Assume ADD exists in FUNCTION_MAP and its arity is known
        new_function = select_function_with_same_arity(rng, old_function, FUNCTION_MAP)
        @test new_function != old_function  # The function should be different from the original
        @test FUNCTION_MAP[new_function].arity == FUNCTION_MAP[old_function].arity  # Arity should be the same
    end
    
    @testset "get_genotype_after_swapping_functions" begin
        new_func = :MULTIPLY  # Assume MULTIPLY is a valid function
        swapped_genotype = get_genotype_after_swapping_functions(genotype_example, 3, new_func)
        
        # Check function swap
        @test swapped_genotype.nodes[3].func == new_func  # Function should be updated
        
        # Check the other nodes remain unaffected
        @test swapped_genotype.nodes[4] == genotype_example.nodes[4]
        @test swapped_genotype.nodes[5] == genotype_example.nodes[5]
    end
    
    @testset "swap_function" begin
        swapped_genotype = swap_function(rng, gene_id_counter, genotype_example, FUNCTION_MAP)
        
        # Check a function was swapped (assuming swap will always change the function)
        swapped_funcs = [node.func for node in values(swapped_genotype.nodes)]
        original_funcs = [node.func for node in values(genotype_example.nodes)]
        @test any(swapped_funcs .!= original_funcs)
        
        # Check node topology remains the same
        swapped_connections = [node.input_connections for node in values(swapped_genotype.nodes)]
        original_connections = [node.input_connections for node in values(genotype_example.nodes)]
        @test swapped_connections == original_connections
    end
end


@testset "Test Connection Redirection" begin
    genotype = FunctionGraphGenotype(
        input_node_ids = [1],
        bias_node_ids = [2],
        hidden_node_ids = [3],
        output_node_ids = [4],
        nodes = Dict(
            1 => FunctionGraphNode(1, :INPUT, []),
            2 => FunctionGraphNode(2, :BIAS, []),
            3 => FunctionGraphNode(3, :ADD, [
                FunctionGraphConnection(1, 1.0, false),
                FunctionGraphConnection(2, 1.0, false)
            ]),
            4 => FunctionGraphNode(4, :OUTPUT, [
                FunctionGraphConnection(3, 1.0, false)
            ])
        )
    )

    # Seed to make stochastic tests reproducible
    rng = StableRNG(42)
    gene_id_counter = Counter(5)

    @testset "Deterministic Redirection" begin
        new_input_node_id = 2  # redirect to bias node for simplicity
        
        # redirect the first input of node 3 to new_input_node_id
        redirection_spec = ConnectionRedirectionSpecification(
            node_id = 3, 
            input_connection_index = 1, 
            new_input_node_id = new_input_node_id
        )
        new_genotype = redirect_connection(genotype, redirection_spec)
        
        @test new_genotype.nodes[3].input_connections[1].input_node_id == new_input_node_id
        @test new_genotype.nodes[3].input_connections[1].weight == 1.0  # Weight should be unchanged
        @test !new_genotype.nodes[3].input_connections[1].is_recurrent  # Recurrent status should be unchanged
    end
    
    @testset "Stochastic Redirection" begin
        new_genotype = redirect_connection(rng, gene_id_counter, genotype, FUNCTION_MAP)

        # Due to the random nature, we perform a basic check
        # Here, making sure something was redirected while maintaining weights and recurrent status
        is_changed = false
        for (nid, node) in new_genotype.nodes
            for (old_conn, new_conn) in zip(genotype.nodes[nid].input_connections, node.input_connections)
                if old_conn.input_node_id != new_conn.input_node_id
                    is_changed = true
                end
                @test old_conn.weight == new_conn.weight
                @test old_conn.is_recurrent == new_conn.is_recurrent
            end
        end
        @test is_changed
    end
end



using Test

@testset "Function Graph Phenotype Tests" begin
    genotype = FunctionGraphGenotype(
        input_node_ids  = [1], 
        bias_node_ids   = [2],
        hidden_node_ids = [3], 
        output_node_ids = [4],
        nodes = Dict(
            1 => FunctionGraphNode(1, :INPUT, FunctionGraphConnection[]),
            2 => FunctionGraphNode(2, :BIAS, FunctionGraphConnection[]),
            3 => FunctionGraphNode(3, :ADD, [
                FunctionGraphConnection(1, 1.0, true),
                FunctionGraphConnection(2, 1.0, true),
            ]),
            4 => FunctionGraphNode(4, :OUTPUT, [
                FunctionGraphConnection(3, 1.0, false),
            ])
        )
    )
    
    # Test 1: Initialization of a stateful node from a stateless node
    @testset "Stateful Node Initialization" begin
        stateless_node = FunctionGraphNode(1, :add, [FunctionGraphConnection(2, 0.5, false)])
        stateful_node = FunctionGraphStatefulNode(stateless_node)
        @test stateful_node.id == stateless_node.id
        @test stateful_node.func == stateless_node.func
        @test stateful_node.input_nodes == []
        @test stateful_node.current_value === nothing
        @test stateful_node.previous_value == 0.0
        @test stateful_node.seeking_output == false
    end
    
    # Test 2: Creation of phenotype from genotype
    @testset "Phenotype Creation" begin
        phenotype = create_phenotype(DefaultPhenotypeCreator(), genotype)
        @test length(phenotype.nodes) == length(genotype.nodes)
        @test phenotype.input_node_ids == genotype.input_node_ids
        @test phenotype.output_node_ids == genotype.output_node_ids
    end
    
end



@testset "Fibonacci Phenotype" begin
    geno = FunctionGraphGenotype(
        input_node_ids = [0],
        bias_node_ids = Int[],
        hidden_node_ids = [1, 2, 3, 4, 5],
        output_node_ids = [6],
        nodes = Dict(
            6 => FunctionGraphNode(6, :OUTPUT, [
                FunctionGraphConnection(5, 1.0, false)
            ]),
            5 => FunctionGraphNode(5, :ADD, [
                FunctionGraphConnection(3, 1.0, false), 
                FunctionGraphConnection(4, 1.0, false)
            ]),
            4 => FunctionGraphNode(4, :MULTIPLY, [
                FunctionGraphConnection(2, 1.0, true), 
                FunctionGraphConnection(3, 1.0, true)
            ]),
            3 => FunctionGraphNode(3, :MAXIMUM, [
                FunctionGraphConnection(5, 1.0, true), 
                FunctionGraphConnection(1, 1.0, false)
            ]),
            2 => FunctionGraphNode(2, :IDENTITY, [
                FunctionGraphConnection(1, 1.0, true)
            ]),
            1 => FunctionGraphNode(1, :IDENTITY, [
                FunctionGraphConnection(0, 1.0, false)
            ]),
            0 => FunctionGraphNode(0, :INPUT, [])
        )
    )

    phenotype_creator = DefaultPhenotypeCreator()
    phenotype = create_phenotype(phenotype_creator, geno)
    input_values = [1.0]
    output = act!(phenotype, input_values)
    @test output == [1.0]
    output = act!(phenotype, input_values)
    @test output == [1.0]
    output = act!(phenotype, input_values)
    @test output == [2.0]
    output = act!(phenotype, input_values)
    @test output == [3.0]
    output = act!(phenotype, input_values)
    @test output == [5.0]
    output = act!(phenotype, input_values)
    @test output == [8.0]
    output = act!(phenotype, input_values)
    @test output == [13.0]
end



@testset "Logic Gate Phenotype" begin
    geno = FunctionGraphGenotype(
        input_node_ids = [1, 2],
        bias_node_ids = Int[],
        hidden_node_ids = [3, 4, 5],
        output_node_ids = [6],
        nodes = Dict(
            6 => FunctionGraphNode(6, :OUTPUT, [
                FunctionGraphConnection(5, 1.0, false)
            ]),
            5 => FunctionGraphNode(5, :AND, [
                FunctionGraphConnection(3, 1.0, false), 
                FunctionGraphConnection(4, 1.0, false)
            ]),
            4 => FunctionGraphNode(4, :OR, [
                FunctionGraphConnection(1, 1.0, false), 
                FunctionGraphConnection(2, 1.0, false)
            ]),
            3 => FunctionGraphNode(3, :NAND, [
                FunctionGraphConnection(1, 1.0, false), 
                FunctionGraphConnection(2, 1.0, false)
            ]),
            2 => FunctionGraphNode(2, :INPUT, []),
            1 => FunctionGraphNode(1, :INPUT, [])
        )
    )

    phenotype_creator = DefaultPhenotypeCreator()
    phenotype = create_phenotype(phenotype_creator, geno)

    input_outputs = [
        ([1.0, 1.0], [0.0]),
        ([0.0, 1.0], [1.0]),
        ([1.0, 0.0], [1.0]),
        ([0.0, 0.0], [0.0])
    ]

    for (input_values, expected_output) in input_outputs
        output = act!(phenotype, input_values)
        @test output == expected_output
    end
end

@testset "Complex Logic Phenotype" begin
    geno = FunctionGraphGenotype(
        input_node_ids = [1, 2, 3],
        bias_node_ids = Int[],
        hidden_node_ids = [4, 5, 6, 7, 8, 9],
        output_node_ids = [10, 11],
        nodes = Dict(
            11 => FunctionGraphNode(11, :OUTPUT, [
                FunctionGraphConnection(8, 1.0, false)
            ]),
            10 => FunctionGraphNode(10, :OUTPUT, [
                FunctionGraphConnection(9, 1.0, false)
            ]),
            9 => FunctionGraphNode(9, :OR, [
                FunctionGraphConnection(5, 1.0, false), 
                FunctionGraphConnection(6, 1.0, false)
            ]),
            8 => FunctionGraphNode(8, :XOR, [
                FunctionGraphConnection(3, 1.0, false), 
                FunctionGraphConnection(4, 1.0, false)
            ]),
            7 => FunctionGraphNode(7, :AND, [
                FunctionGraphConnection(3, 1.0, false), 
                FunctionGraphConnection(4, 1.0, false)
            ]),
            6 => FunctionGraphNode(6, :AND, [
                FunctionGraphConnection(1, 1.0, false), 
                FunctionGraphConnection(2, 1.0, false)
            ]),
            5 => FunctionGraphNode(5, :AND, [
                FunctionGraphConnection(3, 1.0, false), 
                FunctionGraphConnection(4, 1.0, false)
            ]),
            4 => FunctionGraphNode(4, :XOR, [
                FunctionGraphConnection(1, 1.0, false), 
                FunctionGraphConnection(2, 1.0, false)
            ]),
            3 => FunctionGraphNode(3, :INPUT, []),
            2 => FunctionGraphNode(2, :INPUT, []),
            1 => FunctionGraphNode(1, :INPUT, [])
        )
    )

    phenotype_creator = DefaultPhenotypeCreator()
    phenotype = create_phenotype(phenotype_creator, geno)

    input_outputs = [
        ([0.0, 0.0, 0.0], [0.0, 0.0]),
        ([0.0, 0.0, 1.0], [0.0, 1.0]),
        ([0.0, 1.0, 0.0], [0.0, 1.0]),
        ([0.0, 1.0, 1.0], [1.0, 0.0]),
        ([1.0, 0.0, 0.0], [0.0, 1.0]),
        ([1.0, 0.0, 1.0], [1.0, 0.0]),
        ([1.0, 1.0, 0.0], [1.0, 0.0]),
        ([1.0, 1.0, 1.0], [1.0, 1.0])
    ]

    for (input_values, expected_output) in input_outputs
        output = act!(phenotype, input_values)
        @test output == expected_output
    end
end

@testset "Physics Phenotype" begin
    geno = FunctionGraphGenotype(
        input_node_ids = [1, 2, 3, 4],
        bias_node_ids = Int[],
        hidden_node_ids = [5, 6, 7, 8],
        output_node_ids = [9],
        nodes = Dict(
            9 => FunctionGraphNode(9, :OUTPUT, [
                FunctionGraphConnection(8, 1.0, false)
            ]),
            8 => FunctionGraphNode(8, :MULTIPLY, [
                FunctionGraphConnection(1, 1.0, false), 
                FunctionGraphConnection(7, 1.0, false)
            ]),
            7 => FunctionGraphNode(7, :DIVIDE, [
                FunctionGraphConnection(5, 1.0, false), 
                FunctionGraphConnection(6, 1.0, false)
            ]),
            6 => FunctionGraphNode(6, :MULTIPLY, [
                FunctionGraphConnection(4, 1.0, false), 
                FunctionGraphConnection(4, 1.0, false)
            ]),
            5 => FunctionGraphNode(5, :MULTIPLY, [
                FunctionGraphConnection(2, 1.0, false), 
                FunctionGraphConnection(3, 1.0, false)
            ]),
            4 => FunctionGraphNode(4, :INPUT, []),
            3 => FunctionGraphNode(3, :INPUT, []),
            2 => FunctionGraphNode(2, :INPUT, []),
            1 => FunctionGraphNode(1, :INPUT, [])
        )
    )

    newtons_law_of_gravitation = (g, m1, m2, r) -> (g * m1 * m2) / r^2

    phenotype_creator = DefaultPhenotypeCreator()
    phenotype = create_phenotype(phenotype_creator, geno)

    input_outputs = [
        ([(6.674 * 10^-11), 5.972 * 10^24, 1.989 * 10^30, 1.496 * 10^11], [newtons_law_of_gravitation(6.674 * 10^-11, 5.972 * 10^24, 1.989 * 10^30, 1.496 * 10^11)]),
        ([6.674 * 10^-11, 7.342 * 10^22, 1.989 * 10^30, 3.844 * 10^8], [newtons_law_of_gravitation(6.674 * 10^-11, 7.342 * 10^22, 1.989 * 10^30, 3.844 * 10^8)])
    ]

    for (input_values, expected_output) in input_outputs
        output = act!(phenotype, input_values)
        @test isapprox(output[1], expected_output[1]; atol=1e-5)
    end
end

using Test

@testset "Inject Noise" begin
    # Create a simple genotype as test case
    rng = StableRNG(42)
    genotype = FunctionGraphGenotype(
        input_node_ids = [1, 2],
        bias_node_ids = [],
        hidden_node_ids = [3, 4],
        output_node_ids = [5],
        nodes = Dict(
            1 => FunctionGraphNode(1, :INPUT, []),
            2 => FunctionGraphNode(2, :INPUT, []),
            3 => FunctionGraphNode(3, :IDENTITY, [FunctionGraphConnection(1, 0.5, false)]),
            4 => FunctionGraphNode(4, :ADD, [
                FunctionGraphConnection(1, 0.3, false),
                FunctionGraphConnection(2, 0.6, false)
            ]),
            5 => FunctionGraphNode(5, :OUTPUT, [FunctionGraphConnection(3, 0.2, false), FunctionGraphConnection(4, 0.7, false)])
        )
    )

    # [Your inject_noise! implementations here]

    # Testing deterministic noise injection
    @testset "Deterministic Noise Injection" begin
        noise_map = Dict(3 => [0.1], 4 => [-0.1, 0.1], 5 => [0.05, -0.05])
        inject_noise!(genotype, noise_map)

        @test genotype.nodes[3].input_connections[1].weight ≈ 0.6
        @test genotype.nodes[4].input_connections[1].weight ≈ 0.2
        @test genotype.nodes[4].input_connections[2].weight ≈ 0.7
        @test genotype.nodes[5].input_connections[1].weight ≈ 0.25
        @test genotype.nodes[5].input_connections[2].weight ≈ 0.65
    end

    # Testing stochastic noise injection
    @testset "Stochastic Noise Injection" begin
        # Storing original weights to compare after noise injection
        original_weights = Dict(
            3 => copy([conn.weight for conn in genotype.nodes[3].input_connections]),
            4 => copy([conn.weight for conn in genotype.nodes[4].input_connections]),
            5 => copy([conn.weight for conn in genotype.nodes[5].input_connections])
        )

        # Injecting stochastic noise
        inject_noise!(rng, genotype, std_dev=0.2)

        # Verifying that weights have changed after noise injection
        @test any(original_weights[3] .!= [conn.weight for conn in genotype.nodes[3].input_connections])
        @test any(original_weights[4] .!= [conn.weight for conn in genotype.nodes[4].input_connections])
        @test any(original_weights[5] .!= [conn.weight for conn in genotype.nodes[5].input_connections])
    end

end


function validate_genotype(geno::FunctionGraphGenotype, function_map::Dict{Symbol, GraphFunction})
    # 1. Ensure Unique IDs
    function_map = FUNCTION_MAP
    ids = Set{Int}()
    for (id, node) in geno.nodes
        @assert id == node.id "ID mismatch in node dictionary and node struct"
        @assert !(id in ids) "Duplicate node ID: $id"
        push!(ids, id)
    end
    
    # 2. Output Node Constraints & 3. Input Constraints
    for (id, node) in geno.nodes
        is_output_node = id in geno.output_node_ids
        for conn in node.input_connections
            if is_output_node
                @assert !conn.is_recurrent "Output nodes must have nonrecurrent inputs"
            else
                @assert conn.is_recurrent "Non-output nodes must have recurrent inputs"
            end
        end
    end
    
    # 4. Avoid Output as Input
    for (id, node) in geno.nodes
        if id in geno.output_node_ids
            continue  # Skip the output nodes
        end
        for conn in node.input_connections
            @assert !(conn.input_node_id in geno.output_node_ids) "Output node serving as input"
        end
    end
    
    # 5. Ensure Proper Arity
    for (_, node) in geno.nodes
        expected_arity = function_map[node.func].arity
        @assert length(node.input_connections) == expected_arity "Incorrect arity for function $(node.func)"
    end
        # 6. Validate input connection ids
    for (_, node) in geno.nodes
        for conn in node.input_connections
            @assert haskey(geno.nodes, conn.input_node_id) "Input node id $(conn.input_node_id) does not exist in the network"
        end
    end
end


function apply_mutation_storm(mutator::FunctionGraphMutator, genotype::FunctionGraphGenotype, n_storms::Int)
    # Use the mutate function, applying n_storms mutations
    rng = Random.MersenneTwister(1234)
    gene_id_counter = Counter(7)  # Assume some counter
    phenotype_creator = DefaultPhenotypeCreator()
    output_length_equals_expected = Bool[]
    
    for _ in 1:n_storms
        genotype = mutate(mutator, rng, gene_id_counter, genotype)
        #println("---------------------")
        #pretty_print(genotype)
        validate_genotype(genotype, mutator.function_map)
        phenotype = create_phenotype(phenotype_creator, genotype)
        reset!(phenotype)
        input_values = [1.0, -1.0]
        outputs = [round(act!(phenotype, input_values)[1], digits=3) for _ in 1:10]
        #println(outputs)
        push!(output_length_equals_expected, length(outputs) == 10)
    end
    @test all(output_length_equals_expected)
end

@testset "Mutation Storm" begin
    genotype = FunctionGraphGenotype(
        input_node_ids = [1, 2], 
        bias_node_ids = [3],
        hidden_node_ids = [4, 5],
        output_node_ids = [6],
        nodes = Dict(
            1 => FunctionGraphNode(1, :INPUT, []),
            2 => FunctionGraphNode(2, :INPUT, []),
            3 => FunctionGraphNode(3, :BIAS, []),
            4 => FunctionGraphNode(4, :ADD, [
                FunctionGraphConnection(1, 1.0, true), 
                FunctionGraphConnection(3, 1.0, true)
            ]),
            5 => FunctionGraphNode(5, :ADD, [
                FunctionGraphConnection(2, 1.0, true), 
                FunctionGraphConnection(4, 1.0, true)
            ]),
            6 => FunctionGraphNode(6, :OUTPUT, [
                FunctionGraphConnection(5, 1.0, false)
            ])
        )
    )
    mutator = FunctionGraphMutator()  # You may customize this
    
    n_storms = 100_000  # Number of mutation storms
    apply_mutation_storm(mutator, genotype, n_storms)
end

println("Finished tests for FunctionGraphs.")