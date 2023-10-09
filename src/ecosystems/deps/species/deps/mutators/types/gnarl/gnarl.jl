module GnarlNetworks

export mutate_weight, GnarlNetworkMutator, mutate_weights, add_node, remove_node
export add_connection, remove_connection, get_neuron_positions, find_valid_connection_positions
export find_available_nodes, get_next_layer, get_previous_layer, create_random_connection
export replace_connection, redirect_or_replace_connection, remove_node_from_genotype
export remove_node_2

using StatsBase: Weights, sample
using ....Species.Genotypes.Abstract: Genotype
using Random: AbstractRNG, shuffle!
using .....Ecosystems.Utilities.Counters: Counter, next!
using  ...Mutators.Abstract: Mutator
using ....Genotypes.GnarlNetworks: GnarlNetworkGenotype, GnarlNetworkConnectionGene, GnarlNetworkNodeGene
using ....Genotypes.GnarlNetworks.GnarlMethods: get_neuron_positions

import ...Mutators.Interfaces: mutate





# function find_available_nodes(geno::GnarlNetworkGenotype, nodes::Vector{Float32})
#     occupied_nodes = Set{Float32}()
#     for conn in geno.connections
#         if conn.origin in nodes
#             push!(occupied_nodes, conn.destination)
#         end
#     end
#     all_nodes = Set(get_neuron_positions(geno))
#     return setdiff(all_nodes, occupied_nodes)
# end

function find_available_nodes(geno::GnarlNetworkGenotype, nodes::Vector{Float32})
    occupied_nodes = Set{Float32}()
    for conn in geno.connections
        if conn.origin in nodes
            push!(occupied_nodes, conn.destination)
        end
    end
    all_nodes = filter(position -> position > 0.0, Set(get_neuron_positions(geno)))
    return setdiff(all_nodes, union(occupied_nodes, Set(nodes)))
end


function get_next_layer(geno::GnarlNetworkGenotype, nodes::Vector{Float32})
    downstream_nodes = Set{Float32}()
    for conn in geno.connections
        if conn.origin in nodes
            push!(downstream_nodes, conn.destination)
        end
    end
    return collect(downstream_nodes)
end

function get_previous_layer(geno::GnarlNetworkGenotype, nodes::Vector{Float32})
    upstream_nodes = Set{Float32}()
    for conn in geno.connections
        if conn.destination in nodes
            push!(upstream_nodes, conn.origin)
        end
    end
    return collect(upstream_nodes)
end

function create_random_connection(geno::GnarlNetworkGenotype)
    possible_nodes = [node.position for node in geno.hidden_nodes]
    
    origin = rand(possible_nodes)
    destination = rand(possible_nodes)
    
    while origin == destination
        destination = rand(possible_nodes)
    end
    
    return GnarlNetworkConnectionGene(
        id=maximum([conn.id for conn in geno.connections]) + 1,
        origin=origin,
        destination=destination,
        weight=0.0f0
    )
end

function replace_connection(
    geno::GnarlNetworkGenotype, 
    old_conn::GnarlNetworkConnectionGene, 
    new_conn::GnarlNetworkConnectionGene
)
    new_connections = deepcopy(geno.connections)
    new_connections[findfirst(x -> x == old_conn, new_connections)] = new_conn
    return GnarlNetworkGenotype(geno.n_input_nodes, geno.n_output_nodes, geno.hidden_nodes, new_connections)
end

function exists_connection(geno::GnarlNetworkGenotype, origin::Float32, destination::Float32)
    return any(conn -> conn.origin == origin && conn.destination == destination, geno.connections)
end

function redirect_or_replace_connection(
        geno::GnarlNetworkGenotype,
        connection::GnarlNetworkConnectionGene,
        direction::Symbol
    )
    
    current_nodes = direction == :incoming ? [connection.destination] : [connection.origin]
    source_node = direction == :incoming ? connection.origin : connection.destination
    println("current_nodes: $current_nodes")
    println("source_node: $source_node")
    
    new_destination = connection.destination
    new_origin = connection.origin
    println("new_destination: $new_destination")
    println("new_origin: $new_origin")
    
    while !isempty(current_nodes)
        
        # Fetch the next layer of nodes
        if direction == :incoming
            next_nodes = get_next_layer(geno, current_nodes)
            println("next_nodes after get_next_layer: $next_nodes")
        else
            next_nodes = get_previous_layer(geno, current_nodes)
            println("next_nodes after get_previous_layer: $next_nodes")
        end
        
        # Remove nodes that already have a connection with the source_node
        next_nodes = filter(n -> !exists_connection(geno, source_node, n), next_nodes)
        println("next_nodes after filtering: $next_nodes")
        
        # If we find available nodes, then redirect the connection and return
        if !isempty(next_nodes)
            println("Found available nodes")
            if direction == :incoming
                new_destination = rand(next_nodes)
                println("new_destination: $new_destination")
            else
                new_origin = rand(next_nodes)
                println("new_origin: $new_origin")
            end
            
            break  # Exit the while loop if we've found a redirect
        end
        
        println("No available nodes, continuing to next layer")
        current_nodes = next_nodes
        println("current_nodes: $current_nodes")
    end
    
    if new_destination == connection.destination && new_origin == connection.origin
        all_nodes_except_source = filter(
            position -> position > 0.0, setdiff(get_neuron_positions(geno), [source_node])
        )
        # Filter nodes to only those that don't already have a connection with the source_node
        all_nodes_except_source = filter(n -> !exists_connection(geno, source_node, n), all_nodes_except_source)
        
        if length(all_nodes_except_source) > 1
            new_origin, new_destination = sample(all_nodes_except_source, 2, replace=false)
        else
            throw(ErrorException("Network too small for redirection"))
        end
    end

    if direction == :incoming && new_destination == connection.destination
        println("new_destination: $new_destination")
        println("new_origin: $new_origin")
        throw(ErrorException("Invalid connection"))
    end
    if direction == :outgoing && new_origin == connection.origin
        println("new_destination: $new_destination")
        println("new_origin: $new_origin")
        throw(ErrorException("Invalid connection"))
    end
    
    # Create a new connection object with updated values
    new_connection = GnarlNetworkConnectionGene(
        id = connection.id, 
        origin = new_origin, 
        destination = new_destination, 
        weight = connection.weight
    )
    println("new_connection: $new_connection")
    return new_connection
end


# Updated based on the immutability of GnarlNetworkGenotype
function remove_node_from_genotype(geno::GnarlNetworkGenotype, node_to_remove::GnarlNetworkNodeGene)
    new_hidden_nodes = filter(node -> node != node_to_remove, geno.hidden_nodes)
    return GnarlNetworkGenotype(geno.n_input_nodes, geno.n_output_nodes, new_hidden_nodes, geno.connections)
end

function remove_node_2(
        geno::GnarlNetworkGenotype,
        node_to_remove::GnarlNetworkNodeGene
    )
    
    incoming_connections = filter(x -> x.destination == node_to_remove.position, geno.connections)
    outgoing_connections = filter(x -> x.origin == node_to_remove.position, geno.connections)
    
    new_geno = deepcopy(geno)
    
    new_incoming_connections = GnarlNetworkConnectionGene[]
    for conn in incoming_connections
        new_conn = redirect_or_replace_connection(new_geno, conn, :incoming)
        push!(new_incoming_connections, new_conn)
        #new_geno = replace_connection(new_geno, conn, new_conn)
    end
    
    new_outgoing_connections = GnarlNetworkConnectionGene[]
    for conn in outgoing_connections
        new_conn = redirect_or_replace_connection(new_geno, conn, :outgoing)
        push!(new_outgoing_connections, new_conn)
        # new_geno = replace_connection(new_geno, conn, new_conn)
    end
    for (old_conn, new_conn) in zip(incoming_connections, new_incoming_connections)
        new_geno = replace_connection(new_geno, old_conn, new_conn)
    end

    for (old_conn, new_conn) in zip(outgoing_connections, new_outgoing_connections)
        new_geno = replace_connection(new_geno, old_conn, new_conn)
    end
    
    # Now, remove the target node
    return remove_node_from_genotype(new_geno, node_to_remove)
end


"Mutate the weight of genes"
function mutate_weight(
    rng::AbstractRNG, connection::GnarlNetworkConnectionGene, weight_factor::Float64
)
    connection = GnarlNetworkConnectionGene(
        connection.id, 
        connection.origin, 
        connection.destination, 
        connection.weight + randn(rng) * weight_factor, 
    )
    return connection
end

# function mutate_weights(rng::AbstractRNG, geno::GnarlNetworkGenotype, weight_factor::Float64)
#     connections = mutate_weight.(rng, geno.connections, weight_factor)
#     geno = GnarlNetworkGenotype(
#         geno.n_input_nodes, geno.n_output_nodes, geno.hidden_nodes,  connections
#     )
#     return geno
# end

function mutate_weights(rng::AbstractRNG, geno::GnarlNetworkGenotype, weight_factor::Float64)
    # Pick a random index from the connections
    if length(geno.connections) == 0
        return geno
    end
    
    connections = [
        mutate_weight(rng, connection, weight_factor) for connection in geno.connections
    ]
    
    # Return a new GnarlNetworkGenotype with the mutated connection
    geno = GnarlNetworkGenotype(
        geno.n_input_nodes, geno.n_output_nodes, geno.hidden_nodes, connections
    )
    return geno
end

function add_node(geno::GnarlNetworkGenotype, gene_id::Int, position::Float32)
    node = GnarlNetworkNodeGene(gene_id, position)
    hidden_nodes = [geno.hidden_nodes; node]
    genotype = GnarlNetworkGenotype(
        geno.n_input_nodes, geno.n_output_nodes, hidden_nodes, geno.connections
    )
    return genotype
end

function add_node(rng::AbstractRNG, gene_id_counter::Counter, geno::GnarlNetworkGenotype)
    gene_id = next!(gene_id_counter)
    position = Float32(rand(rng))
    geno = add_node(geno, gene_id, position)
    return geno
end

function indexof(a::Array{Float32}, f::Float32)
    index = findall(x->x==f, a)[1]
    return index
end


function find_valid_connection_positions(geno::GnarlNetworkGenotype)
    neuron_positions = get_neuron_positions(geno)
    n_neurons = length(neuron_positions)
    # Valid neuron pairs
    valid = trues(n_neurons, n_neurons)
    # Remove existing ones
    for connection in geno.connections
        origin_index = indexof(neuron_positions, connection.origin)
        destination_index = indexof(neuron_positions, connection.destination)
        valid[origin_index, destination_index] = false
    end

    for original_index in 1:n_neurons
        orig_pos = neuron_positions[original_index]
        for destination in 1:n_neurons
            destination_position = neuron_positions[destination]
            # Remove links towards input neurons and bias neuron
            if destination_position <= 0
                valid[original_index, destination] = false
            end
            # Remove links between output neurons (would not support adding a neuron)
            if orig_pos >= 1 
                valid[original_index, destination] = false
            end
        end
    end
    # Filter invalid ones
    connections = findall(valid)
    return connections
end

function remove_node(
    geno::GnarlNetworkGenotype, 
    node_to_remove::GnarlNetworkNodeGene,
    connections_to_remove::Vector{GnarlNetworkConnectionGene},
    connections_to_add::Vector{GnarlNetworkConnectionGene}
)
    remaining_nodes = filter(x -> x != node_to_remove, geno.hidden_nodes)
    pruned_connections = filter(x -> x ∉ connections_to_remove, geno.connections)
    new_connections = [pruned_connections; connections_to_add]
    geno = GnarlNetworkGenotype(
        geno.n_input_nodes, geno.n_output_nodes, remaining_nodes, new_connections
    )
    return geno
end

function create_connection(
    rng::AbstractRNG,
    gene_id_counter::Counter,
    geno::GnarlNetworkGenotype
)
    valid_connections = find_valid_connection_positions(geno)
    if length(valid_connections) == 0
        return
    end
    shuffle!(rng, valid_connections) # Pick random
    neuron_positions = get_neuron_positions(geno)
    origin = neuron_positions[valid_connections[1][1]]
    destination = neuron_positions[valid_connections[1][2]]
    if destination <= 0 # Catching error where destination is an input
        throw("Invalid connection")
    end
    gene_id = next!(gene_id_counter)
    new_connection = GnarlNetworkConnectionGene(gene_id, origin, destination, 0.0f0)
    return new_connection
end

function remove_node(rng::AbstractRNG, gene_id_counter::Counter, geno::GnarlNetworkGenotype)
    if length(geno.hidden_nodes) == 0
        return geno
    end
    node_to_remove = rand(rng, geno.hidden_nodes)
    connections_to_remove = filter(
        x -> x.origin == node_to_remove.position || x.destination == node_to_remove.position, 
        geno.connections
    )
    pruned_connections = filter(
        x -> x ∉ connections_to_remove,  geno.connections
    )
    pruned_nodes = filter(x -> x != node_to_remove, geno.hidden_nodes)
    pruned_genotype = GnarlNetworkGenotype(
        geno.n_input_nodes, geno.n_output_nodes, pruned_nodes, pruned_connections
    )
    connections_to_add = GnarlNetworkConnectionGene[]
    for i in 1:length(connections_to_remove)
        result = create_connection(rng, gene_id_counter, pruned_genotype)
        if result !== nothing
            push!(connections_to_add, result)
            
        end
    end
    geno = remove_node(geno, node_to_remove, connections_to_remove, connections_to_add)
    return geno
end

function add_connection(
    geno::GnarlNetworkGenotype, gene_id::Int, origin::Float32, destination::Float32
)
    new_connection = GnarlNetworkConnectionGene(gene_id, origin, destination, 0.0f0)
    genotype = GnarlNetworkGenotype(
        geno.n_input_nodes, 
        geno.n_output_nodes, 
        geno.hidden_nodes, 
        [geno.connections; new_connection]
    )
    return genotype
end

"Add a connection between 2 random neurons"
function add_connection(rng::AbstractRNG, gene_id_counter::Counter, geno::GnarlNetworkGenotype)
    valid_connections = find_valid_connection_positions(geno)
    if length(valid_connections) == 0
        return geno
    end
    shuffle!(rng, valid_connections) # Pick random
    neuron_positions = get_neuron_positions(geno)
    origin = neuron_positions[valid_connections[1][1]]
    destination = neuron_positions[valid_connections[1][2]]
    if destination <= 0 # Catching error where destination is an input
        throw("Invalid connection")
    end
    gene_id = next!(gene_id_counter)
    geno = add_connection(geno, gene_id, origin, destination)
    return geno
end

function remove_connection(
    geno::GnarlNetworkGenotype, connection::GnarlNetworkConnectionGene
)
    remaining_connections = filter(x -> x != connection, geno.connections)
    genotype = GnarlNetworkGenotype(
        geno.n_input_nodes, geno.n_output_nodes, geno.hidden_nodes, remaining_connections
    )
    return genotype
end

function remove_connection(rng::AbstractRNG, ::Counter, geno::GnarlNetworkGenotype)
    if length(geno.connections) == 0
        return geno
    end
    connection_to_remove = rand(rng, geno.connections) # pick a random gene
    geno = remove_connection(geno, connection_to_remove)
    return geno
end


Base.@kwdef struct GnarlNetworkMutator <: Mutator
    n_changes::Int = 1
    probs::Dict{Function, Float64} = Dict(
        add_node => 0.25,
        remove_node => 0.25,
        add_connection => 0.25,
        remove_connection => 0.25
    )
    weight_factor::Float64 = 0.1
end

function mutate(
    mutator::GnarlNetworkMutator, 
    rng::AbstractRNG, 
    gene_id_counter::Counter, 
    geno::GnarlNetworkGenotype
)
    geno_before = geno
    geno = mutate_weights(rng, geno, mutator.weight_factor)
    functions = collect(keys(mutator.probs))
    function_weights = Weights(collect(values(mutator.probs)))
    mutation_functions = sample(rng, functions, function_weights, mutator.n_changes)
    guilty = nothing
    for mutation_function in mutation_functions
        geno = mutation_function(rng, gene_id_counter, geno)
        guilty = mutation_function
    end
    neuron_positions = get_neuron_positions(geno)
    origin_nodes = [gene.origin for gene in geno.connections]
    destination_nodes = [gene.destination for gene in geno.connections]
    for node in union(origin_nodes, destination_nodes) 
        if node ∉ neuron_positions
            throw(ErrorException("Invalid mutation: $guilty, node removed but not from links"))
        end
        node_gene_ids = Set(gene.id for gene in geno.hidden_nodes)
        if length(node_gene_ids) != length(geno.hidden_nodes)
            throw(ErrorException("Invalid mutation: $guilty, duplicate node ids"))
        end

        connection_gene_ids = Set(gene.id for gene in geno.connections)
        if length(connection_gene_ids) != length(geno.connections)
            throw(ErrorException("Invalid mutation: $guilty, duplicate connection ids"))
        end
    end
    return geno
end

end
    # println("-------------REMOVE NODE----------")
    # println("geno: $geno")
    # println("node_to_remove: $node_to_remove")
    # println("connections_to_remove: $connections_to_remove")
    # println("pruned_connections: $pruned_connections")
    # println("pruned_nodes: $pruned_nodes")
    # println("pruned_genotype: $pruned_genotype")
    # println("connections_to_add: $connections_to_add")
    # println("remaining_nodes: $remaining_nodes")
    # println("pruned_connections: $pruned_connections")
    # println("new_connections: $new_connections")
    # println("new geno: $geno")

    # println("------------MUTATE----------")
    # println("geno_before: $geno_before")
    # println("neuron_positions: $neuron_positions")
    # println("origin_nodes: $origin_nodes")
    # println("destination_nodes: $destination_nodes")
    # println("geno: $geno")