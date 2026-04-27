#
# widgets.jl -
#
# Implement Tk (and Ttk) widgets
#

"""
    @TkWidget type class command prefix

Define structure `type` for widget `class` based on Tk `command` and using `prefix` for
automatically defined widget names. If `prefix` starts with a dot, a top-level widget is
assumed. `class` is the class name as given by the Tk command `winfo class \$w` and is
needed to uniquely identify Julia widget type given its Tk class. For now, `command` and
`prefix` must be string literals.

"""
macro TkWidget(structname, class, command, prefix)

    type = esc(structname) # constructor must be in the caller's module
    class isa Union{Symbol,String} || error("`class` must be a symbol or a string literal")
    class = QuoteNode(Symbol(class)::Symbol)
    command isa String || error("`command` must be a string literal")
    prefix isa String || error("`prefix` must be a string literal")

    quote
        # Define structure an inner constructor.
        struct $type <: TkWidget
            interp::TclInterp
            path::TclObj # Tk window path and Tcl widget command
            $type(interp::TclInterp, path::Verified{<:Name}) = new(interp, path.value)
        end

        # Build instance.
        $type(args...; kwds...) = build($type, $class, $command, $prefix, args...; kwds...)

        # Make the widget callable. FIXME make this at the TkWidget level
        (w::$type)(args...; kwds...) = exec(w, args...; kwds...)

        # Register widget class.
        register_widget_class($class, $type)
    end
end

const widget_classes = Dict{Symbol,Type{<:TkWidget}}()

function register_widget_class(class::Union{Symbol,AbstractString}, ::Type{T}) where {T<:TkWidget}
    class isa Symbol || (class = Symbol(class)::Symbol)
    if haskey(widget_classes, class)
        S = widget_classes[class]
        isequal(S, T) || error("attempt to register widget class `$class` for type `$T` ",
                               "while already registered for type `$S`")
    else
        widget_classes[class] = T
    end
    return nothing
end

function widget_constructor_from_path(interp::TclInterp, path::Name)
    return widget_constructor_from_class(winfo_class(interp, path))
end

function widget_constructor_from_class(class::Name)
    # In the database of widget classes, the class is a string.
    class isa Symbol || (class = Symbol(class)::Symbol)
    constructor = get(widget_classes, class, nothing)
    isnothing(constructor) && argument_error("unregistered widget class \"$class\"")
    return constructor
end

include("Tk.jl")
import .Tk:
    Canvas,
    Listbox,
    Menu,
    Message, # use Ttk.Label
    Text,
    Toplevel

include("Ttk.jl")
import .Ttk:
    Button,
    Checkbutton,
    Combobox,
    Entry,
    Frame,
    Label,
    Labelframe,
    Menubutton,
    Notebook,
    Panedwindow,
    Progressbar,
    Radiobutton,
    Scale,
    Scrollbar,
    Separator,
    Sizegrip,
    Spinbox,
    Treeview

function widget_doc(constructor::Union{Symbol,AbstractString},
                    name::Union{Symbol,AbstractString})
    name isa AbstractString || (name = String(name)::String)
    a = startswith(name, r"[aeiou]") ? "an" : "a"
    return """
    w = $(constructor)(parent::Widget, [name,] pairs::Pair...; kwds...)

Create or wrap $(a) *$(name)* widget in `parent` widget.

Optional argument `name` is the name the widget relative to its parent path; if not
specified, a unique name is automatically generated. If `name` is specified and corresponds
to an existing $(name) widget, no new widget is created and the existing widget is wrapped
as explained below.

Any number of configurable options may be specified by `opt => val` pairs of by `opt=val`
keywords with `opt` the option name and `val` the option value. The option name has no
leading hyphen and, if the option is specified by a pair, is a string or a symbol.
[`TclTk.configure`](@ref) may be called to retrieve a list of possible options.

The constructor may also wrap an existing $(name) widget in a `$(constructor)` structure:

    w = $(constructor)(interp=TclInterp(), path, pairs::Pair...; kwds...)

where `interp` is the Tcl interpreter where lives the widget and `path` is the full path of
the widget. If any configurable options are specified, they are applied to the existing
widget.

"""
end

"$(widget_doc("Button", "button"))"
Button

"$(widget_doc("Canvas", "canvas"))"
Canvas

"$(widget_doc("Checkbutton", "check button"))"
Checkbutton

"$(widget_doc("Combobox", "combo box"))"
Combobox

"$(widget_doc("Entry", "entry"))"
Entry

"$(widget_doc("Frame", "frame"))"
Frame

"$(widget_doc("Label", "label"))"
Label

"$(widget_doc("Labelframe", "label frame"))"
Labelframe

"$(widget_doc("Listbox", "list box"))"
Listbox

"$(widget_doc("Menu", "menu"))"
Menu

"$(widget_doc("Menubutton", "menu button"))"
Menubutton

"$(widget_doc("Message", "message"))"
Message

"$(widget_doc("Notebook", "notebook"))"
Notebook

"$(widget_doc("Panedwindow", "paned window"))"
Panedwindow

"$(widget_doc("Progressbar", "progress bar"))"
Progressbar

"$(widget_doc("Radiobutton", "radio button"))"
Radiobutton

"$(widget_doc("Scale", "scale"))"
Scale

"$(widget_doc("Scrollbar", "scroll bar"))"
Scrollbar

"$(widget_doc("Separator", "separator"))"
Separator

"$(widget_doc("Sizegrip", "size grip"))"
Sizegrip

"$(widget_doc("Spinbox", "spin box"))"
Spinbox

"$(widget_doc("Text", "text"))"
Text

"$(widget_doc("Treeview", "tree view"))"
Treeview

"""
    w = Toplevel(interp=TclInterp(), [path,] pairs::Pair...; kwds...)

Create or wrap a *top-level* widget living in `interp` interpreter. This also takes care of
loading the Tk extension in the interpreter and of starting the event loop.

Optional argument `path` is the full path of the widget relative to its parent path; if not
specified, a unique path is automatically generated. If `path` is specified and corresponds
to an existing top-level widget, no new widget is created and the existing widget is wrapped
in `Toplevel` structure.

Any number of configurable options may be specified by `opt => val` pairs of by `opt=val`
keywords with `opt` the option name and `val` the option value. The option name has no
leading hyphen and, if the option is specified by a pair, is a string or a symbol. Function
[`TclTk.configure`](@ref) may be called to retrieve a list of possible options.

For example:

```julia
top = Toplevel()
```

creates a new top-level widget in while

```julia
main = Toplevel(".")
```

returns the main Tk window for Tcl interpreter `interp`. No interpreter being specified,
both `top` and `main` live in the shared Tcl interpreter of the thread.

"""
Toplevel

"""
    TkWidget(interp=TclInterp(), path)

Return a widget for the given Tk window `path` in interpreter `interp`. The type of the
widget is inferred from the class of the Tk window.

"""
TkWidget(path::Name, interp::TclInterp = TclInterp()) = TkWidget(interp, path)
function TkWidget(interp::TclInterp, path::Name)
    # The following requires that `path` be a Tcl object or a string, not a symbol.
    (path isa Union{AbstractString,TclObj}) || (path = String(path)::String)
    winfo_exists(interp, path) || argument_error(
        "\"$path\" is not the path of an existing Tk widget")
    # Now we can get the widget class and hence find its registered constructor.
    T = widget_constructor_from_path(interp, path)
    return T(interp, Verified(path))
end

"""
    TclTk.winfo(T=TclObj, interp=TclInterp(), what, args...) -> res::T

Return information `what` related to Tk window(s) as a value of type `T`.

"""
winfo(interp::TclInterp, what::Name, args...) = winfo(TclObj, interp, what, args...)
winfo(::Type{T}, interp::TclInterp, what::Name, args...) where {T} =
    interp(T, "::winfo", what, args...)

"""
    TclTk.winfo(T=TclObj, w::TkWidget, what) -> res::T

Return information `what` related to widget `w` as a value of type `T`.

"""
winfo(w::TkWidget, what::Name) = winfo(what, w)
winfo(what::Name, w::TkWidget) = winfo(TclObj, w, what)
winfo(::Type{T}, w::TkWidget, what::Name) where {T} = winfo(T, what, w)
winfo(::Type{T}, what::Name, w::TkWidget) where {T} = winfo(T, w.interp, what, w.path)

winfo_exists(w::TkWidget) = winfo_exists(w.interp, w.path)
winfo_exists(interp::TclInterp, path::Name) = winfo(Bool, interp, :exists, path)

winfo_parent(w::TkWidget) = winfo_parent(w.interp, w.path)
winfo_parent(interp::TclInterp, path::Name) = winfo(String, interp, :parent, path)

winfo_name(w::TkWidget) = winfo_name(w.interp, w.path)
winfo_name(interp::TclInterp, path::Name) = winfo(String, interp, :name, path)

winfo_class(w::TkWidget) = winfo_class(w.interp, w.path)
function winfo_class(interp::TclInterp, path::Name)
    # `winfo class .` yields the name of the application which is not what we want. So, we
    # must specifically consider the case of the "." window.
    return isrootwidget(path) ? :Toplevel : winfo(Symbol, interp, :class, path)
    # TODO for Tix widgets, we may instead use: class = string(interp(path, :configure, "-class")[4])
end

winfo_interps(w::TkWidget) =
    winfo(Vector{String}, w.interp, :interps, "-displayof", w)

winfo_visualsavailable(w::TkWidget) =
    winfo(Vector{Tuple{Symbol,Int}}, w.interp, :visualsavailable, w)

winfo_visualsavailable_includeids(w::TkWidget) =
     winfo(Vector{Tuple{Symbol,Int,UInt32}}, w.interp, :visualsavailable, w, :includeids)

winfo_atom(w::TkWidget) = PrefixedFunction(winfo_atom, w)
winfo_atom(w::TkWidget, name) = winfo(UInt32, w.interp, :atom, "-displayof", w, name)

winfo_atomname(w::TkWidget) = PrefixedFunction(winfo_atomname, w)
winfo_atomname(w::TkWidget, id) = winfo(String, w.interp, :atomname, "-displayof", w, id)

winfo_containing(w::TkWidget) = PrefixedFunction(winfo_containing, w)
winfo_containing(w::TkWidget, rootx, rooty) =
     winfo(String, w.interp, :containing, "-displayof", w, rootx, rooty)

winfo_fpixels(w::TkWidget) = PrefixedFunction(winfo_fpixels, w)
winfo_fpixels(w::TkWidget, number) = winfo(Float64, w.interp, :fpixels, w, number)

winfo_pathname(w::TkWidget) = PrefixedFunction(winfo_pathname, w)
winfo_pathname(w::TkWidget, id) = winfo(String, w.interp, :pathname, "-displayof", w, id)

winfo_pixels(w::TkWidget) = PrefixedFunction(winfo_pixels, w)
winfo_pixels(w::TkWidget, number) = winfo(Int, w.interp, :pixels, w, number)

winfo_rgb(w::TkWidget) = PrefixedFunction(winfo_rgb, w)
winfo_rgb(w::TkWidget, color) = reinterpret_as_colorant(
    winfo(NTuple{3,UInt16}, w.interp, :rgb, w, color))

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
    :interp           => (true,  typeof(getfield)),
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

@inline Base.getproperty(w::TkWidget, key::Symbol) = _getproperty(w, Val(key))

let props = Symbol[]
    for (sym, (flag, T)) in WINFO
        key = QuoteNode(sym)
        if T === typeof(getfield)
            @eval _getproperty(w::TkWidget, ::Val{$key}) = getfield(w, $key)
        elseif T <: Function
            @eval _getproperty(w::TkWidget, ::Val{$key}) = $(T.instance)(w)
        else
            @eval _getproperty(w::TkWidget, ::Val{$key}) = winfo($T, w, $key)

        end
        flag && push!(props, sym)
    end
    @eval Base.propertynames(w::TkWidget) = $(Tuple(sort!(props)))
end

# For Tk objects, syntax `obj.comd(...)` invokes sub-command.
_getproperty(w::TkObject, ::Val{cmd}) where {cmd} = SubCommand{cmd}(w)

# Some sub-commands are special.
for cmd in (:cget, :configure)
    @eval begin
        (f::SubCommand{$(QuoteNode(cmd)),<:TkObject})(::Type{T}, args...; kwds...) where T =
            $cmd(T, f.caller, args...; kwds...)
        (f::SubCommand{$(QuoteNode(cmd)),<:TkObject})(args...; kwds...) =
            $cmd(f.caller, args...; kwds...)
    end
end
for cmd in (:grid, :pack, :place)
    @eval begin
        (f::SubCommand{$(QuoteNode(cmd)),<:TkWidget})(::Type{T}, args...; kwds...) where T =
            $cmd(T, f.caller, args...; kwds...)
        (f::SubCommand{$(QuoteNode(cmd)),<:TkWidget})(args...; kwds...) =
            $cmd(f.caller, args...; kwds...)
    end
end

# Canvas sub-commands that do not return an empty string (`nothing`).

# The default for `bbox` cannot be `Tuple{4,Float64}` because there may be no matching items
# and an empty result.
function (f::SubCommand{:bbox, Canvas})(tags::TagOrId...)
    r = f(TclObj, tags...)
    n = length(r)
    n == 0 && return nothing
    n == 4 || error("unexpected result for `bbox` canvas command: \"",
                    escape_string(string(r)), "\"")
    return convert(NTuple{4,Int}, r)
end

# Same logic as `bind`.
(f::SubCommand{:bind, Canvas})(tag::TagOrId) = f(TclObj, tag)
(f::SubCommand{:bind, Canvas})(tag::TagOrId, seq) = f(TclObj, tag, seq)
(f::SubCommand{:bind, Canvas})(tag::TagOrId, seq, script) = f(TclObj, tag, seq, script)
# FIXME (f::SubCommand{:bind, Canvas})(::Type{T}, tag::TagOrId, args...) where {T} =
# FIXME     exec(T, f.caller, :bind, tag, args...)

(f::SubCommand{:canvasx, Canvas})(x::Union{TclObj,Real}) = f(Float64, x)
(f::SubCommand{:canvasy, Canvas})(y::Union{TclObj,Real}) = f(Float64, y)
(f::SubCommand{:coords, Canvas})(tag::TagOrId) = f(Vector{Float64}, tag)
(f::SubCommand{:create, Canvas})(type::Word, args...) = f(Int, type, args...)
(f::SubCommand{:find, Canvas})(spec::Word, args...) = f(TclObj, spec, args...)

# TODO focus
(f::SubCommand{:gettags, Canvas})(tag::TagOrId) = f(TclObj, tag)
(f::SubCommand{:index, Canvas})(tag::TagOrId, index) = f(Int, tag, index)

(f::SubCommand{:itemcget, Canvas})(tag::TagOrId, opt::Word) = f(TclObj, tag, opt)
(f::SubCommand{:itemcget, Canvas})(::Type{T}, tag::TagOrId, opt::Word) where {T} =
    exec(T, f.caller, :itemcget, tag, with_hyphen(opt))

# TODO itemconfigure

(f::SubCommand{:postscript, Canvas})(pairs::Pair...; kwds...) = f(TclObj, pairs...; kwds...)

(f::SubCommand{:type, Canvas})(tag::TagOrId) = f(Symbol, tag)

(f::SubCommand{:xview, Canvas})() = f(Tuple{2,Float64})
(f::SubCommand{:yview, Canvas})() = f(Tuple{2,Float64})


"""
    TclTk.Impl.isrootwidget(w) -> bool

Return whether `w` is the Tk root widget of window path.

This is to cope with that, in many situations, the case of the "." window must be considered
specifically. For example, `winfo parent .` yields an empty result while `winfo class .`
yields the name of the application.

"""
isrootwidget(path::Symbol) = (path == :(.))
isrootwidget(path::Name) = path == "."
isrootwidget(w::Toplevel) = isrootwidget(w.path)
isrootwidget(w::TkWidget) = false

# Supply interpreter.
function build(::Type{T}, class::Symbol, command::String, prefix::String,
               pairs::Pair...; kwds...) where {T<:TkWidget}
    return build(T, class, command, prefix, TclInterp(), pairs...; kwds...)
end
function build(::Type{T}, class::Symbol, command::String, prefix::String,
               path::Name, pairs::Pair...; kwds...) where {T<:TkWidget}
    return build(T, class, command, prefix, TclInterp(), path, pairs...; kwds...)
end

# Build a top-level widget with automatic name.
function build(::Type{T}, class::Symbol, command::String, prefix::String,
               interp::TclInterp, pairs::Pair...; kwds...) where {T<:TkWidget}
    startswith(prefix, '.') || argument_error("missing parent widget")
    tk_start() # make sure Tk has been loaded
    path = interp(TclObj, command, widget_auto_path(interp, "", prefix), pairs...; kwds...)
    return T(interp, Verified(path))
end

# Build a widget given its full path.
function build(::Type{T}, class::Symbol, command::String, prefix::String,
               interp::TclInterp, path::Name, pairs::Pair...; kwds...) where {T<:TkWidget}
    # If top-level widget, make sure Tk has been loaded.
    startswith(prefix, '.') && tk_start()
    if winfo_exists(interp, path)
        # Re-use existing widget.
        trueclass = winfo_class(interp, path)
        class == trueclass || argument_error(
            "attempt to wrap a widget with class `", class, "` on top of existing widget \"",
            path, "\" whose class is `", trueclass, "`")
        w = T(interp, Verified(path))
        (isempty(pairs) && isempty(kwds)) || w.configure(pairs...; kwds...)
        return w
    else
        # Create a new widget.
        path = interp(TclObj, command, path, pairs...; kwds...)
        return T(interp, Verified(path))
    end
end

# Build a child widget given its parent and its name.
function build(::Type{T}, class::Symbol, command::String, prefix::String,
               parent::TkWidget, name::Name, pairs::Pair...; kwds...) where {T<:TkWidget}
    name isa String || (name = String(name)::String)
    isempty(match(r"^[A-Z_a-z][0-9A-Z_a-z]*$", name)) && argument_error(
        "invalid widget child name \"$name\"")
    root = String(parent.path)::String
    path = (root == "." ? root*name : root*"."*name)::String
    return build(T, class, command, prefix, parent.interp, path, pairs...; kwds...)
end

# Build a child widget given its parent and with automatic name.
function build(::Type{T}, class::Symbol, command::String, prefix::String,
               parent::TkWidget, pairs::Pair...; kwds...) where {T<:TkWidget}
    interp = parent.interp
    path = widget_auto_path(interp, String(parent.path)::String, prefix)
    return build(T, class, command, prefix, interp, path, pairs...; kwds...)
end

# Return the path of a non-existing widget.
function widget_auto_path(interp::TclInterp, parent::String, prefix::String)
    i, j = firstindex(prefix), lastindex(prefix)
    key = SubString(prefix, (i ≤ j && prefix[i] == '.' ? nextind(prefix, i) : i), j)
    base = (parent == "." ? "."*key : parent*"."*key)::String
    T = valtype(auto_name_dict)
    n = get(auto_name_dict, key, zero(T)) + one(T)
    while true
        # NOTE `s*string(i)` is faster than `string(s,i)` or, equivalently, `"$s$i"
        path = base*string(n)
        if !winfo_exists(interp, path)
            auto_name_dict[key] = n
            return path
        end
        n += one(n)
    end
end

# Accessors.
TclInterp(w::TkWidget) = w.interp
Base.parent(w::TkWidget) = winfo_parent(w)
TclObj(w::TkWidget) = w.path
Base.convert(::Type{TclObj}, w::TkWidget) = TclObj(w)::TclObj
# FIXME Base.convert(::Type{String}, w::TkWidget) = ...
unsafe_objptr(w::TkWidget) = unsafe_objptr(TclObj(w), "Tk widget") # used in `exec`

exec(w::TkWidget, args...; kwds...) =
    exec(w.interp, w.path, args...; kwds...)
exec(w::TkWidget, ::Type{T}, args...; kwds...) where {T} =
    exec(T, w.interp, w.path, args...; kwds...)
exec(::Type{T}, w::TkWidget, args...; kwds...) where {T} =
    exec(T, w.interp, w.path, args...; kwds...)

# We want to have the object type and path both printed in the REPL but want only the object
# path with the `string` method or for string interpolation. Note that "$w" and `string(w)`
# call `print(io, w)`.
Base.print(io::IO, w::TkWidget) = (write(io, w.path); nothing)

Base.show(io::IO, ::MIME"text/plain", w::TkWidget) = show(io, w)

function Base.show(io::IO, w::T) where {T<:TkWidget}
    print(io, T, "(\"")
    write(io, w.path)
    print(io, "\")")
    return nothing
end

for f in (:isequal, :(==))
    @eval function Base.$f(a::T, b::T) where {T<:TkWidget}
        return $f(a.interp, b.interp) && $f(a.path, b.path)
    end
end

"""
    tk_start(interp = TclInterp()) -> interp

Ensure that Tk and Ttk packages are loaded in Tcl interpreter `interp` and that the event
loop is started (for all Tcl interpreters). Return the Tcl interpreter. Once, Tk and Ttk
packages have been loaded and the event loop started, calling `tk_start` is very fast.

!!! note
    `tk_start` also takes care of withdrawing the root window "." to avoid its destruction
    as this would terminate the Tcl application. Execute Tcl command `wm deiconify .` to
    show the root window again.

# See also

[`TclTk.resume`](@ref), [`TclInterp`](@ref), and [`TkWidget`](@ref).

"""
function tk_start(interp::TclInterp = TclInterp()) :: TclInterp
    getfield(interp, :tkstarted) || force_tk_start(interp)
    isrunning() || resume()
    return interp
end

function force_tk_start(interp::TclInterp)
    # Initialize Tcl interpreter to find Tk library scripts. NOTE this is the same as
    # initializing global variable `tcl_library` before calling `Tcl_Init`.
    if isdefined(@__MODULE__, :Tk_jll)
        tk_library = joinpath(dirname(dirname(Tk_jll.libtk_path)), "lib",
                              "tk$(TCL_MAJOR_VERSION).$(TCL_MINOR_VERSION)")
        ptr = Tcl_SetVar(interp, "tk_library", tk_library, TCL_GLOBAL_ONLY|TCL_LEAVE_ERR_MSG)
        isnull(ptr) && @warn "Unable to set `tk_library`: $(getresult(String, interp))"
    end
    # Load Tk and Ttk packages. It is not needed to explicitly load these packages, it is
    # sufficient to call `Tk_Init`.
    status = @ccall libtk.Tk_Init(interp::Ptr{Tcl_Interp})::TclStatus
    status == TCL_OK || @warn "Unable to initialize Tk interpreter: $(getresult(String, interp))"
    status == TCL_OK && (status = interp(TclStatus, :wm, :withdraw, "."))
    # Attempt to set the icon for top-level windows.
    file = joinpath(@__DIR__, "logo.png")
    ns = "::assets"
    logo = "$(ns)::logo"
    status == TCL_OK && (status = interp(TclStatus, :namespace, :eval, ns, ""))
    status == TCL_OK && (status = interp(TclStatus, :image, :create, :photo, logo, file=file))
    status == TCL_OK && (status = interp(TclStatus, :wm, :iconphoto, ".", "-default", logo))
    setfield!(interp, :tkstarted, true)
    return nothing
end

"""
    TclTk.configure(w)
    w(:configure)

Return all the options of Tk object (widget or image) `w`.

---
    TclTk.configure(w, pairs...; kwds...)
    w(:configure, pairs...; kwds...)
    w.configure(pairs...; kwds...)

Change some options of widget or image `w`. Trailing `pairs...` arguments and keywords
`kwds...` are interpreted as configuration options. Another way to change the settings is:

    w[opt1] = val1
    w[opt2] = val2

# See also

[`TclTk.cget`](@ref) and [`TkWidget`](@ref).

"""
configure(::Type{T}, w::TkObject, pairs...; kwds...) where {T} =
    exec(T, w, :configure, pairs...; kwds...)
configure(::Type{T}, w::TkObject, opt::Word) where {T} =
    exec(T, w, :configure, with_hyphen(opt))

# Default result type depends on the number of arguments.
configure(w::TkObject) = configure(TclObj, w)
configure(w::TkObject, opt::Word) = configure(TclObj, w, opt)
configure(w::TkObject, pairs...; kwds...) = configure(Nothing, w, pairs...; kwds...)

"""
    TclTk.cget(w, opt)

Return the value of the option `opt` for Tk object (widget or image) `w`. Option `opt` may
be specified as a string or as a `Symbol` and shall corresponds to a Tk option name (the
leading hyphen may be omitted). Another way to obtain an option value is:

    w[opt]

# See also

[`TclTk.configure`](@ref) and [`TkWidget`](@ref).

"""
cget(w::TkObject, opt::Word) = cget(TclObj, w, opt)
cget(w::TkObject, ::Type{T}, opt::Word) where {T} = cget(T, w, opt)
cget(::Type{T}, w::TkObject, opt::Word) where {T} = exec(T, w, :cget, with_hyphen(opt))

Base.getindex(w::TkObject, key::Word) = cget(w, key)
@inline Base.getindex(w::TkObject, (key,T)::Pair{<:Word,DataType}) = cget(T, w, key)
Base.getindex(w::TkObject, ::Type{T}, key::Word) where {T} = cget(T, w, key)
Base.getindex(w::TkObject, key::Word, ::Type{T}) where {T} = cget(T, w, key)
function Base.setindex!(w::TkObject, val, key::Word)
    exec(Nothing, w, :configure, key => val)
    return w
end

"""
    TclTk.grid(args...)

Call Tk *grid* geometry manager. One of the arguments must be a widget (that is an instance
of `TkWidget`). All widgets in `args...` must live in the same interpreter.


To specify the gridding options for a single widget `w`, another possible syntax is:

    w.grid(args...; kwds...)

# See also

[`TclTk.pack`](@ref) and [`TclTk.place`](@ref).

"""
function grid end

"""
    TclTk.pack(args...; kwds...)

Call Tk *packer* geometry manager. One of the arguments must be a widget (that is an
instance of `TkWidget`). All widgets in `args...` must live in the same interpreter.

To specify the packing options for a single widget `w`, another possible syntax is:

    w.pack(args...; kwds...; kwds..)

For example:

```julia
using TclTk
tk_start()
top = Toplevel()
wm.title(top, "A simple example")
btn = Button(top, text="Click me", command="puts {ouch!}")
btn.pack(side=:bottom, padx=30, pady=5)
```

# See also

[`TclTk.grid`](@ref) and [`TclTk.place`](@ref).

"""
function pack end

"""
    TclTk.place(args...; kwds..)

Call Tk *placer* geometry manager. One of the arguments must be a widget (that is an
instance of `TkWidget`). All widgets in `args...` must live in the same interpreter.

To specify the placing options for a single widget `w`, another possible syntax is:

    w.place(args...; kwds...)

# See also

[`TclTk.grid`](@ref) and [`TclTk.pack`](@ref).

"""
function place end

for cmd in (:grid, :pack, :place)
    @eval begin
        $cmd(args...; kwds...) = $cmd(Nothing, args...; kwds...)
        function $cmd(::Type{T}, args...; kwds...) where {T}
            interp = common_interpreter(nothing, args...)
            interp == nothing && argument_error("missing a widget argument")
            return exec(T, interp, $(QuoteNode(cmd)), args...; kwds...)
        end
    end
end

common_interpreter() = nothing
common_interpreter(interp::Union{Nothing,TclInterp}) = interp
common_interpreter(interp::Union{Nothing,TclInterp}, arg::Any, args...) =
    common_interpreter(interp, args...)
common_interpreter(::Nothing, arg::TkWidget, args...) =
    common_interpreter(arg.interp, args...)
function common_interpreter(interp::TclInterp, arg::TkWidget, args...)
    pointer(interp) == pointer(arg.interp) || argument_error("not all widgets have the same interpreter")
    return common_interpreter(interp, args...)
end

# Base.bind is overloaded because it already exists for sockets, but there
# should be no conflicts.
"""
    bind(w, ...)

Bind events to widget `w` or yields bindings for widget `w`.

With a single argument:

    bind(w)

yields bindings for widget `w`; while

    bind(w, seq)

yields the specific bindings for the sequence of events `seq` and

    bind(w, seq, script)

arranges to invoke `script` whenever any event of the sequence `seq` occurs for widget `w`.
For instance:

    bind(w, "<ButtonPress>", "+puts click")

To deal with class bindings, the Tcl interpreter may be provided (otherwise the shared
interpreter of the thread will be used):

    bind([interp,] classname, args...)

where `classname` is the name of the widget class (a string or a symbol).

"""
Base.bind(::Type{T}, w::TkWidget, args...) where {T} =
    exec(T, w.interp, "::bind", w, args...)

# Supply return type.
Base.bind(w::TkWidget) = bind(TclObj, w)
Base.bind(w::TkWidget, seq) = bind(TclObj, w, seq)
Base.bind(w::TkWidget, seq, script) = bind(Nothing, w, seq, script)
