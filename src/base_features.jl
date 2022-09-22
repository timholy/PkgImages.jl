## Features in Base that might see wider usage and may deserve PRs on their own

# Rework SkipMissing as SkipValue and implement `skipnothing`
skipnothing(itr) = SkipValue{Base.nonnothingtype(eltype(itr))}(itr, nothing)

struct SkipValue{T,I,V}
    itr::I
    val::V
end
SkipValue{T}(itr, val) = SkipValue{T,typeof(itr),typeof(val)}(itr, val)
SkipValue(itr, val) = SkipValue{eltype(itr)}(itr, val)

# Backwards compatibility:
# const SkipMissing{I} = SkipValue{Base.nonmissingtype(eltype(I)),I,Missing}

IteratorSize(::Type{<:SkipValue}) = SizeUnknown()
IteratorEltype(::Type{SkipValue{T,I,V}}) where {T,I,V} = IteratorEltype(I)
eltype(::Type{<:SkipValue{T}}) where {T} = T

function iterate(itr::SkipValue, state...)
    _isequal(x, y) = x == y
    _isequal(x, ::Missing) = x === missing
    _isequal(x, ::Nothing) = x === nothing

    y = iterate(itr.itr, state...)
    y === nothing && return nothing
    item, state = y
    while _isequal(item, itr.val)
        y = iterate(itr.itr, state)
        y === nothing && return nothing
        item, state = y
    end
    item, state
end

# Iterator-indexing support via `pairs` for backedges---not sure we actually need this

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
