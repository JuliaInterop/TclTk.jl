baremodule TclTk

export
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
    TclInterp,
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
    TCL_LEAVE_ERR_MSG,

    # Methods.
    tcl_error,
    tcl_library,
    tcl_version,
    tk_chooseColor,
    tk_chooseDirectory,
    tk_getOpenFile,
    tk_getSaveFile,
    tk_messageBox,
    tk_start

# Non-exported public symbols.
for sym in (
    # Modules.
    :Tk,
    :Ttk,

    # Types.
    :Callback,
    :NothingOr,
    :Value,
    :Variable,
    :WideInt,

    # Methods.
    :bool,
    :cget,
    :concat,
    :configure,
    :deletecommand,
    :do_events,
    :do_one_event,
    :eval,
    :exec,
    :exists,
    :getresult,
    :getvar,
    :grid,
    :isactive,
    :isdeleted,
    :isrunning,
    :issafe,
    :list,
    :pack,
    :place,
    :quote_string,
    :resume,
    :setresult!,
    :setvar!,
    :setvar, # FIXME deprecated
    :suspend,
    :unsetvar!,
    :unsetvar, # FIXME deprecated
    :winfo,
    )

    # Import symbols from the `Impl` module and declare them as "public".
    if sym ∉ (:eval,)
        @eval import .Impl: $sym
    end
    if VERSION ≥ v"1.11.0-DEV.469"
        @eval $(Base.Expr(:public, sym))
    end
end

end # module
