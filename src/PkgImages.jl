module PkgImages

using Core: MethodInstance, CodeInstance
using MethodAnalysis

## Move to Base

struct EdgePairs
    itr::Core.Compiler.BackedgeIterator
end
Base.pairs(itr::Core.Compiler.BackedgeIterator) = EdgePairs(itr)
function Base.iterate(itr::EdgePairs, i::Int=1)
    i0 = i
    ret = iterate(itr.itr)
    ret === nothing && return nothing
    edge, i = ret
    return i0:i-1 => edge, i
end

## End move to Base

include("serialize.jl")
include("deserialize.jl")

end
