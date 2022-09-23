# Steps at serialization:
# - pull out forward-edges to non-cached MethodInstances & create:
#   + targets::Vector{ExternalTarget}
#   + caller_targetidxs::Vector{Pair{MethodInstance,Vector{Int}}}
# - pull out `method_extensions`
# - pull out `external_method_instances`
# Serialize all these quantities plus the worklist items

"""
    getmodule(mi::MethodInstance) → mod

Return the module that "owns" `mi`.
"""
function getmodule(mi::MethodInstance)
    m = mi.def
    isa(m, Module) && return m
    return m.module
end

"""
    needed_by_worklist!(is_needed::AbstractDict{MethodInstance,Union{Bool,Missing}}, mi::MethodInstance, worklist)::Bool

Determine whether `mi` is called, directly or indirectly, by anything owned by a module in `worklist`.
`is_needed` is internal storage needed for efficient operation, and after the call `isneed[mi]` holds the
same value that is returned by the function.
"""
function needed_by_worklist!(is_needed::AbstractDict{MethodInstance,Union{Bool,Missing}}, mi::MethodInstance, worklist)
    needed = get(is_needed, mi, nothing)
    isa(needed, Bool) && return needed
    needed === missing && return false  # break cycles
    if mi.precompiled || getmodule(mi) ∈ worklist
        is_needed[mi] = true
        return true
    end
    if !isdefined(mi, :backedges)
        is_needed[mi] = false
        return false
    end
    is_needed[mi] = missing
    for (_, caller) in BackedgeIterator(mi.backedges)
        if caller isa MethodInstance
            if needed_by_worklist!(is_needed, caller, worklist)
                is_needed[mi] = true
                return true
            end
        end
    end
    is_needed[mi] = false
    return false
end

"""
    split_internal_external(worklist, newly_inferred) →
        method_extensions, external_method_instances, targets, caller_targetidxs

Given a list `worklist` of modules to be cached, and a collection of `newly_inferred` MethodInstances,
split the entire system into categories with different caching needs:

    - `method_extensions` is a list of `Method`s that are added to callables that are not owned by
      modules in `worklist`. For example, if the package defines a new method for `Base.sort`,
      then this method will be added to `method_extensions`. Methods in `method_extensions` will be cached.
    - `external_method_instances` are newly-inferred specializations of uncached methods. These, together
      with all MethodInstances "owned" by `worklist` modules or by methods in `method_extensions`, will be cached.
    - `targets` is a `Vector{Target}` listing uncached direct dependencies of cached MethodInstances.
      These list items that lie on the boundary between cached and uncached in the global call graph.
      When the package is loaded, these items will need to have backedges inserted from cached MethodInstances.
    - `caller_targetidxs` is the complement to `targets`, it lists `caller => targetidxs` pairs
      where `targetidxs` is the set of `target` indices needed by `caller`.
"""
function split_internal_external(worklist, newly_inferred::AbstractSet)
    # outputs to compute (Dicts will be converted on output)
    method_extensions = Method[]
    targets = Dict{Target,Int}()   # uncached items that are called by cached items
    caller_targetidxs = Dict{MethodInstance,Vector{Int}}()  # which targets does a MethodInstance require?
    # working storage
    is_needed = Dict{MethodInstance,Union{Bool,Missing}}()   # includes all MIs
    is_cached = Dict{MethodInstance,Bool}()   # includes needed MIs

    visit_withmodule() do item, mod  # visit the whole system
        if item isa Module
            println(item)
        end
        item === Main && return false
        if item isa MethodTable && isdefined(item, :backedges) && item.module ∉ worklist
            # This MethodTable will not be cached, but let's see if it's a target of a cached item
            for (callsig, caller) in BackedgeIterator(item.backedges)
                if caller ∈ newly_inferred  # not all newly-inferred MIs will be cached, but all cached MIs are newly-inferred
                    idx = get!(targets, Target(callsig, nothing), length(targets)+1)
                    push!(get!(Vector{Int}, caller_targetidxs, caller), idx)
                end
            end
            return true
        end
        if item isa Method
            # Check whether the worklist added this method to an external (non-worklist) function
            mod ∉ worklist && item.module ∈ worklist && push!(method_extensions, item)
            return true # continue on to the MethodInstances
        end
        if item isa MethodInstance
            # Determine whether this MI is needed (directly or indirectly) by anything in the worklist,
            # and if so whether it will be cached.
            if needed_by_worklist!(is_needed, item, worklist)
                is_cached[item] = item.precompiled || getmodule(item) ∈ worklist || item ∈ newly_inferred ||
                                    (m = item.def; m isa Method && m ∈ method_extensions)
            end
            return false
        end
        return true
    end
    # Assemble the remaining forward edges to external targets, and collect the to-be-cached external MethodInstances
    external_method_instances = MethodInstance[]
    for (mi, iscached) in is_cached
        if !iscached
            for (invokesig, caller) in BackedgeIterator(mi.backedges)   # backedges must be defined as mi would otherwise not be needed
                if get(is_cached, caller, false)
                    idx = get!(targets, Target(invokesig, mi), length(targets)+1)
                    push!(get!(Vector{Int}, caller_targetidxs, caller), idx)
                end
            end
        elseif getmodule(mi) ∉ worklist && mi ∈ newly_inferred
            push!(external_method_instances, mi)
        end
    end
    # Convert the outputs & return
    targets = ExternalTarget.(first.(sort!(collect(targets); by=last)))
    caller_targetidxs = collect(caller_targetidxs)
    return method_extensions, external_method_instances, targets, caller_targetidxs
end
split_internal_external(worklist, newly_inferred) = split_internal_external(worklist, Set(newly_inferred))
