module TclTk

# Exported public symbols.
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

    # Tk images.
    TkBitmap,
    TkImage,
    TkPhoto,

    # Widgets.
    TkWidget,

    # Tk dialogs.
    tk_choosecolor,
    tk_choosedirectory,
    tk_getopenfile,
    tk_getopenfiles,
    tk_getsavefile,
    tk_messagebox,

    # Re-export from UnsetIndex.
    unset

# Non-exported public symbols.
using TypeUtils: @public
@public(
    # Modules.
    Tk,
    Ttk,

    # Types.
    NothingOr,
    Value,
    WideInt,

    # Methods.
    cget,
    configure,
    deletecommand,
    expand!,
    grid,
    pack,
    place,
    winfo,
    wm
)

using CEnum
using ColorTypes
using Colors
using FixedPointNumbers
using Reexport
using UnsetIndex

include("defs.jl")
include("types.jl")
include("api.jl")
include("arrays.jl")
include("dialogs.jl")
include("impl.jl")
@reexport import .Impl:
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
    Treeview

import .Impl:
    # Modules.
    Tk,
    Ttk,

    # Types.
    NothingOr,
    Value,
    WideInt,

    # Methods.
    bool

@deprecate tk_messageBox(args...; kwds...) tk_messagebox(args...; kwds...) true
@deprecate tk_getSaveFile(args...; kwds...) tk_getsavefile(args...; kwds...) true
@deprecate tk_getOpenFile(args...; kwds...) tk_getopenfile(args...; kwds...) true
@deprecate tk_getOpenFiles(args...; kwds...) tk_getopenfiles(args...; kwds...) true
@deprecate tk_chooseColor(args...; kwds...) tk_choosecolor(args...; kwds...) true
@deprecate tk_chooseDirectory(args...; kwds...) tk_choosedirectory(args...; kwds...) true

end # module
