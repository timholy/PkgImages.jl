# Step 1: check external edges and insert backedges (uncached callees). For these, the edges and callees must be stored in a separate list
# Step 2: check new edges for non-worklist callables (cached callees). For these, the edges can be stored in callee.backedges.

function insert_external_edges(targets::Vector{ExternalTarget}, caller_targetidxs)
    # Note: `targets` must already correspond to the MIs in the running system
    # These targets are not cached
    valids =  map(still_valid, targets)
    for (caller, targetidxs) in caller_targetidxs
        !has_active_codeinst(caller) && continue   # already invalidated
        if all(i -> valids[i], targetidxs)
            foreach(targetidxs) do i
                target = targets[i]
                insert_backedge!(target.callee, target.invokesig, caller)
            end
        else
            # TODO: logging
            invalidate!(caller)
        end
    end
end

function validate_cached_callee(callee::MethodInstance; validsigs = IdDict{Any,Bool}())
    # This is necessary only when the callable is not worklist-owned
    # Consolidate the unique invokesigs
    empty!(validsigs)
    validsigs[nothing] = true   # initially mark as valid, but we'll check once the unique invokesigs have been identified
    for (invokesig, caller) in BackedgeIterator(callee.backedges)
        !has_active_codeinst(caller) && continue   # already invalidated
        if invokesig !== nothing
            validsigs[invokesig] = true
        end
    end
    # Check each unique invokesig
    for invokesig in keys(validsigs)
        validsigs[invokesig] = still_valid(invokesig, callee)
    end
    # Invalidate the no-longer-valid callers
    for (invokesig, caller) in BackedgeIterator(callee.backedges)
        !has_active_codeinst(caller) && continue   # already invalidated
        if !validsigs[invokesig]
            # TODO: logging
            invalidate!(caller)
        end
    end
end

# Call this for both `method_extensions` and `external_method_instances`, but not `worklist`
function validate_cached_callees(method_extensions::Vector{Method})
    validsigs = IdDict{Any,Bool}()   # allocate work-storage once
    foreach(m -> validate_cached_callees(skipnothing(m.specializations); validsigs), method_extensions)
end
validate_cached_callees(method_instances; kwargs...) = foreach(mi -> validate_cached_callee(mi; kwargs...), method_instances)

## Utils

function has_active_codeinst(mi::MethodInstance, world=get_world_counter())
    isdefined(mi, :cache) || return false
    ci = mi.cache
    while true
        ci.max_world >= world && return true
        isdefined(ci, :next) || return false
        ci = ci.next
    end
    return false
end

function still_valid(target::ExternalTarget, world=get_world_counter())
    (; invokesig, callee, matches) = target
    currentmatches = get_matches(invokesig, callee, world)
    if currentmatches === false || length(currentmatches) != length(matches)
        return false
    end
    return all(match -> method(match) ∈ matches, currentmatches)
end

function invalidate!(mi::MethodInstance, world=get_world_counter())
    # TODO: logging
    isdefined(mi, :cache) && invalidate!(mi.cache, world)
    isdefined(mi, :backedges) || return nothing
    for (_, caller) in BackedgeIterator(mi.backedges)
        has_active_codeinst(caller, world) || continue
        invalidate!(caller, world)
    end
    empty!(mi.backedges)
    return nothing
end
function invalidate!(ci::CodeInstance, world=get_world_counter())
    while true
        if ci.max_world == typemax(ci.max_world)
            ci.max_world = world
        end
        isdefined(ci, :next) || break
        ci = ci.next
    end
end

insert_backedge!(callee::MethodInstance, @nospecialize(invokesig), caller) =
    insert_backedge!(callee.backedges, invokesig, caller)

function insert_backedge!(backedges, @nospecialize(invokesig), caller)
    if invokesig !== nothing
        push!(backedges, invokesig)
    end
    push!(backedges, caller)
end

function insert_backedge!(::Nothing, @nospecialize(invokesig), caller)
    ft = Base.unwrap_unionall(invokesig).parameters[1]
    mt = ft.name.mt
    push!(mt.backedges, invokesig, caller)
end

function merge_backedges!(active, inactive)
    activeset = Set{InvokeEdgeMI}()
    for (invokesig, caller) in BackedgeIterator(active)
        push!(activeset, InvokeEdgeMI(invokesig, caller))
    end
    for (invokesig, caller) in BackedgeIterator(inactive)
        edge = InvokeEdgeMI(invokesig, caller)
        edge ∉ activeset && insert_backedge!(active, invokesig, caller)
    end
    return active
end
