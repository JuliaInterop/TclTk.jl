module TclTkImageTests

using TclTk
using Test
using Colors
using Colors.FixedPointNumbers: N0f8, N0f16

@testset "Tk Images" begin
    props = sort!([:handle, :height, :inuse, :name, :size, :type, :width])

    # Bitmap image.
    xbm = @inferred TkBitmap(file=joinpath(@__DIR__, "rule.xbm"))

    # Image properties.
    @test sort!(collect(propertynames(xbm))) == props
    @test xbm.type === :bitmap
    @test xbm.inuse === false
    @test xbm.name isa TclObj
    @test startswith(string(xbm.name), "image")
    @test xbm.width === 32
    @test xbm.height === 17
    @test xbm.size === (32, 17)

    # Image keys.
    @test haskey(xbm, :data) === true
    @test haskey(xbm, :file) === true
    @test haskey(xbm, :foreground) === true
    @test haskey(xbm, :maskdata) === true
    @test haskey(xbm, :maskfile) === true
    @test haskey(xbm, :non_existing_option) === false
    path = convert(String, @inferred xbm[:file])
    @test isfile(path)
    @test endswith(path, "rule.xbm")
    @test path == @inferred xbm["file"]
    @test path == @inferred xbm["-file"]
    @test path == @inferred xbm.cget(:file)
    @test path == @inferred xbm.cget(String, :file)
    @test path == @inferred xbm.cget("file")
    @test path == @inferred xbm.cget(String, "file")
    @test path == @inferred xbm.cget("-file")
    @test path == @inferred xbm.cget(String, "-file")
    color = "cyan"
    @inferred xbm.configure(foreground = color)
    @test color == @inferred xbm.cget(:foreground)
    color = "red"
    @inferred xbm.configure(:foreground => color)
    @test color == @inferred xbm.cget(:foreground)
    color = "green"
    @inferred xbm.configure("foreground" => color)
    @test color == @inferred xbm.cget("foreground")
    color = "blue"
    @inferred xbm.configure("-foreground", color)
    @test color == @inferred xbm.cget("-foreground")

    # Change content.
    xbm[:file] = joinpath(@__DIR__, "letters.xbm")
    @test xbm.size === (47, 35)
    path = convert(String, @inferred xbm[:file])
    @test isfile(path)
    @test endswith(path, "letters.xbm")

    # Photo image.
    png = @inferred TkPhoto("m51", :file => joinpath(@__DIR__, "m51-tiny.png"))
    @test png isa TkPhoto

    # Image properties.
    @test sort!(collect(propertynames(png))) == props
    @test png.type === :photo
    @test png.inuse === false
    @test png.name == "m51"
    @test png.width === 48
    @test png.height === 64
    @test png.size === (48, 64)

    # Image keys.
    @test haskey(png, :non_existing_option) === false
    @test haskey(png, :file) === true
    path = convert(String, @inferred png[:file])
    @test isfile(path)
    @test endswith(path, "m51-tiny.png")

    # Abstract array API for photo images.
    @test @inferred(ndims(png)) === 2
    @test @inferred(ndims(typeof(png))) === 2
    @test @inferred(eltype(png)) === RGBA{N0f8}
    @test @inferred(eltype(typeof(png))) === RGBA{N0f8}
    @test @inferred(size(png)) === png.size
    @test @inferred(length(png)) === prod(png.size)

end

end # module
