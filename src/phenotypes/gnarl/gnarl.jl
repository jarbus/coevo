module GnarlNetworks

export GnarlNetworkPhenotype, GnarlNetworkPhenotypeNeuron, GnarlNetworkPhenotypeInputConnection
export GnarlNetworkPhenotypeNodeOperation

import ..Phenotypes: act!, reset!, create_phenotype

using ...Genotypes.GnarlNetworks: GnarlNetworkGenotype, get_neuron_positions
using ..Phenotypes: Phenotype, PhenotypeCreator

struct GnarlNetworkPhenotypeNeuron
    position::Float32
    output::Base.RefValue{Float32}
end

function GnarlNetworkPhenotypeNeuron(position::Float32, output::Float32)
    GnarlNetworkPhenotypeNeuron(position, Ref(output))
end

function get_output(neuron::GnarlNetworkPhenotypeNeuron)
    neuron.output[]
end

function set_output!(neuron::GnarlNetworkPhenotypeNeuron, output::Float32)
    neuron.output[] = output
end

struct GnarlNetworkPhenotypeInputConnection
    input_node::GnarlNetworkPhenotypeNeuron
    weight::Float32
end

struct GnarlNetworkPhenotypeNodeOperation
    input_connections::Vector{GnarlNetworkPhenotypeInputConnection}
    output_node::GnarlNetworkPhenotypeNeuron
end

struct GnarlNetworkPhenotype <: Phenotype
    n_input_nodes::Int
    n_output_nodes::Int
    neurons::Dict{Float32, GnarlNetworkPhenotypeNeuron}
    operations::Vector{GnarlNetworkPhenotypeNodeOperation}
end

function Base.show(io::IO, neuron::GnarlNetworkPhenotypeNeuron)
    println(io, "Neuron(Position: $(neuron.position), Output: $(get_output(neuron)))")
end

function Base.show(io::IO, conn::GnarlNetworkPhenotypeInputConnection)
    println(io, "Connection(InputNode Position: $(conn.input_node.position), Weight: $(conn.weight))")
end

function Base.show(io::IO, op::GnarlNetworkPhenotypeNodeOperation)
    println(io, "Node Operation(OutputNode Position: $(op.output_node.position), #Connections: $(length(op.input_connections)))")
end

function Base.show(io::IO, phenotype::GnarlNetworkPhenotype)
    println(io, "GnarlNetwork Phenotype(#Input Nodes: $(phenotype.n_input_nodes), #Output Nodes: $(phenotype.n_output_nodes), #Neurons: $(length(phenotype.neurons)), #Operations: $(length(phenotype.operations)))")
end


function create_phenotype(::PhenotypeCreator, genotype::GnarlNetworkGenotype)
    neuron_positions = get_neuron_positions(genotype)
    neurons = Dict(
        position => GnarlNetworkPhenotypeNeuron(position, 0.0f0)
        for position in neuron_positions
    )
    connection_map = Dict(
        position => filter(
            connection -> connection.destination == position, 
            genotype.connections
        ) 
        for position in neuron_positions
    )
    operations = [
        GnarlNetworkPhenotypeNodeOperation(
            [
                GnarlNetworkPhenotypeInputConnection(
                    neurons[connection.origin], connection.weight
                ) 
                for connection in connection_map[position]
            ], 
            neurons[position]
        ) 
        for position in neuron_positions
    ]
    phenotype = GnarlNetworkPhenotype(
        genotype.n_input_nodes, genotype.n_output_nodes, neurons, operations
    )
    return phenotype
end

function reset!(phenotype::GnarlNetworkPhenotype)
    for neuron in values(phenotype.neurons)
        set_output!(neuron, 0.0f0)
    end
end

function act!(
    phenotype::GnarlNetworkPhenotype,
    inputs::Vector{Float32}
)
    if length(inputs) != phenotype.n_input_nodes
        throw(ArgumentError("Wrong number of inputs for $phenotype"))
    end
    operations = phenotype.operations
    for i in 1:phenotype.n_input_nodes
        set_output!(operations[i].output_node, inputs[i])
    end
    set_output!(operations[phenotype.n_input_nodes + 1].output_node, 1.0f0) # Bias
    start_operation_idx = phenotype.n_input_nodes + 2
    for operation in operations[start_operation_idx:end]
        sum = 0.0f0
        for i = eachindex(operation.input_connections)
            input_connection = operation.input_connections[i]
            connection_output = get_output(input_connection.input_node) * input_connection.weight
            sum += connection_output
        end
        set_output!(operation.output_node, tanh(2.5f0 * sum))
    end
    outputs = [
        get_output(operations[end - phenotype.n_output_nodes + i].output_node) 
        for i in 1:phenotype.n_output_nodes
    ]
    return outputs
end

act!(phenotype::GnarlNetworkPhenotype, inputs::Vector{Float64}) = act!(phenotype, Float32.(inputs))

act!(phenotype::GnarlNetworkPhenotype, input::Real) = act!(phenotype, [input])

end