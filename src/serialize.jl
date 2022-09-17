struct InvokeEdge{T}
    invokesig
    node::T
end

struct CallGraphNode
    mi::MethodInstance
    safeedges::Vector{Bool}    # safeedges[i] if mi.backedges[i] cannot be invalidated (purely internal)
    callees::Set{InvokeEdge{CallGraphNode}}
end
CallGraphNode(mi::MethodInstance) = CallGraphNode(mi, fill(false, length(mi.backedges)), InvokeEdge{CallGraphNode}[])

"""
    collect_method_extensions(mod::Module) → method_extensions

Collect all methods added in `mod` or one of its submodules that extend an external function.
"""
function collect_method_extensions(worklist)
    method_extensions = Method[]
    visit() do item    # visit the whole system
        item isa Module && item ∈ worklist && return false # skip items already attached to worklist
        if item isa Method
            item.module ∈ worklist && push!(method_extensions, item)
            return false
        end
        return true
    end
    return method_extensions
end

function split_internal_external(worklist, external_method_instances)
    method_extensions = Method[]
    all_nodes = Dict{MethodInstance,CallGraphNode}()
    visit_withmodule() do (item, mod)    # visit the whole system
        # iscached = inworklist || (item isa MethodInstance && item ∈ external_method_instances)
        if item isa Method
            mod ∉ worklist && item.module ∈ worklist && push!(method_extensions, item)
            return true # continue on to the MethodInstances
        end
        if item isa MethodInstance
            @assert !haskey(all_nodes, item)
            all_nodes[item] = CallGraphNode(item)
            return false
        end
        return true
    end
    # Assemble the forward edges
    for (mi, node) in all_nodes
        if isdefined(mi, :backedges)
        for (idxs, (invokesig, caller)) in pairs(Core.Compiler.BackedgeIterator(mi.backedges))
            callernode = all_nodes[caller]
            push!(callernode.callees, InvokeEdge(invokesig, node))
        end
    end
    # For the to-be-cached MethodInstances, tag their backedges as to whether they can be cached in-place
    # or whether they require validation, and assemble the list of callees that require validation
    validated_callees = InvokeEdge{MethodInstance}[]
    caller_validations = Pair{MethodInstance,Vector{Int}}[]  # mi => idxs, where mi depends on validated_callees[idxs]
    for itr in (worklist, method_extensions, external_method_instances)
        for x in itr
            visit(x) do item
                if item isa MethodInstance
                    # FINISH ME
                    return false
                end
                return true
            end
        end
    end
end
