import TclTk: wm

# Sub-commands of Tk `wm` procedure, in alphabetical order.
const WM_COMMANDS = (
    :aspect, :attributes, :client, :colormapwindows, :command, :deiconify, :focusmodel,
    :forget, :frame, :geometry, :grid, :group, :iconbadge, :iconbitmap, :iconify,
    :iconmask, :iconname, :iconphoto, :iconposition, :iconwindow, :manage, :maxsize,
    :minsize, :overrideredirect, :positionfrom, :protocol, :resizable, :sizefrom,
    :stackorder, :state, :title, :transient, :withdraw)

"""
    TclTk.wm(T=Nothing, cmd, w::TkWidget, args...; kwds...) -> res::T
    wm.cmd(T=Nothing, w::TkWidget, args...; kwds...) -> res::T

Interact with the window manager to query or control such things as the title for widget
`w`, its geometry, etc. Argument `T` is the expected type for the result. With the syntax
`wm.cmd(w, ...)` the result has a suitable default type that depends on `cmd`.

The window manager command `cmd` is one of $("`" * join(WM_COMMANDS, "`, `", "`, or `") * "`").

"""
wm(cmd::Word, w::TkWidget, args...; kwds...) = wm(Nothing, cmd, w, args...; kwds...)
function wm(::Type{T}, cmd::Word, w::TkWidget, args...; kwds...) where {T}
    return tcl_exec(T, "::wm", cmd, w, args...; kwds...)
end

Base.propertynames(f::typeof(wm)) = WM_COMMANDS

# Implement sub-commands for `wm` as properties.
@inline Base.getproperty(f::typeof(wm), key::Symbol) = _getproperty(f, Val(key))
_getproperty(f::typeof(wm), ::Val{key}) where {key} = throw(KeyError(key))

for cmd in WM_COMMANDS
    func = Symbol("wm_", cmd)
    @eval begin
        # Associate property with function implementing the sub-command.
        _getproperty(f::typeof(wm), ::$(Val{cmd})) = $func

        # Implement sub-command function when return type is specified by caller.
        $func(::Type{T}, w::TkWidget, args...; kwds...) where {T} =
            wm(T, $(QuoteNode(cmd)), w, args...; kwds...)
    end
end

# The sub-commands of `wm` with suitable default return type depending on argument types.

wm_aspect(w::TkWidget) = wm_aspect(TclObj, w)
wm_aspect(w::TkWidget, minNum, minDen, maxNum, maxDen) =
    wm_aspect(Nothing, w, minNum, minDen, maxNum, maxDen)

# TODO parse attributes as, say, a dictionary.
wm_attributes(w::TkWidget) = wm_attributes(TclObj, w)
wm_attributes(w::TkWidget, opt::Word) = wm_attributes(TclObj, w, with_hyphen(opt))
wm_attributes(::Type{T}, w::TkWidget, opt::Word) where {T} = wm(T, :attributes, w, with_hyphen(opt))
wm_attributes(w::TkWidget, pairs::Pair...; kwds...) = wm_attributes(Nothing, w, pairs...; kwds...)

wm_client(w::TkWidget) = wm_client(String, w)
wm_client(::Type{T}, w::TkWidget) where {T} = wm(T, :client, w)
wm_client(w::TkWidget, name) = wm_client(Nothing, w)
wm_client(::Type{T}, w::TkWidget, name) where {T} = wm(T, :client, w, name)

wm_colormapwindows(w::TkWidget) = wm_colormapwindows(TclObj, w)
wm_colormapwindows(w::TkWidget, list) = wm_colormapwindows(Nothing, w, list)
wm_colormapwindows(w::TkWidget, arg, args...) = wm_colormapwindows(Nothing, w, (arg, args...,))

wm_command(w::TkWidget) = wm_command(TclObj, w)
wm_command(w::TkWidget, list) = wm_command(Nothing, w, list)
wm_command(w::TkWidget, arg, args...) = wm_command(Nothing, w, (arg, args...,))

wm_deiconify(w::TkWidget) = wm_deiconify(Nothing, w)

wm_focusmodel(w::TkWidget) = wm_focusmodel(Symbol, w)
wm_focusmodel(w::TkWidget, model) = wm_focusmodel(Nothing, w, model)

wm_forget(w::TkWidget) = wm_forget(Nothing, w)

# TODO define platform-specific type of window identifier
wm_frame(w::TkWidget) = wm_frame(String, w)

wm_geometry(w::TkWidget) = wm_geometry(String, w)
wm_geometry(w::TkWidget, geometry) = wm_geometry(Nothing, w, geometry)

wm_grid(w::TkWidget) = wm_grid(TclObj, w)
wm_grid(w::TkWidget, baseWidth, baseHeight, widthInc, heightInc) =
    wm_grid(Nothing, w, baseWidth, baseHeight, widthInc, heightInc)

wm_group(w::TkWidget) = wm_group(Symbol, w)
wm_group(w::TkWidget, path) = wm_group(Nothing, w, path)

wm_iconbadge(w::TkWidget, badge) = wm_iconbadge(Nothing, w, badge)

wm_iconbitmap(w::TkWidget) = wm_iconbitmap(String, w)
wm_iconbitmap(w::TkWidget, args...; kwds...) = wm_iconbitmap(Nothing, w, args...; kwds...)
function wm_iconbitmap(::Type{T}, w::TkWidget, bitmap; default::Bool=false) where {T}
    if default
        wm(T, :iconbitmap, w, "-default", bitmap)
    else
        wm(T, :iconbitmap, w, bitmap)
    end
end

wm_iconify(w::TkWidget) = wm_iconify(Nothing, w)

wm_iconmask(w::TkWidget) = wm_iconmask(String, w)
wm_iconmask(w::TkWidget, bitmap) = wm_iconmask(Nothing, w, bitmap)

wm_iconname(w::TkWidget) = wm_iconname(String, w)
wm_iconname(w::TkWidget, name) = wm_iconname(Nothing, w, name)

wm_iconphoto(w::TkWidget, args...; kwds...) = wm_iconphoto(Nothing, w, args...; kwds...)
function wm_iconphoto(::Type{T}, w::TkWidget, img, imgs...; default::Bool=false) where {T}
    if default
        wm(T, :iconphoto, w, "-default", img, imgs...)
    else
        wm(T, :iconphoto, w, img, imgs...)
    end
end

wm_iconposition(w::TkWidget) = wm_iconposition(TclObj, w)
wm_iconposition(w::TkWidget, x, y) = wm_iconposition(Nothing, w, x, y)

wm_iconwindow(w::TkWidget) = wm_iconwindow(String, w)
wm_iconwindow(w::TkWidget, path) = wm_iconwindow(Nothing, w, path)

wm_manage(w::TkWidget) = wm_manage(Nothing, w)

wm_maxsize(w::TkWidget) = wm_maxsize(NTuple{2,Int}, w)
wm_maxsize(w::TkWidget, x, y) = wm_maxsize(Nothing, w, x, y)

wm_minsize(w::TkWidget) = wm_minsize(NTuple{2,Int}, w)
wm_minsize(w::TkWidget, x, y) = wm_minsize(Nothing, w, x, y)

wm_overrideredirect(w::TkWidget) = wm_overrideredirect(Bool, w)
wm_overrideredirect(w::TkWidget, bool) = wm_overrideredirect(Nothing, w, bool)

wm_positionfrom(w::TkWidget) = wm_positionfrom(String, w)
wm_positionfrom(w::TkWidget, who) = wm_positionfrom(Nothing, w, who)

wm_protocol(w::TkWidget) = wm_positionfrom(TclObj, w)
wm_protocol(w::TkWidget, args...) = wm_positionfrom(Nothing, w, args...)

wm_resizable(w::TkWidget) = wm_resizable(NTuple{2,Bool}, w)
wm_resizable(w::TkWidget, width, height) = wm_resizable(Nothing, w, width, height)

wm_sizefrom(w::TkWidget) = wm_sizefrom(String, w)
wm_sizefrom(w::TkWidget, who) = wm_sizefrom(Nothing, w, who)

wm_stackorder(w::TkWidget) = wm_sizefrom(TclObj, w)
wm_stackorder(w::TkWidget, args...) = wm_sizefrom(Nothing, w, args...)

wm_state(w::TkWidget) = wm_state(Symbol, w)
wm_state(w::TkWidget, state) = wm_state(Nothing, w, state)

wm_title(w::TkWidget) = wm_title(String, w)
wm_title(w::TkWidget, title) = wm_title(Nothing, w, title)

wm_transient(w::TkWidget) = wm_transient(String, w)
wm_transient(w::TkWidget, container) = wm_transient(Nothing, w, container)

wm_withdraw(w::TkWidget) = wm_withdraw(Nothing, w)
