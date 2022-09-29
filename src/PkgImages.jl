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
ExternalTarget(@nospecialize(invokesig), callee) = _external_target(invokesig, callee, get_matches(invokesig, callee))
_external_target(@nospecialize(invokesig), callee, match::MethodMatch) = ExternalTarget(invokesig, callee, [match.method])
_external_target(@nospecialize(invokesig), callee, matches) = ExternalTarget(invokesig, callee, method.(matches))
ExternalTarget(target::Target) = ExternalTarget(target.invokesig, target.node)

method(match::MethodMatch) = match.method

function get_matches(@nospecialize(invokesig::Type), mi::MethodInstance, world=get_world_counter())
    m = mi.def
    isa(m, Method) || error("no matches for toplevel ", mi)
    mt = ccall(:jl_method_get_table, Any, (Any,), m)
    isa(mt, MethodTable) || error("expected MethodTable, got ", mt, " from ", mi, ", a specialization of ", mi.def)
    ret = Core.Compiler._findsup(invokesig, mt, world)
    mm = first(ret)
    isa(mm, MethodMatch) || error("expected MethodMatch, got ", mm, " from mt=", mt, ", invokesig=", invokesig, ", mi=", mi, ", a specialization of ", mi.def)
    return mm
end
get_matches(@nospecialize(invokesig), callee, world=get_world_counter()) =
    Base._methods_by_ftype(callee === nothing ? invokesig : callee.specTypes, -1, world)   # intersectional dispatch

include("base_features.jl")
include("serialize.jl")
include("deserialize.jl")

end
