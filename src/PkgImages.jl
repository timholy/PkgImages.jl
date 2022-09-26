module PkgImages

using Core: MethodInstance, CodeInstance, MethodTable, MethodMatch
using Core.Compiler: BackedgeIterator
using Base: IdSet, get_world_counter
using MethodAnalysis

struct InvokeEdge{T}
    invokesig
    node::T
end
const CalledBy = InvokeEdge{MethodInstance}               # specifies a caller, including any `invoke` signature used by the caller
const Target = InvokeEdge{Union{MethodInstance,Nothing}}  # specifies a callee (`nothing` is for an abstract call to MethodTable)

"""
    ExternalTarget(invokesig, callee, matches)

A callee "target" (half of a forward-edge) with a record of how that target was assigned.

Kinds of targets:
- `ExternalTarget(nothing, callee::MethodInstance, matches::Vector{Methods})`: standard concrete inferrable dispatch
- `ExternalTarget(invokesig, callee::MethodInstance, matches::Vector{Methods})`: `invoke`-dispatch
- `ExternalTarget(sig, nothing, matches::Vector{Methods})`: abstract dispatch using a MethodTable
"""
struct ExternalTarget
    invokesig
    callee::Union{MethodInstance,Nothing}
    matches::Vector{Method}
end
ExternalTarget(@nospecialize(invokesig), callee) = ExternalTarget(invokesig, callee, method.(get_matches(invokesig, callee)))
ExternalTarget(target::Target) = ExternalTarget(target.invokesig, target.node)

method(match::MethodMatch) = match.method

# NOTE: Base._methods_by_ftype/jl_matching_methods need to take an additional `intersection::Bool` argument and pass it
#       to ml_matches
function get_matches(@nospecialize(invokesig::Type), mi::MethodInstance, world=get_world_counter())
    mt = ccall(:jl_method_get_table, Any, (Method,), mi.def)::MethodTable
    return first(Core.Compiler._findsup(invokesig, mt, world))
end
get_matches(@nospecialize(invokesig), callee, world=get_world_counter()) =
    Base._methods_by_ftype(callee === nothing ? invokesig : callee.specTypes, -1, world)   # intersectional dispatch

include("base_features.jl")
include("serialize.jl")
include("deserialize.jl")

end
