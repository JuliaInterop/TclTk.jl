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
    tcl_deletecommand,
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

    # Tk images.
    TkBitmap,
    TkImage,
    TkPhoto,

    # Widgets.
    TkWidget,

    # Tk dialogs.
    tk_chooseColor,
    tk_chooseDirectory,
    tk_getOpenFile,
    tk_getSaveFile,
    tk_messageBox,

    # Re-export from UnsetIndex.
    unset

using CEnum
using ColorTypes
using Colors
using FixedPointNumbers
using Reexport
using UnsetIndex

include("CoreDefs.jl")
include("types.jl")
include("api.jl")
include("dialogs.jl")
include("Core.jl")
#FIXME @reexport import .Core:
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
    #FIXME Treeview
#FIXME # Non-exported public symbols.
#FIXME for sym in (
#FIXME     # Modules.
#FIXME     :Tk,
#FIXME     :Ttk,
#FIXME
#FIXME     # Types.
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

# TODO @deprecate tk_messageBox(args...; kwds...) tk_messagebox(args...; kwds...) true
# TODO @deprecate tk_getSaveFile(args...; kwds...) tk_getsavefile(args...; kwds...) true
# TODO @deprecate tk_getOpenFile(args...; kwds...) tk_getopenfile(args...; kwds...) true
# TODO @deprecate tk_getOpenFiles(args...; kwds...) tk_getopenfiles(args...; kwds...) true
# TODO @deprecate tk_chooseColor(args...; kwds...) tk_choosecolor(args...; kwds...) true
# TODO @deprecate tk_chooseDirectory(args...; kwds...) tk_choosedirectory(args...; kwds...) true

end # module
