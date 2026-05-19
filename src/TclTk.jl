module TclTk

export
    # Tcl types.
    TclCallback,
    TclError,
    TclObj,
    TclStatus,
    TclVariable,

    # Version.
    TCL_MAJOR_VERSION,
    TCL_MINOR_VERSION,
    TCL_ALPHA_RELEASE,
    TCL_BETA_RELEASE,
    TCL_FINAL_RELEASE,

    # Status constants.
    TCL_OK,
    TCL_ERROR,
    TCL_RETURN,
    TCL_BREAK,
    TCL_CONTINUE,

    # Tcl methods.
    tcl_concat,
    tcl_error,
    tcl_eval,
    tcl_evalfile,
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
using CEnum
using Reexport
using UnsetIndex

include("CoreDefs.jl")
include("types.jl")
include("api.jl")
include("Core.jl")
#FIXME @reexport import .Core:
    #FIXME # Tk images.
    #FIXME TkBitmap,
    #FIXME TkImage,
    #FIXME TkPhoto,
    #FIXME
    #FIXME # Widgets.
    #FIXME TkWidget,
    #FIXME Button,
    #FIXME Canvas,
    #FIXME Checkbutton,
    #FIXME Combobox,
    #FIXME Entry,
    #FIXME Frame,
    #FIXME Label,
    #FIXME Labelframe,
    #FIXME Listbox,
    #FIXME Menu,
    #FIXME Menubutton,
    #FIXME Message, # use Ttk.Label
    #FIXME Notebook,
    #FIXME Panedwindow,
    #FIXME Progressbar,
    #FIXME Radiobutton,
    #FIXME Scale,
    #FIXME Scrollbar,
    #FIXME Separator,
    #FIXME Sizegrip,
    #FIXME Spinbox,
    #FIXME Text,
    #FIXME Toplevel,
    #FIXME Treeview,

    # Methods.
    #FIXME tk_chooseColor,
    #FIXME tk_chooseDirectory,
    #FIXME tk_getOpenFile,
    #FIXME tk_getSaveFile,
    #FIXME tk_messageBox

#FIXME # Non-exported public symbols.
#FIXME for sym in (
#FIXME     # Modules.
#FIXME     :Tk,
#FIXME     :Ttk,
#FIXME
#FIXME     # Types.
#FIXME     :Callback,
#FIXME     :NothingOr,
#FIXME     :Value,
#FIXME     :WideInt,
#FIXME
#FIXME     # Methods.
#FIXME     :bool,
#FIXME     :cget,
#FIXME     :configure,
#FIXME     :deletecommand,
#FIXME     :grid,
#FIXME     :pack,
#FIXME     :place,
#FIXME     :winfo,
#FIXME     )
#FIXME
#FIXME     # Import symbols from the `Core` module and declare them as "public".
#FIXME     if sym ∉ (:eval,)
#FIXME         @eval import .Core: $sym
#FIXME     end
#FIXME     if VERSION ≥ v"1.11.0-DEV.469"
#FIXME         @eval $(Base.Expr(:public, sym))
#FIXME     end
#FIXME end

end # module
