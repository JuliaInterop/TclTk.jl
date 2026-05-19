function tcl_eval end
function tcl_exec end
function tcl_list end
function tcl_concat end
function tcl_getvar end
function tcl_setvar end
function tcl_unsetvar end
function tcl_exists end
function tcl_quote_string end
function tcl_version end
function tcl_library end

export wm

"""
    wm(T=Nothing, cmd, w::TkWidget, args...; kwds...) -> res::T
    wm.cmd(T, w::TkWidget, args...; kwds...) -> res::T
    wm.cmd(w::TkWidget, args...; kwds...) -> res

Interact with the window manager to query or control such things as the title for widget
`w`, its geometry, etc. Argument `T` is the expected type for the result. With the syntax
`wm.cmd(w, ...)` the result has a suitable default type that depends on `cmd`.

The window manger command `cmd` is one of ...

"""
function wm end
