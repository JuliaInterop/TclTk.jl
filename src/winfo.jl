import TclTk: winfo

# Define `winfo` sub-commands first (they are needed in the `WINFO` constant).

winfo_exists(w::Union{TkWidget,Name}) = winfo(Bool, :exists, w)
winfo_parent(w::Union{TkWidget,Name}) = winfo(String, :parent, w)
winfo_name(w::Union{TkWidget,Name}) = winfo(String, :name, w)

winfo_class(w::TkWidget) = winfo_class(w.path)
function winfo_class(path::Name)
    # `winfo class .` yields the name of the application which is not what we want. So, we
    # must specifically consider the case of the "." window.
    return isrootwidget(path) ? :Toplevel : winfo(Symbol, :class, path)
    # TODO for Tix widgets, we may instead use:
    # class = string(tcl_exec(path, :configure, "-class")[4])
end

winfo_interps(w::Union{TkWidget,Name}) = winfo(Vector{String}, :interps, "-displayof", w)

winfo_visualsavailable(w::Union{TkWidget,Name}) =
    winfo(Vector{Tuple{Symbol,Int}}, :visualsavailable, w)

winfo_visualsavailable_includeids(w::Union{TkWidget,Name}) =
     winfo(Vector{Tuple{Symbol,Int,UInt32}}, :visualsavailable, w, :includeids)

winfo_atom(w::Union{TkWidget,Name}) = PrefixedFunction(winfo_atom, w)
winfo_atom(w::Union{TkWidget,Name}, name) = winfo(UInt32, :atom, "-displayof", w, name)

winfo_atomname(w::Union{TkWidget,Name}) = PrefixedFunction(winfo_atomname, w)
winfo_atomname(w::Union{TkWidget,Name}, id) = winfo(String, :atomname, "-displayof", w, id)

winfo_containing(w::Union{TkWidget,Name}) = PrefixedFunction(winfo_containing, w)
winfo_containing(w::Union{TkWidget,Name}, rootx, rooty) =
     winfo(String, :containing, "-displayof", w, rootx, rooty)

winfo_fpixels(w::Union{TkWidget,Name}) = PrefixedFunction(winfo_fpixels, w)
winfo_fpixels(w::Union{TkWidget,Name}, number) = winfo(Float64, :fpixels, w, number)

winfo_pathname(w::Union{TkWidget,Name}) = PrefixedFunction(winfo_pathname, w)
winfo_pathname(w::Union{TkWidget,Name}, id) = winfo(String, :pathname, "-displayof", w, id)

winfo_pixels(w::Union{TkWidget,Name}) = PrefixedFunction(winfo_pixels, w)
winfo_pixels(w::Union{TkWidget,Name}, number) = winfo(Int, :pixels, w, number)

winfo_rgb(w::Union{TkWidget,Name}) = PrefixedFunction(winfo_rgb, w)
winfo_rgb(w::Union{TkWidget,Name}, color) = reinterpret_as_colorant(
    winfo(NTuple{3,UInt16}, :rgb, w, color))

# Sub-commands of Tk `winfo` procedure, in alphabetical order.
const WINFO = (
    :atom             => (false, typeof(winfo_atom)),
    :atomname         => (false, typeof(winfo_atomname)),
    :cells            => (true,  Int),
    :children         => (true,  Vector{String}), # TODO iterable list of strings
    :class            => (true,  typeof(winfo_class)),
    :colormapfull     => (true,  Bool),
    :containing       => (false, typeof(winfo_containing)),
    :depth            => (true,  Int),
    :exists           => (true,  Bool),
    :fpixels          => (false, typeof(winfo_fpixels)),
    :geometry         => (true,  String), # TODO parse "widthxheight+x+y" in pixels
    :height           => (true,  Int),
    :id               => (true,  UInt),
    :interps          => (true,  typeof(winfo_interps)),
    :ismapped         => (true,  Bool),
    :manager          => (true,  Symbol),
    :name             => (true,  String),
    :parent           => (true,  String),
    :path             => (true,  typeof(getfield)),
    :pathname         => (false, typeof(winfo_pathname)),
    :pixels           => (false, typeof(winfo_pixels)),
    :pointerx         => (true,  Int),
    :pointerxy        => (true,  NTuple{2,Int}),
    :pointery         => (true,  Int),
    :reqheight        => (true,  Int),
    :reqwidth         => (true,  Int),
    :rgb              => (false, typeof(winfo_rgb)),
    :rootx            => (true,  Int),
    :rooty            => (true,  Int),
    :screen           => (true,  String),
    :screencells      => (true,  Int),
    :screendepth      => (true,  Int),
    :screenheight     => (true,  Int),
    :screenmmheight   => (true,  Float64), # NOTE here float seems more appropriate than integer
    :screenmmwidth    => (true,  Float64), # NOTE  here float seems more appropriate than integer
    :screenvisual     => (true,  Symbol),
    :screenwidth      => (true,  Int),
    :server           => (true,  String),
    :toplevel         => (true,  String),
    :viewable         => (true,  Bool),
    :visual           => (true,  Symbol),
    :visualid         => (true,  UInt32),
    :visualsavailable => (true,  typeof(winfo_visualsavailable)),
    :visualsavailable_includeids => (true,  typeof(winfo_visualsavailable_includeids)),
    :vrootheight      => (true,  Int),
    :vrootwidth       => (true,  Int),
    :vrootx           => (true,  Int),
    :vrooty           => (true,  Int),
    :width            => (true,  Int),
    :x                => (true,  Int),
    :y                => (true,  Int),
)

"""
    TclTk.winfo(T=TclObj, option, args...) -> res::T
    TclTk.winfo(T=TclObj, option, w::TkWidget) -> res::T
    TclTk.winfo(T=TclObj, w::TkWidget, option) -> res::T

Return information related to Tk window(s) or to specific Tk widget `w` as a value of type
`T`.

The returned information depends on `option`, one of
$("`" * join(map(first, WINFO), "`, `", "`, or `") * "`").

"""
winfo(option::Word, args...) = winfo(TclObj, option, args...)
winfo(::Type{T}, option::Word, args...) where {T} = tcl_exec(T, "::winfo", option, args...)

winfo(w::TkWidget, option::Word) = winfo(option, w)
winfo(option::Word, w::TkWidget) = winfo(TclObj, option, w)
winfo(::Type{T}, w::TkWidget, option::Word) where {T} = winfo(T, option, w)
