# Tk images

Tk images are stored in memory and are meant to be displayed in Tk widgets (usually with the
`-image` option).

## Image creation

To build a Tk image, call the constructor [`TkImage`](@ref) as follows:

```julia
TkImage{type}(host=TclInterp(), option => value, ...) -> img
TkImage{type}(host=TclInterp(), name, option => value, ...) -> img
```

Parameter `type` is the symbolic image type. Types `:bitmap` and `:photo` are provided by
the base Tk package but other packages may implement additional image types.

Argument `host` is used to infer the Tcl interpreter where lives the image. It is the shared
interpreter of the thread if omitted. It can be a widget instance to create the image in the
same interpreter as the widget.

Optional argument `name` is the identifier of the image, it must be a unique command name
for the interpreter (the image object can be called as any other Tcl commands); if not
specified, `name` is automatically supplied by Tk. For the returned image, the name is given
by `img.name`. If `name` is given and corresponds to an existing image in the interpreter,
this image is re-wrapped in a `TkImage` object after applying the configuration changes if
any are specified by `option => value, ...`. If the image already exists, it must be of the
same `type`.

Any number of `option => value` pairs may be specified for setting the initial configurable
parameters of the image. As for widgets, `option` is the name of an image option without the
leading hyphen.

Calling the  [`TkImage`](@ref) constructor with no `type` parameter is meant to re-wrap
an existing image, the image `name` must be specified in this case:

```julia
TkImage(host=TclInterp(), name, option => value, ...) -> img
```

## Aliases

`TclTk` exports a few aliases for the base Tk image types:

```julia
const TkBitmap = TkImage{:bitmap}
const TkPhoto  = TkImage{:photo}
```

## Image configuration

Image configurable options are available by indexing the image with the option name
(without the leading hyphen) specified as a string or as a symbol.

For example:

```julia-repl
julia> using TclTk, Colors

julia> img = TkBitmap(:data => """"#define rule_width 32
       #define rule_height 17
       static char rule_bits[] = {0x00, 0x00, 0x00, 0x00, 0xfe, 0xff, 0xff, 0x7f,
       0xfe, 0xff, 0xff, 0x7f, 0x98, 0x99, 0x99, 0x19, 0x98, 0x99, 0x99, 0x19,
       0x18, 0x80, 0x01, 0x18, 0x18, 0x80, 0x01, 0x18, 0x00, 0x00, 0x00, 0x00,
       0x1c, 0x80, 0x01, 0x1c, 0x36, 0xc0, 0x01, 0x36, 0x36, 0x80, 0x01, 0x36,
       0x36, 0x80, 0x01, 0x30, 0x36, 0x80, 0x01, 0x18, 0x36, 0x80, 0x01, 0x04,
       0x36, 0x80, 0x01, 0x3e, 0x1c, 0xc0, 0x03, 0x3e, 0x00, 0x00, 0x00, 0x00};
       """)
TkBitmap (alias for TkImage{:bitmap}) name = "image7", size = (32, 17)

julia> img[:foreground]
TclObj("#000000")

julia> img[:background] = colorant"cyan"
RGB{N0f8}(0.0, 1.0, 1.0)

julia> img[:background]
TclObj("#00FFFF")

```

Accessing to the image configuration can also be done by the `cget` and `configure`
sub-commands described below.


## Image properties

A Tk image has a number of properties:

- `img.inuse` yields whether an image is in use in a Tk widget.

- `img.width` yields the width of the image in pixels. This is the same as `size(img, 1)` or
  `img.size[1]`.

- `img.height` yields the height of the image in pixels. This is the same as `size(img, 2)`
  or `img.size[2]`.

- `img.size` yields the iamge size as `(width, height)` in pixels. This is the same as
  `size(img)` or `(img.width, img.height)`.

- `img.type` yields the symbolic type of the image (`:bitmap`, `:photo`, etc.).

- `img.name` yields the image name in its interpreter.

- `img.interp` yields the Tcl interpreter hosting the image.


## Image sub-commands

Like a widget, an image is callable to execute a sub-command for the image. The available
sub-commands depend on the image type. For example, for a `TkPhoto` image, `cget` and
`configure` are possible sub-commands:

```julia-repl
julia> img = TkImage()
TkPhoto (alias for TkImage{:photo}) name = "image1", size = (0, 0)

julia> img(:config)
TclObj(("-data {} {} {} {}", "-format {} {} {} {}", "-metadata {} {} {} {}", "-file {} {} {} {}", "-gamma {} {} 1 1.0", "-height {} {} 0 0", "-palette {} {} {} {}", "-width {} {} 0 0",))

julia> img(:cget, "-width")
TclObj("0")

julia> img(Int, :cget, "-height")
0

```

Public functions [`TclTk.cget`](@ref) and [`TclTk.configure`](@ref) are applicable to an
image instance. For example:

```julia-repl
julia> img = TkImage()
TkPhoto (alias for TkImage{:photo}) name = "image1", size = (0, 0)

julia> TclTk.configure(img)
TclObj(("-data {} {} {} {}", "-format {} {} {} {}", "-metadata {} {} {} {}", "-file {} {} {} {}", "-gamma {} {} 1 1.0", "-height {} {} 0 0", "-palette {} {} {} {}", "-width {} {} 0 0",))

julia> TclTk.cget(Int, img, "width") # no hyphen here
0

```

## Loading and storing pixels

A Tk photo image can be indexed as a 2-dimensional array to access its pixels. Pixel indices
are 1-based as is usually the case in Julia arrays. Following the convention in Tk, the
first and second axes respectively correspond to the *width* and *height* of the image.

For example:

```julia
A = img[xroi, yroi]
```

yields an array `A` with a copy of the pixels of the image `img` in the *region of interest*
(ROI) defined by `xroi` and `yroi`, two unit ranges or colons. The full image is obtained by
`img[:,:]`. The element type of the result depend on the image pixel type, most certainly
`RGBA{N0f8}`, that is red, green, blue, and alpha each encoded in a `UInt8`.

As for indexing arrays, if one of `xroi` or `yroi` is a scalar index, the extracted ROI is a
vector of pixels, while if both `xroi` or `yroi` are scalar indices, the extracted ROI is a
single pixel.

Storing pixel values is as simple as:

```julia
img[xroi, yroi] = A
```

which performs pixel value conversion as needed. When the content of a Tk image is modified,
it is automatically redrawn in the widgets that use it.
