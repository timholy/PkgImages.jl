using PkgImages
using MethodAnalysis
using Test

function clear_precompiled!(mis)
    foreach(mis) do mi
        mi.precompiled = false
    end
end
clear_precompiled() = clear_precompiled!(methodinstances())

macro track_mis(expr)
    return quote
        empty!(Core.Compiler.newly_inferred)
        Core.Compiler.track_newly_inferred.x = true
        try
            $expr
        finally
            Core.Compiler.track_newly_inferred.x = false
        end
        Core.Compiler.newly_inferred
    end
end

function make_staleA(M::Module)
    @eval M module StaleA
        stale(x) = rand(1:8)
        stale(x::Int) = length(digits(x))
        not_stale(x::String) = first(x)

        use_stale(c) = stale(c[1]) + not_stale("hello")
        build_stale(x) = use_stale(Any[x])
        # force precompilation
        build_stale(37)
        stale('c')

        nbits(::Int8) = 8
        nbits(::Int16) = 16

        # for invoke
        invk(::Int) = 1
        invk(::Integer) = 2
    end
end

function make_staleB(M::Module)
    @eval M module StaleB
        using ..StaleA
        # This will be invalidated if StaleC is loaded unless we manually remove backedges
        useA() = StaleA.stale("hello")
        useA()

        call_nbits(x::Integer) = StaleA.nbits(x)
        map_nbits() = map(call_nbits, Integer[Int8(1), Int16(1)])
        map_nbits()

        callinvk(x) = invoke(StaleA.invk, Tuple{Integer}, x)
        callinvk(3)
    end
end

function make_staleC(M::Module)
    @eval M module StaleC
        using ..StaleA
        StaleA.stale(x::String) = length(x)
        call_buildstale(x) = StaleA.build_stale(x)

        call_buildstale("hey")
    end
end

#@testset "PkgImages.jl" begin
    # clear_precompiled()

    # Check that new specializations of Base methods are placed in `external_method_instances`
    mis_digits_pre = methodinstances(digits)
    M = Module()
    mis = @track_mis make_staleA(M)
    method_extensions, external_method_instances, targets, caller_targetidxs = PkgImages.split_internal_external([M.StaleA], mis)
    @test isempty(method_extensions)
    mis_digits_post = methodinstances(digits)
    newmis_digits = setdiff(mis_digits_post, mis_digits_pre)
    @test newmis_digits ⊆ external_method_instances
    # Check handling of edges to non-worklist callables
    callers_with_extedges = first.(caller_targetidxs)
    missing_edge_mis = filter(mi -> mi ∉ callers_with_extedges, external_method_instances)
    target_mis = map(tgt -> tgt.callee, targets)
    @test missing_edge_mis ⊆ target_mis
    foreach(missing_edge_mis) do mi
        # None of these have generic callees, not sure of the best way to test that
        # This is very specific to our test case
        @test Tuple{String, DataType, String, Int64} ∈ mi.specTypes.parameters || isdefined(mi.cache, :rettype_const)
    end
    uncached_example = methodinstance(iterate, (UnitRange{Int}, Int))  # this should already be compiled
    @test uncached_example ∈ target_mis
    @test uncached_example ∉ external_method_instances
    # All targets match a unique method
    @test extrema(tgt -> length(tgt.matches), targets) == (1, 1)
    method_extensionsA, external_method_instancesA, targetsA, caller_targetidxsA =
        method_extensions, external_method_instances, targets, caller_targetidxs
    mis_staleA = methodinstances(M.StaleA.stale)


    mis = @track_mis make_staleB(M)
    method_extensions, external_method_instances, targets, caller_targetidxs = PkgImages.split_internal_external([M.StaleB], mis; extra_modules=[M])
    @test isempty(method_extensions)
    mis_staleB = methodinstances(M.StaleA.stale)
    mi = only(setdiff(mis_staleB, mis_staleA))
    @test mi ∈ external_method_instances
#end
