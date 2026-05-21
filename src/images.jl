#
# images.jl -
#
# Manipulation of Tk images.


# TODO Attach a callback to the image so that its handle is cleared when the image is
#      destroyed.

# Union of colorants that can be directly handled by a `TkPhoto`.
const PhotoColorant = Union{Gray{N0f8},GrayA{N0f8},AGray{N0f8},
                            RGB{N0f8},RGBA{N0f8},ARGB{N0f8},
                            BGR{N0f8},BGRA{N0f8},ABGR{N0f8}}

"""
    TkImage{type}(pairs...; kwds...) -> img
    TkImage{type}(name, pairs...; kwds...) -> img

Return a Tk image of given `type` (e.g., `:bitmap` or `:photo`).

If the image `name` is omitted, it is automatically generated. If `name` is specified and an
image with this name already exists, it is re-used and, if options are specified, it is
reconfigured.

Trailing `pairs...` arguments and keywords `kwds...` are interpreted as image configuration
options. Possible options depend on the image types.

A Tk image can then be used in any Tcl/Tk script or command where an image is expected.

Tk images implement the abstract array API. To extract the pixels of an image, the
`img[x,y]` syntax may be used with `x` and `y` pixel indices or ranges. For a `:photo`
image, pixel values are represented by `RGBA{N0f8}` colors.

A Tk image has a number of properties:

```julia
img.inuse    # whether an image is in use in a Tk widget
img.width    # the width of the image in pixels
size(img, 1) # idem
img.height   # the height of the image in pixels
size(img, 2) # idem
img.size     # (width, height)
size(img)    # idem
img.type     # the symbolic type of the image (`:bitmap`, `:photo`, etc.)
img.name     # the image name
img.handle   # the image handle
```

# See also

[`TkBitmap`](@ref) and [`TkPhoto`](@ref) are aliases for specific image types.

"""
function TkImage{type}(pairs::Pair...; kwds...) where {type}
    # Create a new image of a given type and automatically named.
    type isa Symbol || argument_error("image type must be a symbol")
    name = tcl_exec(TclObj, :image, :create, type, pairs...; kwds...)
    return _TkImage(Val(type), name)
end

function TkImage{type}(name::Name, pairs::Pair...; kwds...) where {type}
    # Create a new image of a given type and name. If an image of the same name already
    # exists, it is re-wrapped.
    type isa Symbol || argument_error("image type must be a symbol")
    name = tcl_exec(TclObj, "::_jl::image_create_or_config", type, name, pairs...; kwds...)
    return _TkImage(Val(type), name)
end

"""
    TkImage(name, pairs...; kwds...) -> img

Return an instance of `TkImage` managing Tk image named `name` and after applying any
options specified by `pairs...` and `kwds...`.

"""
TkImage(name::Name, pairs::Pair...; kwds...) = TkImage(TclObj(name), pairs...; kwds...)
function TkImage(name::TclObj, pairs::Pair...; kwds...)
    type = tcl_exec(Symbol, :image, :type, name)
    (isempty(pairs) && isempty(kwds)) || tcl_exec(Nothing, name, :configure, pairs...; kwds...)
    return _TkImage(Val(type), name)
end

"""
    TkPhoto([name,] arr::AbstractMatrix) -> img

Return an instance of `TkImage{:photo}` whose pixels are set with the values of `arr`.
Optional `name` argument is to specify the image's name.

"""
function TkPhoto(arr::AbstractMatrix{<:Colorant})
    (width, height) = size(arr)
    img = TkPhoto(width = width, height = height)
    img[:,:] = arr
    return img
end

function TkPhoto(name::Name, arr::AbstractMatrix{<:Colorant})
    (width, height) = size(arr)
    img = TkPhoto(name, width = width, height = height)
    img[:,:] = arr
    return img
end

# For Tcl, an image is identified by its name.
TclObj(img::TkImage) = img.name
Base.convert(::Type{TclObj}, img::TkImage) = TclObj(img)::TclObj
unsafe_objptr(img::TkImage) = unsafe_objptr(TclObj(img), "Tk image") # used in `exec`
Base.print(io::IO, img::TkImage) = print(io, img.name)

Base.show(io::IO, ::MIME"text/plain", img::TkImage) = show(io, img)

function Base.show(io::IO, img::T) where {T<:TkImage}
    if T == TkBitmap
        print(io, "TkBitmap (alias for TkImage{:bitmap})")
    elseif T == TkPhoto
        print(io, "TkPhoto (alias for TkImage{:photo})")
    else
        print(io, T)
    end
    dims = size(img)
    print(io, " name = \"", img.name, "\", size = (", dims[1], ", ", dims[2], ")")
    return nothing
end

for f in (:isequal, :(==))
    @eval begin
        Base.$f(a::T, b::T) where {T<:TkImage} = $f(a.name, b.name)
        Base.$f(a::TkImage, b::TkImage) = false
    end
end

#---------------------------------------------------------------------- Image sub-commands -

# Make Tk image objects callable to evaluate sub-commands.
(img::TkImage)(args...; kwds...) = tcl_exec(img, args...; kwds...)
(img::TkImage)(::Type{T}, args...; kwds...) where {T} = tcl_exec(T, img, args...; kwds...)

#------------------------------------------------------------------------ Image properties -

Base.propertynames(img::TkImage) = (:handle, :height, :inuse, :name, :size, :type, :width,)

@inline Base.getproperty(img::TkImage, key::Symbol) = _getproperty(img, Val(key))
_getproperty(img::TkImage, ::Val{:handle}) = getfield(img, :handle)
_getproperty(img::TkImage, ::Val{:height}) = image_height(img)
_getproperty(img::TkImage, ::Val{:inuse}) = image_inuse(img)
_getproperty(img::TkImage, ::Val{:name}) = getfield(img, :name)
_getproperty(img::TkImage, ::Val{:size}) = size(img)
_getproperty(img::TkImage{T}, ::Val{:type}) where {T} = T
_getproperty(img::TkImage, ::Val{:width}) = image_width(img)

# Reproduce Tk `image command ...`.
for (prop, T) in (:delete => :Nothing,
                  :height => :Int,
                  :inuse  => :Bool,
                  :size   => :(Tuple{Int,Int}),
                  :type   => :TclObj,
                  :width  => :Int,
                  )
    jl_func = Symbol("image_", prop)
    tcl_proc = "::_jl::image_" * String(prop)
    @eval begin
        $jl_func(img::TkImage) = tcl_exec($T, $tcl_proc, img)
    end
end

# Optimized accessors for Tk photo images.
for (func, expr) in (:image_width => :(Int(width)::Int),
                     :image_height => :(Int(height)::Int),
                     :image_size => :((Int(width)::Int, Int(height)::Int)))
    @eval function $func(img::TkPhoto)
        width, height = GC.@preserve img unsafe_get_photo_size(img)
        return $expr
    end
end

#-------------------------------------------------------------------- Photo core functions -

function unsafe_get_photo_size(img::TkPhoto)
    # Here the handle can be NULL.
    return unsafe_get_photo_size(unchecked_photo_handle(img))
end
function unsafe_get_photo_size(handle::Tk_PhotoHandle)
    width = Ref{Cint}(𝟘)
    height = Ref{Cint}(𝟘)
    isnull(handle) || Tk_PhotoGetSize(handle, width, height)
    return (width[], height[])
end

# Return Tk photo handle, may be NULL.
function unchecked_photo_handle(img::TkPhoto)
    return Tk_PhotoHandle(getfield(img, :handle))::Tk_PhotoHandle
end

# Return non-NULL Tk photo handle.
function checked_photo_handle(img::TkPhoto)
    handle = unchecked_photo_handle(img)
    isnull(handle) && TclError("invalid NULL Tk photo handle")
    return handle
end

Base.unsafe_convert(::Tk_PhotoHandle, img::TkPhoto) = checked_photo_handle(img)

# Resize Tk photo image. If image must be resized, its content is not preserved.
Base.resize!(img::TkPhoto, (width, height)::Tuple{Integer,Integer}) =
    resize!(img, width, height)

function Base.resize!(img::TkPhoto, width::Integer, height::Integer)
    width ≥ 𝟘 || argument_error("width must be nonnegative, got $width")
    width ≤ typemax(Cint) || argument_error("width is too large, got $width")
    height ≥ 𝟘 || argument_error("height must be nonnegative, got $height")
    height ≤ typemax(Cint) || argument_error("height is too large, got $height")
    GC.@preserve img begin
        handle = checked_photo_handle(img)
        current_width, current_height = unsafe_get_photo_size(handle)
        if width != current_width || height != current_height
            # Not clear (from Tcl/Tk doc.) why the following should be done and I had to
            # dive into the source code TkImgPhoto.c to figure out how to actually resize
            # the image (just calling Tk_PhotoSetSize with the correct size yields
            # segmentation fault).
            status = Tk_PhotoSetSize(C_NULL, handle, zero(Cint), zero(Cint))
            status == TCL_OK || TclError("cannot set Tk photo size")
            status = Tk_PhotoExpand(C_NULL, handle, width, height)
            status == TCL_OK || TclError("cannot expand Tk photo")
        end
    end
    return img
end

unsafe_photo_get_image(img::TkPhoto) = unsafe_photo_get_image(unchecked_photo_handle(img))
function unsafe_photo_get_image(handle::Tk_PhotoHandle)
    isnull(handle) && return Tk_PhotoImageBlock(
        pointer=C_NULL, width=0, height=0, pitch=0, step=0, offset=(0,0,0,0))
    block = Ref{Tk_PhotoImageBlock}()
    Tk_PhotoGetImage(handle, block)
    return block[]
end

# Unsafe: pointer and ROI must be valid.
function unsafe_store_pixels!(img::TkPhoto, ptr::Ptr{C},
                              x::Integer, y::Integer, width::Integer, height::Integer,
                              comprule::Integer) where {C<:PhotoColorant}
    unsafe_store_pixels!(unchecked_photo_handle(img), ptr, x, y, width, height, comprule)
end

function unsafe_store_pixels!(handle::Tk_PhotoHandle, ptr::Ptr{C},
                              x::Integer, y::Integer, width::Integer, height::Integer,
                              comprule::Integer) where {C<:PhotoColorant}
    isnull(handle) && TclError("invalid NULL Tk photo handle")
    block = Tk_PhotoImageBlock(
        pointer = ptr, width = width, height = height,
        pitch = sizeof(C)*width, step = sizeof(C), offset = offset_from_pixel_type(C))
    # In `Tk_PhotoPutBlock`, interpreter is only needed for error reporting and can be null.
    status = Tk_PhotoPutBlock(C_NULL, handle, Ref(block), x, y, width, height, comprule)
    status == TCL_OK || Tcl_Error("cannot put image block in Tk photo image")
    return nothing
end

function unsafe_photo_put_block(img::TkPhoto,
                                block::Tk_PhotoImageBlock,
                                x::Integer, y::Integer, width::Integer,
                                height::Integer, comprule::Integer)
    handle = checked_photo_handle(img)
    status = Tk_PhotoPutBlock(C_NULL, handle, Ref(block), x, y, width, height, comprule)
    status == TCL_OK || TclError("cannot put image block in Tk photo image")
    return nothing
end

function unsafe_photo_put_zoomed_block(img::TkPhoto,
                                       block::Tk_PhotoImageBlock,
                                       x::Integer, y::Integer,
                                       width::Integer, height::Integer,
                                       zoomx::Integer, zoomy::Integer,
                                       subsamplex::Integer, subsampley::Integer,
                                       comprule::Integer)
    handle = checked_photo_handle(img)
    status = Tk_PhotoPutZoomedBlock(C_NULL, handle, ref(block), x, y, width, height,
                                    zoomx, zoomy, subsamplex, subsampley, comprule)
    status == TCL_OK || TclError("cannot put zoomed image block in Tk photo image")
    return nothing
end

#--------------------------------------------------------------------- Image configuration -

# Image configurable options are available by indexing the image with the option name
# without the leading hyphen and specified as a string or as a symbol.

# Known image options are stored in a vector (faster than a dictionary considered the small
# number of image types).
const image_options = Pair{Symbol,Vector{String}}[]

function get_options(img::TkImage{type}) where {type}
    global image_options
    for (key,opts) in image_options
        key === type && return opts
    end
    opts = String[stripfirst(fetch(String, spec, 1)) for spec in img.configure()]
    push!(image_options, type => opts)
    return opts
end

function stripfirst(s::AbstractString)
    start = firstindex(s)
    stop = lastindex(s)
    start ≤ stop && (start = nextind(s, start))
    return SubString(s, start, stop)
end

function Base.haskey(img::TkImage, key::Union{String,SubString{String},Symbol})
    GC.@preserve key begin
        ptr = Base.unsafe_convert(Ptr{UInt8}, key)
        for opt in get_options(img)
            iszero(@ccall strcmp(ptr::Ptr{UInt8}, opt::Ptr{UInt8})::Cint) && return true
        end
    end
    return false
end

#----------------------------------------------------------- Abstract array API for images -

# 32-bit RGBA is the pixel format used by Tk for its photo images.
Base.eltype(::Type{<:TkPhoto}) = RGBA{N0f8}

Base.ndims(img::TkImage) = ndims(typeof(img))
Base.ndims(::Type{<:TkImage}) = 2

Base.IteratorSize(::Type{<:TkImage}) = Base.HasShape{2}()

Base.length(img::TkImage) = prod(size(img))

Base.size(img::TkImage) = image_size(img)
Base.size(img::TkImage, i::Integer) =
    i == 1 ? image_width(img) :
    i == 2 ? image_height(img) :
    i ≥ 3 ? 1 : throw(BoundsError("out of bounds dimension index"))

function Base.getindex(img::TkPhoto, ::Colon, ::Colon)
    GC.@preserve img begin
        block = ImageBlock{UInt8,Int}(unsafe_photo_get_image(img))
        return unsafe_load_pixels(Matrix{eltype(img)}, block)
    end
end

function Base.getindex(img::TkPhoto, xrng::ViewRange, yrng::ViewRange)
    GC.@preserve img begin
        block = ImageBlock{UInt8,Int}(unsafe_photo_get_image(img))
        block = restrict_xrange(block, xrng)
        block = restrict_yrange(block, yrng)
        return unsafe_load_pixels(Matrix{eltype(img)}, block)
    end
end

function Base.getindex(img::TkPhoto, x::Integer, yrng::ViewRange)
    GC.@preserve img begin
        block = ImageBlock{UInt8,Int}(unsafe_photo_get_image(img))
        block = restrict_xrange(block, x)
        block = restrict_yrange(block, yrng)
        return unsafe_load_pixels(Vector{eltype(img)}, block)
    end
end

function Base.getindex(img::TkPhoto, xrng::ViewRange, y::Integer)
    GC.@preserve img begin
        block = ImageBlock{UInt8,Int}(unsafe_photo_get_image(img))
        block = restrict_xrange(block, xrng)
        block = restrict_yrange(block, y)
        return unsafe_load_pixels(Vector{eltype(img)}, block)
    end
end

function Base.getindex(img::TkPhoto, x::Integer, y::Integer)
    GC.@preserve img begin
        block = unsafe_photo_get_image(img)
        return unsafe_load_pixel(eltype(img), block, x, y)
    end
end

function Base.setindex!(img::TkPhoto, A::Colorant, x::Integer, y::Integer)
    width, height = size(img)
    check_pixel_x_coordinate(x, width)
    check_pixel_y_coordinate(y, height)
    B = to_photo_colorant(A)
    ref = Ref(B)
    GC.@preserve img ref begin
        unsafe_store_pixels!(img, Base.unsafe_convert(Ptr{typeof(B)}, ref),
                             x, y, 1, 1, TK_PHOTO_COMPOSITE_SET)
    end
    return img
end

function Base.setindex!(img::TkPhoto, A::AbstractVector{<:Colorant},
                        xrng::ViewRange, y::Integer)
    width, height = size(img)
    xroi = check_pixel_x_range(xrng, width)
    check_pixel_y_coordinate(y, height)
    length(A) == length(xroi) || error(
        "array of pixel values and image region of interest have different sizes")
    B = to_photo_pixels(A)
    GC.@preserve img B begin
        unsafe_store_pixels!(img, Base.unsafe_convert(Ptr{eltype(B)}, B),
                             first(xroi), y, length(xroi), 1, TK_PHOTO_COMPOSITE_SET)
    end
    return img
end

function Base.setindex!(img::TkPhoto, A::AbstractVector{<:Colorant},
                        x::Integer, yrng::ViewRange)
    width, height = size(img)
    check_pixel_x_coordinate(x, width)
    yroi = check_pixel_y_range(yrng, height)
    length(A) == length(yroi) || error(
        "array of pixel values and image region of interest have different sizes")
    B = to_photo_pixels(A)
    GC.@preserve img B begin
        unsafe_store_pixels!(img, Base.unsafe_convert(Ptr{eltype(B)}, B),
                             x, first(yroi), 1, length(yroi), TK_PHOTO_COMPOSITE_SET)
    end
    return img
end

function Base.setindex!(img::TkPhoto, A::AbstractMatrix{<:Colorant},
                        xrng::ViewRange, yrng::ViewRange)
    width, height = size(img)
    xroi = check_pixel_x_range(xrng, width)
    yroi = check_pixel_y_range(yrng, height)
    size(A) == (length(xroi), length(yroi)) || error(
        "array of pixel values and image region of interest have different sizes")
    B = to_photo_pixels(A)
    GC.@preserve img B begin
        unsafe_store_pixels!(img, Base.unsafe_convert(Ptr{eltype(B)}, B),
                             first(xroi), first(yroi),
                             length(xroi), length(yroi), TK_PHOTO_COMPOSITE_SET)
    end
    return img
end

#-------------------------------------------------------------------------- Pixel colorant -

# Preferred colorant for conversion to a `TkPhoto`.
photo_colorant(c::Colorant) = photo_colorant(typeof(c))
photo_colorant(::Type{<:TransparentColor{<:Any,<:Any,4}}) = RGBA{N0f8}
photo_colorant(::Type{<:TransparentColor{<:Any,<:Any,2}}) = GrayA{N0f8}
photo_colorant(::Type{Color{<:Any,3}}) = RGB{N0f8}
photo_colorant(::Type{Color{<:Any,1}}) = Gray{N0f8}
for C in (:Gray, :GrayA, :AGray, :RGB, :BGR, :ARGB, :ABGR, :RGBA, :BGRA)
    @eval photo_colorant(::Type{<:$C}) = $C{N0f8}
end

to_photo_colorant(A::PhotoColorant) = A
function to_photo_colorant(A::Colorant)
    C = photo_colorant(A)
    return convert(C, A)::C
end

to_photo_pixels(A::DenseArray{<:PhotoColorant}) = A
to_photo_pixels(A::AbstractArray{<:Colorant}) =
    copyto!(Array{photo_colorant(eltype(A))}(undef, size(A)), A)

#----------------------------------------------------------------------------- Image block -

restrict_xrange(block::ImageBlock, ::Colon) = block

restrict_yrange(block::ImageBlock, ::Colon) = block

function restrict_xrange(block::ImageBlock{T,I}, xrng::AbstractUnitRange) where {T,I}
    ptr = block.pointer
    if isempty(xrng)
        width = zero(I)
    else
        xoff = first(xrng) - 𝟙
        (xoff ≥ 𝟘 && last(xrng) ≤ block.width) || error("out of bounds `x` index range")
        ptr += block.step*xoff
        width = convert(I, length(xrng))
    end
    return ImageBlock{T,I}(block; pointer = ptr, width = width)
end

function restrict_yrange(block::ImageBlock{T,I}, yrng::AbstractUnitRange) where {T,I}
    ptr = block.pointer
    if isempty(yrng)
        height = zero(I)
    else
        yoff = first(yrng) - 𝟙
        (yoff ≥ 𝟘 && last(yrng) ≤ block.height) || error("out of bounds `y` index range")
        ptr += block.pitch*yoff
        height = convert(I, length(yrng))
    end
    return ImageBlock{T,I}(block; pointer = ptr, height = height)
end

function restrict_xrange(block::ImageBlock{T,I}, x::Integer) where {T,I}
    (𝟙 ≤ x ≤ block.width) || error("out of bounds `x` index")
    return ImageBlock{T,I}(block; width = one(I),
                           pointer = block.pointer + block.step*(x - 𝟙))
end

function restrict_yrange(block::ImageBlock{T,I}, y::Integer) where {T,I}
    (𝟙 ≤ y ≤ block.height) || error("out of bounds `y` index")
    return ImageBlock{T,I}(block; height = one(I),
                           pointer = block.pointer + block.pitch*(y - 𝟙))
end

check_pixel_x_coordinate(x::Integer, width::Integer) =
    𝟙 ≤ x ≤ width ? nothing : error("out of bounds `x` pixel coordinate")

check_pixel_y_coordinate(y::Integer, height::Integer) =
    𝟙 ≤ y ≤ height ? nothing : error("out of bounds `y` pixel coordinate")

check_pixel_x_range(xrng::Colon, width::Integer) = 𝟙:(Int(width)::Int)
function check_pixel_x_range(xrng::AbstractUnitRange{<:Integer}, width::Integer)
    start, stop = first(xrng), last(xrng)
    start > stop || ((𝟙 ≤ start)&(stop ≤ width)) || error("out of bounds `x` pixel range")
    return (Int(start)::Int):(Int(stop)::Int)
end

check_pixel_y_range(yrng::Colon, height::Integer) = 𝟙:(Int(height)::Int)
function check_pixel_y_range(yrng::AbstractUnitRange{<:Integer}, height::Integer)
    start, stop = first(yrng), last(yrng)
    start > stop || ((𝟙 ≤ start)&(stop ≤ height)) || error("out of bounds `y` pixel range")
    return (Int(start)::Int):(Int(stop)::Int)
end

# Return the `offset` field of the `ImageBlock` given the pixel type. All colorants in
# `PhotoColorant` shall be allowed here.
offset_from_pixel_type(::Type{UInt8}) = (0, 0, 0, -1)
offset_from_pixel_type(::Type{Gray{ T}}) where {T} = (0, 0, 0, -1)
offset_from_pixel_type(::Type{GrayA{T}}) where {T} = (n = sizeof(T); return (0, 0, 0, n))
offset_from_pixel_type(::Type{AGray{T}}) where {T} = (n = sizeof(T); return (n, n, n, 0))
offset_from_pixel_type(::Type{RGB{  T}}) where {T} = (n = sizeof(T); return (0, n, 2n, -1))
offset_from_pixel_type(::Type{BGR{  T}}) where {T} = (n = sizeof(T); return (2n, n, 0, -1))
offset_from_pixel_type(::Type{RGBA{ T}}) where {T} = (n = sizeof(T); return (0, n, 2n, 3n))
offset_from_pixel_type(::Type{ARGB{ T}}) where {T} = (n = sizeof(T); return (n, 2n, 3n, 0))
offset_from_pixel_type(::Type{BGRA{ T}}) where {T} = (n = sizeof(T); return (2n, n, 0, 3n))
offset_from_pixel_type(::Type{ABGR{ T}}) where {T} = (n = sizeof(T); return (3n, 2n, n, 0))

# Constructors for `ImageBlock`.
function ImageBlock(block::ImageBlock; pointer::Ptr{T}, kwds...) where {T}
    return ImageBlock{T}(block; pointer=pointer, kwds...)
end

function ImageBlock{T}(block::ImageBlock; kwds...) where {T}
    return ImageBlock{T,Int}(block; kwds...)
end

function ImageBlock{T,I}(block::ImageBlock;
                         pointer::Ptr = block.pointer,
                         width::Integer = block.width,
                         height::Integer = block.height,
                         pitch::Integer = block.pitch,
                         step::Integer = block.step,
                         offset::NTuple{4,Integer} = block.offset) where {T,I}
    return ImageBlock{T,I}(pointer, width, height, pitch, step, offset)
end

function ImageBlock(; pointer::Ptr{T}, width::Integer, height::Integer,
                    pitch::Integer, step::Integer,
                    offset::NTuple{4,Integer}) where {T}
    return ImageBlock{T,Int}(pointer, width, height, pitch, step, offset)
end

function ImageBlock{T,I}(; pointer::Ptr, width::Integer, height::Integer,
                         pitch::Integer, step::Integer,
                         offset::NTuple{4,Integer}) where {T,I}
    return ImageBlock{T,I}(pointer, width, height, pitch, step, offset)
end

Base.convert(::Type{T}, block::T) where {T<:ImageBlock} = block
Base.convert(::Type{T}, block::ImageBlock) where {T<:ImageBlock} = T(block)::T

# Unsafe.
ImageBlock(arr::DenseMatrix{T}) where {T} = ImageBlock{T}(arr)
ImageBlock{T}(arr::DenseMatrix) where {T} = ImageBlock{T,Int}(arr)
function ImageBlock{T,I}(arr::DenseMatrix{E}) where {T,I,E<:Union{Colorant,UInt8}}
    width, height = size(arr)
    step = sizeof(E)
    return ImageBlock{T,I}(; pointer = pointer(arr),
                           width = width, height = height,
                           pitch = width*step, step = step,
                           offset = offset_from_pixel_type(E))
end

#----------------------------------------------------------------------------- Load pixels -

function unsafe_load_pixel(::Type{T}, block::ImageBlock,
                           x::Integer, y::Integer) where {T<:Colorant}
    (𝟙 ≤ x ≤ block.width) || error("out of bounds `x` index")
    (𝟙 ≤ y ≤ block.height) || error("out of bounds `y` index")
    ptr = Ptr{N0f8}(block.pointer) # always N0f8 format for each component
    ptr += block.step*(x - 𝟙) + block.pitch*(y - 𝟙)
    red_off, green_off, blue_off, alpha_off = block.offset
    if red_off == green_off == blue_off
        # Gray image.
        gray = unsafe_load(ptr + red_off)
        if alpha_off < 0 # no alpha channel
            return convert(T, Gray(gray))
        else
            alpha = unsafe_load(ptr + alpha_off)
            return convert(T, GrayA(gray, alpha))
        end
    else
        red   = unsafe_load(ptr +   red_off)
        green = unsafe_load(ptr + green_off)
        blue  = unsafe_load(ptr +  blue_off)
        if alpha_off < 0 # no alpha channel
            return convert(T, RGB(red, green, blue))
        elseif alpha_off == red_off + 3
            alpha = unsafe_load(ptr + alpha_off)
            return convert(T, RGBA(red, green, blue, alpha))
        end
    end
end

function unsafe_load_pixels(::Type{Vector{T}}, block::ImageBlock) where {T<:Colorant}
    # Pointer to first pixel in red channel (always N0f8 format for each component).
    ptr = Ptr{N0f8}(block.pointer) + block.offset[1]

    # Offset to other channels (relative to red).
    green_off = block.offset[2] - block.offset[1]
    blue_off  = block.offset[3] - block.offset[1]

    # Other block parameters.
    width  = Int(block.width )::Int
    height = Int(block.height)::Int
    number, step = if height == 𝟙
        width, Int(block.step)::Int
    elseif width == 𝟙
        height, Int(block.pitch)::Int
    else
        argument_error("invalid block size for loading a row or a column of pixels")
    end

    # Allocate destination.
    arr = Array{T}(undef, number)

    # Copy image block according to its format.
    gray_image = (green_off == blue_off == 0)
    if  block.offset[4] < 0
        # No alpha channel.
        if gray_image
            # Gray image (no alpha channel).
            unsafe_load_pixels!(arr, Ptr{Gray{N0f8}}(ptr), number, step)
        elseif green_off == 1 && blue_off == 2
            # RGB storage order (no alpha channel).
            unsafe_load_pixels!(arr, Ptr{RGB{N0f8}}(ptr), number, step)
        elseif blue_off == -2 && green_off == -1
            # BGR storage order (no alpha channel).
            unsafe_load_pixels!(arr, Ptr{BGR{N0f8}}(ptr + blue_off), number, step)
        else
            # Generic color image without alpha channel.
            unsafe_load_pixels!(arr, RGB, ptr, ptr + green_off, ptr + blue_off,
                                number, step)
        end
    else
        # Image with alpha channel.
        alpha_off = block.offset[4] - block.offset[1]
        if gray_image
            # Gray image with alpha channel.
            if alpha_off == 1
                unsafe_load_pixels!(arr, Ptr{GrayA}(ptr), number, step)
            elseif alpha_off == -1
                unsafe_load_pixels!(arr, Ptr{AGray}(ptr + alpha_off), number, step)
            else
                unsafe_load_pixels!(arr, GrayA, ptr, ptr + alpha_off, number, step)
            end
        elseif green_off == 1 && blue_off == 2 && alpha_off == 3
            # RGBA storage order.
            unsafe_load_pixels!(arr, Ptr{RGBA{N0f8}}(ptr), number, step)
        elseif alpha_off == -1 && green_off == 1 && blue_off == 2
            # ARGB storage order.
            unsafe_load_pixels!(arr, Ptr{ARGB{N0f8}}(ptr + alpha_off), number, step)
        elseif blue_off == -2 && green_off == -1 && alpha_off == 1
            # BGRA storage order.
            unsafe_load_pixels!(arr, Ptr{BGRA{N0f8}}(ptr + blue_off), number, step)
        elseif alpha_off == -3 && blue_off == -2 && green_off == -1
            # ABGR storage order.
            unsafe_load_pixels!(arr, Ptr{ABGR{N0f8}}(ptr + alpha_off), number, step)
        else
            # Generic 4-channel image.
            unsafe_load_pixels!(arr, RGBA, ptr, ptr + green_off, ptr + blue_off,
                                ptr + alpha_off, number, step)
        end
    end
    return arr
end

function unsafe_load_pixels(::Type{Matrix{T}}, block::ImageBlock) where {T<:Colorant}
    # Pointer to first pixel in red channel (always N0f8 format for each component).
    ptr = Ptr{N0f8}(block.pointer) + block.offset[1]

    # Offset to other channels (relative to red).
    green_off = block.offset[2] - block.offset[1]
    blue_off  = block.offset[3] - block.offset[1]

    # Other block parameters.
    width  = Int(block.width )::Int
    height = Int(block.height)::Int
    pitch  = Int(block.pitch )::Int
    step   = Int(block.step  )::Int

    # Allocate destination.
    arr = Array{T}(undef, width, height)

    # Copy image block according to its format.
    gray_image = (green_off == blue_off == 0)
    if  block.offset[4] < 0
        # No alpha channel.
        if gray_image
            # Gray image (no alpha channel).
            unsafe_load_pixels!(arr, Ptr{Gray{N0f8}}(ptr),
                                width, height, pitch, step)
        elseif green_off == 1 && blue_off == 2
            # RGB storage order (no alpha channel).
            unsafe_load_pixels!(arr, Ptr{RGB{N0f8}}(ptr),
                                width, height, pitch, step)
        elseif blue_off == -2 && green_off == -1
            # BGR storage order (no alpha channel).
            unsafe_load_pixels!(arr, Ptr{BGR{N0f8}}(ptr + blue_off),
                                width, height, pitch, step)
        else
            # Generic color image without alpha channel.
            unsafe_load_pixels!(arr, RGB, ptr, ptr + green_off, ptr + blue_off,
                                width, height, pitch, step)
        end
    else
        # Image with alpha channel.
        alpha_off = block.offset[4] - block.offset[1]
        if gray_image
            # Gray image with alpha channel.
            if alpha_off == 1
                unsafe_load_pixels!(arr, Ptr{GrayA}(ptr),
                                    width, height, pitch, step)
            elseif alpha_off == -1
                unsafe_load_pixels!(arr, Ptr{AGray}(ptr + alpha_off),
                                    width, height, pitch, step)
            else
                unsafe_load_pixels!(arr, GrayA, ptr, ptr + alpha_off,
                                    width, height, pitch, step)
            end
        elseif green_off == 1 && blue_off == 2 && alpha_off == 3
            # RGBA storage order.
            unsafe_load_pixels!(arr, Ptr{RGBA{N0f8}}(ptr),
                                width, height, pitch, step)
        elseif alpha_off == -1 && green_off == 1 && blue_off == 2
            # ARGB storage order.
            unsafe_load_pixels!(arr, Ptr{ARGB{N0f8}}(ptr + alpha_off),
                                width, height, pitch, step)
        elseif blue_off == -2 && green_off == -1 && alpha_off == 1
            # BGRA storage order.
            unsafe_load_pixels!(arr, Ptr{BGRA{N0f8}}(ptr + blue_off),
                                width, height, pitch, step)
        elseif alpha_off == -3 && blue_off == -2 && green_off == -1
            # ABGR storage order.
            unsafe_load_pixels!(arr, Ptr{ABGR{N0f8}}(ptr + alpha_off),
                                width, height, pitch, step)
        else
            # Generic 4-channel image.
            unsafe_load_pixels!(arr, RGBA, ptr, ptr + green_off, ptr + blue_off,
                                ptr + alpha_off, width, height, pitch, step)
        end
    end
    return arr
end

# Load a block of pixels from a 4-channel (red, green, blue, and alpha) image.
function unsafe_load_pixels!(arr::AbstractMatrix, ::Type{C},
                             red_ptr::Ptr, green_ptr::Ptr, blue_ptr::Ptr, alpha_ptr::Ptr,
                             width::Int, height::Int,
                             pitch::Int, step::Int) where {C<:Union{RGBA,ARGB,BGRA,ABGR}}
    @inbounds for y in 𝟙:height
        @simd for x in 𝟙:width
            off   = pitch*(y - 𝟙) + step*(x - 𝟙)
            red   = unsafe_load(  red_ptr + off)
            green = unsafe_load(green_ptr + off)
            blue  = unsafe_load( blue_ptr + off)
            alpha = unsafe_load(alpha_ptr + off)
            arr[x,y] = C(red, green, blue, alpha)
        end
    end
    return nothing
end

function unsafe_load_pixels!(arr::AbstractVector, ::Type{C},
                             red_ptr::Ptr, green_ptr::Ptr, blue_ptr::Ptr, alpha_ptr::Ptr,
                             number::Int, step::Int) where {C<:Union{RGBA,ARGB,BGRA,ABGR}}
    @inbounds @simd for i in 𝟙:number
        off   = step*(i - 𝟙)
        red   = unsafe_load(  red_ptr + off)
        green = unsafe_load(green_ptr + off)
        blue  = unsafe_load( blue_ptr + off)
        alpha = unsafe_load(alpha_ptr + off)
        arr[i] = C(red, green, blue, alpha)
    end
    return nothing
end

# Load a block of pixels from a 3-channel (red, green, and blue) image.
function unsafe_load_pixels!(arr::AbstractMatrix, ::Type{C},
                             red_ptr::Ptr, green_ptr::Ptr, blue_ptr::Ptr,
                             width::Int, height::Int,
                             pitch::Int, step::Int) where {C<:Union{RGB,BGR}}
    @inbounds for y in 𝟙:height
        @simd for x in 𝟙:width
            off   = pitch*(y - 𝟙) + step*(x - 𝟙)
            red   = unsafe_load(  red_ptr + off)
            green = unsafe_load(green_ptr + off)
            blue  = unsafe_load( blue_ptr + off)
            arr[x,y] = C(red, green, blue)
        end
    end
    return nothing
end

function unsafe_load_pixels!(arr::AbstractVector, ::Type{C},
                             red_ptr::Ptr, green_ptr::Ptr, blue_ptr::Ptr,
                             number::Int, step::Int) where {C<:Union{RGB,BGR}}
    @inbounds @simd for i in 𝟙:number
        off   = step*(i - 𝟙)
        red   = unsafe_load(  red_ptr + off)
        green = unsafe_load(green_ptr + off)
        blue  = unsafe_load( blue_ptr + off)
        arr[i] = C(red, green, blue)
    end
    return nothing
end


# Load block of pixels from a 2-channel (gray and alpha) image.
function unsafe_load_pixels!(arr::AbstractMatrix, ::Type{C},
                             gray_ptr::Ptr, alpha_ptr::Ptr,
                             width::Int, height::Int,
                             pitch::Int, step::Int) where {C<:Union{GrayA,AGray}}
    @inbounds for y in 𝟙:height
        @simd for x in 𝟙:width
            off   = pitch*(y - 𝟙) + step*(x - 𝟙)
            gray  = unsafe_load( gray_ptr + off)
            alpha = unsafe_load(alpha_ptr + off)
            arr[x,y] = C(gray, alpha)
        end
    end
    return nothing
end

function unsafe_load_pixels!(arr::AbstractVector, ::Type{C},
                             gray_ptr::Ptr, alpha_ptr::Ptr,
                             number::Int, step::Int) where {C<:Union{GrayA,AGray}}
    @inbounds @simd for i in 𝟙:number
        off   = step*(i - 𝟙)
        gray  = unsafe_load( gray_ptr + off)
        alpha = unsafe_load(alpha_ptr + off)
        arr[i] = C(gray, alpha)
    end
    return nothing
end

# Load block of pixels in packed format.
function unsafe_load_pixels!(arr::AbstractMatrix, ptr::Ptr,
                             width::Int, height::Int,
                             pitch::Int, step::Int)
    @inbounds for y in 𝟙:height
        @simd for x in 𝟙:width
            off = pitch*(y - 𝟙) + step*(x - 𝟙)
            arr[x,y] = unsafe_load(ptr + off)
        end
    end
    return nothing
end

function unsafe_load_pixels!(arr::AbstractVector, ptr::Ptr,
                             number::Int, step::Int)
    @inbounds @simd for i in 𝟙:number
        arr[i] = unsafe_load(ptr + step*(i - 𝟙))
    end
    return nothing
end

#-------------------------------------------------------------------------------------------
# Apply a "color" map to an array of gray levels.

struct AffineFunction{Ta,Tb}
    alpha::Ta
    beta::Tb
end
(f::AffineFunction)(x) = f.alpha*x + f.beta

"""
    AffineFunction((a, b) => rng) -> f

Return the affine function that uniformly maps the interval of data values `[a,b]` to the
range of indices `rng`. The range `rng` must not be empty. The affine function is increasing
if `a < b` and decreasing if `a > b`.

The mapping is *safe* in the sense that `round(f(a)) ≥ first(rng)` and `round(f(b)) ≤
last(rng)`.

"""
function AffineFunction(((a,b),rng)::Pair{<:Tuple{<:Any,<:Any},
                                          <:AbstractUnitRange{<:Integer}},
                        rnd::RoundingMode = RoundNearest)
    # Index bounds.
    len = length(rng)::Int
    len > 0 || throw(AssertionError("index range must not be empty"))
    imin = Int(first(rng))::Int
    imax = Int( last(rng))::Int

    # Make sure `a` and `b` have the same type.
    a, b = promote(a, b)

    # Infer the precision for computations, using at least single precision.
    P = get_precision(Float32, typeof(a))

    # Compute affine transform that approximately maps `[a,b]` to `[imin-1/2:imax+1/2]`.
    two = P(2)
    rho = one(P) - eps(P) # reduction factor
    alpha = rho*len/(b - a)
    if isfinite(alpha)
        while true
            beta = ((imin - alpha*a) + (imax - alpha*b))/two
            round(alpha*a + beta, rnd) ≥ imin && round(alpha*b + beta, rnd) ≤ imax && break
            alpha *= rho
        end
    else
        alpha = zero(alpha) # preserve precision and units
        beta = imin/two + imax/two
    end
    get_precision(alpha) == P || throw(AssertionError(
        "expected precision `$(P)` for `alpha`, got `$(get_precision(alpha))`"))
    get_precision(beta) == P || throw(AssertionError(
        "expected precision `$(P)` for `beta`, got `$(get_precision(beta))`"))
    return AffineFunction(alpha, beta)
end
