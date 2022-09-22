module PkgImages

using Core: MethodInstance, CodeInstance, MethodTable, MethodMatch
using Core.Compiler: BackedgeIterator
using Base: IdSet, get_world_counter
using MethodAnalysis

struct InvokeEdge{T}
    invokesig
    node::T
end
const InvokeEdgeMI = InvokeEdge{MethodInstance}

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
    matches::Vector{Methods}
end
ExternalTarget(@nospecialize(invokesig), callee) = ExternalTarget(invokesig, callee, method.(get_matches(invokesig, callee)))

method(match::MethodMatch) = match.method

# NOTE: Base._methods_by_ftype/jl_matching_methods need to take an additional `intersection::Bool` argument and pass it
#       to ml_matches
get_matches(@nospecialize(invokesig::Type), ::MethodInstance, world=get_world_counter()) =
    Base._methods_by_ftype(invokesig, -1, world, false) # `invoke` subtyping dispatch
get_matches(@nospecialize(invokesig), callee, world=get_world_counter()) =
    Base._methods_by_ftype(callee === nothing ? invokesig : callee.specTypes, -1, world, true)   # intersectional dispatch

include("base_features.jl")
include("serialize.jl")
include("deserialize.jl")

end
