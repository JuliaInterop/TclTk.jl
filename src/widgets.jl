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
    constructor = esc(Symbol("_", structname))
    class isa Union{Symbol,String} || error("`class` must be a symbol or a string literal")
    class = QuoteNode(Symbol(class)::Symbol)
    command isa String || error("`command` must be a string literal")
    prefix isa String || error("`prefix` must be a string literal")

    quote
        # Define structure an inner constructor.
        struct $type <: TkWidget
            path::TclObj # Tk window path and Tcl widget command
            global $constructor
            $constructor(path::Name) = new(path)
        end

        # Build instance.
        $type(args...; kwds...) =
            build($constructor, $class, $command, $prefix, args...; kwds...) :: $type

        # Make the widget callable.
        (w::$type)(::Type{T}, args...; kwds...) where {T} = tcl_exec(T, w, args...; kwds...)
        (w::$type)(args...; kwds...) = tcl_exec(Nothing, w, args...; kwds...)

        # Register widget class.
        register_widget_class($class, $constructor)
    end
end

const widget_classes = Dict{Symbol,Function}()

function register_widget_class(class::Union{Symbol,AbstractString}, constructor::Function)
    class isa Symbol || (class = Symbol(class)::Symbol)
    haskey(widget_classes, class) && error(
        "attempt to register widget class `$class` more than once")
    widget_classes[class] = constructor
    return nothing
end

function widget_constructor_from_path(path::Name)
    return widget_constructor_from_class(winfo_class(path))
end

function widget_constructor_from_class(class::Name)
    # In the database of widget classes, the class is a symbol.
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

    w = $(constructor)(path, pairs::Pair...; kwds...)

where `path` is the full path of the widget and `pairs...` denotes optional configurable
options which are applied to the existing widget.

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
    w = Toplevel([path,] pairs::Pair...; kwds...)

Create or wrap a *top-level* Tk widget.

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

returns the main Tk window.

"""
Toplevel

"""
    TkWidget(path)

Return a widget for the given Tk window `path`. The type of the widget is inferred from the
class of the Tk window.

"""
function TkWidget(path::Name)
    # The following requires that `path` be a Tcl object or a string, not a symbol.
    (path isa Union{AbstractString,TclObj}) || (path = String(path)::String)
    winfo_exists(path) || argument_error(
        "\"$path\" is not the path of an existing Tk widget")
    _T = widget_constructor_from_path(path)
    return _T(path)
end

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
for (cmd, cls) in (:cget => TkObject, :configure => TkObject,
                   :grid => TkWidget, :pack => TkWidget, :place => TkWidget)
    @eval begin
        (f::SubCommand{$(QuoteNode(cmd)),<:$cls})(::Type{T}, args...; kwds...) where T =
            $cmd(T, f.caller, args...; kwds...)
        (f::SubCommand{$(QuoteNode(cmd)),<:$cls})(args...; kwds...) =
            $cmd(f.caller, args...; kwds...)
    end
end

# Sub-commands for top-level widgets.
for cmd in (:iconname, :title)
    wm_cmd = Symbol("wm_",cmd)
    @eval begin
        (f::SubCommand{$(QuoteNode(cmd)),Toplevel})() = $wm_cmd(f.caller)
        (f::SubCommand{$(QuoteNode(cmd)),Toplevel})(str::AbstractString) = $wm_cmd(f.caller, str)
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
# FIXME     tcl_exec(T, f.caller, :bind, tag, args...)

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
    tcl_exec(T, f.caller, :itemcget, tag, with_hyphen(opt))

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
isrootwidget(path::Symbol) = path === :(.)
isrootwidget(path::Name) = path == "."
isrootwidget(w::Toplevel) = isrootwidget(w.path)
isrootwidget(w::TkWidget) = false

# Build a top-level widget with automatic name.
function build(_T::Function, class::Symbol, command::String, prefix::String,
               pairs::Pair...; kwds...)
    startswith(prefix, '.') || argument_error("missing parent widget")
    path = widget_auto_path("", prefix)
    return _T(tcl_exec(TclObj, command, path, pairs...; kwds...))
end

# Build a widget given its full path.
function build(_T::Function, class::Symbol, command::String, prefix::String,
               path::Name, pairs::Pair...; kwds...)
    if winfo_exists(path)
        # Re-use existing widget.
        trueclass = winfo_class(path)
        class == trueclass || argument_error(
            "attempt to wrap a widget with class `", class, "` on top of existing widget \"",
            path, "\" whose class is `", trueclass, "`")
        w = _T(path)
        (isempty(pairs) && isempty(kwds)) || w.configure(pairs...; kwds...)
        return w
    else
        # Create a new widget.
        return _T(tcl_exec(TclObj, command, path, pairs...; kwds...))
    end
end

# Build a child widget given its parent and its name.
function build(_T::Function, class::Symbol, command::String, prefix::String,
               parent::TkWidget, name::Name, pairs::Pair...; kwds...)
    name isa String || (name = String(name)::String)
    isempty(match(r"^[A-Z_a-z][0-9A-Z_a-z]*$", name)) && argument_error(
        "invalid widget child name \"$name\"")
    root = String(parent.path)::String
    path = (root == "." ? root*name : root*"."*name)::String
    return build(_T, class, command, prefix, path, pairs...; kwds...)
end

# Build a child widget given its parent and with automatic name.
function build(_T::Function, class::Symbol, command::String, prefix::String,
               parent::TkWidget, pairs::Pair...; kwds...)
    path = widget_auto_path(String(parent.path)::String, prefix)
    return _T(tcl_exec(TclObj, command, path, pairs...; kwds...))
end

# Return the path of a non-existing widget.
function widget_auto_path(parent::String, prefix::String)
    i, j = firstindex(prefix), lastindex(prefix)
    key = SubString(prefix, (i ≤ j && prefix[i] == '.' ? nextind(prefix, i) : i), j)
    base = (parent == "." ? "."*key : parent*"."*key)::String
    T = valtype(auto_name_dict)
    n = get(auto_name_dict, key, zero(T)) + one(T)
    while true
        # NOTE `s*string(i)` is faster than `string(s,i)` or, equivalently, `"$s$i"
        path = base*string(n)
        if !winfo_exists(path)
            auto_name_dict[key] = n
            return path
        end
        n += one(n)
    end
end

# Accessors.
Base.parent(w::TkWidget) = winfo_parent(w)
TclObj(w::TkWidget) = w.path
Base.convert(::Type{TclObj}, w::TkWidget) = TclObj(w)::TclObj
# FIXME Base.convert(::Type{String}, w::TkWidget) = ...
unsafe_objptr(w::TkWidget) = unsafe_objptr(TclObj(w), "Tk widget") # used in `tcl_exec`

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
    @eval begin
        Base.$f(a::T, b::T) where {T<:TkWidget} = $f(a.path, b.path)
        Base.$f(a::TkWidget, b::TkWidget) = false
    end
end

"""
    TclTk.configure(w)
    w.configure()
    w(:configure)

Return all the options of Tk object (widget or image) `w`.

---
    TclTk.configure(w, pairs...; kwds...)
    w.configure(pairs...; kwds...)
    w(:configure, pairs...; kwds...)

Change some options of widget or image `w`. Trailing `pairs...` arguments and keywords
`kwds...` are interpreted as configuration options. Another way to change the settings is:

    w[opt1] = val1
    w[opt2] = val2

# See also

[`TclTk.cget`](@ref) and [`TkWidget`](@ref).

"""
configure(::Type{T}, w::TkObject, pairs...; kwds...) where {T} =
    tcl_exec(T, w, :configure, pairs...; kwds...)
configure(::Type{T}, w::TkObject, opt::Word) where {T} =
    tcl_exec(T, w, :configure, with_hyphen(opt))

# Default result type depends on the number of arguments.
configure(w::TkObject) = configure(TclObj, w)
configure(w::TkObject, opt::Word) = configure(TclObj, w, opt)
configure(w::TkObject, pairs...; kwds...) = configure(Nothing, w, pairs...; kwds...)

"""
    TclTk.cget(T=TclObj, w, opt) -> val::T

Return the value, converted to type `T`, of the option `opt` for Tk object (widget or image)
`w`. Option `opt` may be specified as a string or as a `Symbol` and shall corresponds to a
Tk option name (the leading hyphen may be omitted). Another way to obtain an option value
is:

    w[opt] -> val::TclObj

# See also

[`TclTk.configure`](@ref) and [`TkWidget`](@ref).

"""
cget(w::TkObject, opt::Word) = cget(TclObj, w, opt)
cget(w::TkObject, ::Type{T}, opt::Word) where {T} = cget(T, w, opt)
cget(::Type{T}, w::TkObject, opt::Word) where {T} = tcl_exec(T, w, :cget, with_hyphen(opt))

Base.getindex(w::TkObject, key::Word) = cget(w, key)
function Base.setindex!(w::TkObject, val, key::Word)
    tcl_exec(Nothing, w, :configure, key => val)
    return w
end

"""
    TclTk.grid(T=Nothing, args...)

Call Tk *grid* geometry manager. One of the arguments must be a widget (that is an instance
of `TkWidget`). Optional argument `T` is to specify the result type.

To specify the grid manager options for a single widget `w`, another possible syntax is:

    w.grid(T=Nothing, args...; kwds...)

# See also

[`TclTk.pack`](@ref) and [`TclTk.place`](@ref).

"""
function grid end

"""
    TclTk.pack(T=Nothing, args...; kwds...)

Call Tk *packer* geometry manager. One of the arguments must be a widget (that is an
instance of `TkWidget`). Optional argument `T` is to specify the result type.

To specify the packing options for a single widget `w`, another possible syntax is:

    w.pack(T=Nothing, args...; kwds...; kwds..)

For example:

```julia
using TclTk
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
    TclTk.place(T=Nothing, args...; kwds..)

Call Tk *placer* geometry manager. One of the arguments must be a widget (that is an
instance of `TkWidget`). Optional argument `T` is to specify the result type.

To specify the placing options for a single widget `w`, another possible syntax is:

    w.place(args...; kwds...)

# See also

[`TclTk.grid`](@ref) and [`TclTk.pack`](@ref).

"""
function place end

# All geometry manager commands follow the same pattern.
for cmd in (:grid, :pack, :place)
    @eval begin
        $cmd(args...; kwds...) = $cmd(Nothing, args...; kwds...)
        function $cmd(::Type{T}, args...; kwds...) where {T}
            return tcl_exec(T, $(QuoteNode(cmd)), args...; kwds...)
        end
    end
end

# Base.bind is overloaded because it already exists for sockets, but there should be no
# conflicts.
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

To deal with class bindings:

    tcl_exec("::bind", classname, args...)

where `classname` is the name of the widget class (a string or a symbol).

"""
Base.bind(::Type{T}, w::TkWidget, args...) where {T} =
    tcl_exec(T, "::bind", w, args...)

# Supply return type.
Base.bind(w::TkWidget) = bind(TclObj, w)
Base.bind(w::TkWidget, seq) = bind(TclObj, w, seq)
Base.bind(w::TkWidget, seq, script) = bind(Nothing, w, seq, script)
