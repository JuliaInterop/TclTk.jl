module TclTkColorTests

using TclTk
using Test
using Colors
using Colors.FixedPointNumbers: N0f8, N0f16, N0f32, N0f64

function compute_significant_bits(::Type{T}) where {T<:AbstractFloat}
    isbitstype(T) || throw(ArgumentError("type `$T` is not a bits type"))
    nmax = 8*sizeof(T) - 1 # at least one bit for sign
    for nbits in 0:nmax
        try
            i = one(Int128) << nbits
            x = convert(T, i)
            x == i && x - one(x) == i - one(i) || return nbits - 1
        catch ex
            return nbits - 1
        end
    end
    error("cannot determine the number of bits in the mantissa of `$T`")
end

@testset "Tk Colors" begin
    let reinterpret_as_fixed_point = TclTk.Impl.reinterpret_as_fixed_point
        @test reinterpret_as_fixed_point(0x00) == zero(N0f8)
        @test reinterpret_as_fixed_point(0xff) == one(N0f8)
        @test reinterpret_as_fixed_point(0x0000) == zero(N0f16)
        @test reinterpret_as_fixed_point(0xffff) == one(N0f16)
        @test reinterpret_as_fixed_point(0x00000000) == zero(N0f32)
        @test reinterpret_as_fixed_point(0xffffffff) == one(N0f32)
        @test reinterpret_as_fixed_point(typemin(UInt64)) == zero(N0f64)
        @test reinterpret_as_fixed_point(typemax(UInt64)) == one(N0f64)
    end
    let reinterpret_as_colorant = TclTk.Impl.reinterpret_as_colorant
        t = (0x01, 0x02, 0x03)
        c = RGB{N0f8}(map(x -> x/0xff, t)...)
        @test reinterpret_as_colorant(t) === c
        @test reinterpret_as_colorant(t...) === c
        t = (0x03, 0x05, 0x04, 0xaf)
        c = RGBA{N0f8}(map(x -> x/0xff, t)...)
        @test reinterpret_as_colorant(t) === c
        @test reinterpret_as_colorant(t...) === c
        t = (0x01a0, 0x02a1, 0x03a3)
        c = RGB{N0f16}(map(x -> x/0xffff, t)...)
        @test reinterpret_as_colorant(t) === c
        @test reinterpret_as_colorant(t...) === c
        t = (0x03da, 0x05db, 0x04df, 0xafe0)
        c = RGBA{N0f16}(map(x -> x/0xffff, t)...)
        @test reinterpret_as_colorant(t) === c
        @test reinterpret_as_colorant(t...) === c
    end
    let significant_bits = TclTk.Impl.significant_bits
        @test significant_bits(Float16) == compute_significant_bits(Float16)
        @test significant_bits(Float32) == compute_significant_bits(Float32)
        @test significant_bits(Float64) == compute_significant_bits(Float64)
    end
    let max_exact_int = TclTk.Impl.max_exact_int
        @test max_exact_int(BigFloat) == typemax(Int128)
    end
end

end # module
