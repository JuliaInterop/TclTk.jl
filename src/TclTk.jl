baremodule TclTk

export
    tcl_concat,
    tcl_eval,
    tcl_exec,
    tcl_getvar,
    tcl_isassigned,
    tcl_library,
    tcl_list,
    tcl_quote_string,
    tcl_setvar,
    tcl_unsetvar,
    tcl_version,

    # Re-export from UnsetIndex.
    unset

using Base
using Reexport
using UnsetIndex

# TclTk is a bare module because it implements its own `eval` function.
function eval end

# Being a bare module, we must define our `include` function.
include(file) = Base.include(@__MODULE__, file)

include("api.jl")

include("Impl.jl")
@reexport import .Impl:
    # Types.
    TclError,
    TclObj,
    TclStatus,

    # Tk images.
    TkBitmap,
    TkImage,
    TkPhoto,

    # Widgets.
    TkWidget,
    Button,
    Canvas,
    Checkbutton,
    Combobox,
    Entry,
    Frame,
    Label,
    Labelframe,
    Listbox,
    Menu,
    Menubutton,
    Message, # use Ttk.Label
    Notebook,
    Panedwindow,
    Progressbar,
    Radiobutton,
    Scale,
    Scrollbar,
    Separator,
    Sizegrip,
    Spinbox,
    Text,
    Toplevel,
    Treeview,
    TclVariable,


    # Version.
    TCL_MAJOR_VERSION,
    TCL_MINOR_VERSION,

    # Status constants.
    TCL_OK,
    TCL_ERROR,
    TCL_RETURN,
    TCL_BREAK,
    TCL_CONTINUE,

    # Constants for events.
    TCL_DONT_WAIT,
    TCL_WINDOW_EVENTS,
    TCL_FILE_EVENTS,
    TCL_TIMER_EVENTS,
    TCL_IDLE_EVENTS,
    TCL_ALL_EVENTS,

    # Constants for variables.
    TCL_GLOBAL_ONLY,
    TCL_NAMESPACE_ONLY,
    TCL_APPEND_VALUE,
    TCL_LIST_ELEMENT,
    TCL_LEAVE_ERR_MSG

    # Methods.
    #FIXME tk_chooseColor,
    #FIXME tk_chooseDirectory,
    #FIXME tk_getOpenFile,
    #FIXME tk_getSaveFile,
    #FIXME tk_messageBox

# Non-exported public symbols.
for sym in (
    #FIXME # Modules.
    #FIXME :Tk,
    #FIXME :Ttk,
    #FIXME
    #FIXME # Types.
    #FIXME :Callback,
    #FIXME :NothingOr,
    #FIXME :Value,
    #FIXME :WideInt,
    #FIXME
    #FIXME # Methods.
    #FIXME :bool,
    #FIXME :cget,
    #FIXME :configure,
    #FIXME :deletecommand,
    #FIXME :grid,
    #FIXME :pack,
    #FIXME :place,
    #FIXME :winfo,
    )

    # Import symbols from the `Impl` module and declare them as "public".
    if sym ∉ (:eval,)
        @eval import .Impl: $sym
    end
    if VERSION ≥ v"1.11.0-DEV.469"
        @eval $(Base.Expr(:public, sym))
    end
end

@deprecate list(args...) tcl_list(args...) false
@deprecate concat(args...) tcl_concat(args...) false

end # module
