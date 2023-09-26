export splice_function

using Random: rand, AbstractRNG

using ......CoEvo.Utilities.Counters: Counter
using ..Genotypes: BasicGeneticProgramGenotype
using ..Genotypes.Utilities: get_ancestors, get_descendents, all_nodes
using ..Mutators: BasicGeneticProgramMutator

import ..Genotypes.Mutations: splice_function

"""
    splice_function(rng::AbstractRNG, gene_id_counter::Counter, ::BasicGeneticProgramMutator, geno::BasicGeneticProgramGenotype)

Randomly splice a function node's subtree into another part of the genotype tree.

# Arguments:
- `rng::AbstractRNG`: Random number generator.
- `gene_id_counter::Counter`: Counter for unique gene IDs.
- `::BasicGeneticProgramMutator`: Mutator operations for genetic programming.
- `geno::BasicGeneticProgramGenotype`: Genotype to splice function into.

# Returns:
- A new `BasicGeneticProgramGenotype` with the spliced function subtree.
"""
function splice_function(
    rng::AbstractRNG, 
    gene_id_counter::Counter,
    ::BasicGeneticProgramMutator, 
    geno::BasicGeneticProgramGenotype
)
    # select a function node at random for splicer_top_id
    if length(geno.functions) == 0
        return deepcopy(geno)
    end
    splicer_top = rand(rng, collect(values(geno.functions)))

    
    # Get all descendents of splicer_top_id for potential splicer_tail_id
    descendents = get_descendents(geno, splicer_top.id)
    splicer_tail = rand(rng, descendents)

    # Identify all nodes not in the lineage of splicer_top and splicer_tail for splicee_id
    lineage_nodes = [get_ancestors(geno, splicer_top.id); splicer_top; descendents]
    lineage_ids = Set(n.id for n in lineage_nodes)
    all_node_ids = Set(n.id for n in values(all_nodes(geno)))
    spliceable = setdiff(all_node_ids, lineage_ids)
    
    # If there are no spliceable nodes, return original genotype
    if isempty(spliceable)
        return deepcopy(geno)
    end

    splicee_id = rand(rng, spliceable)
    
    return splice_function(geno, splicer_top.id, splicer_tail.id, splicee_id)
end