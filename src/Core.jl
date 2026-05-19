"""

`TclTk.Core` module hosts the implementation of the `TclTk` package.

"""
module Core

using ..TclTk

# Import public symbols that are implemented or extended in this module.
import ..TclTk:
    # Constructors.
    TclObj,
    TclVariable,
    TclCallback,

    # Tcl methods.
    tcl_concat,
    tcl_eval,
    tcl_evalfile,
    tcl_exec,
    tcl_getvar,
    tcl_isassigned,
    tcl_library,
    tcl_list,
    tcl_setvar,
    tcl_unsetvar

using ..CoreDefs:
    # Constants for variables.
    TCL_GLOBAL_ONLY,
    TCL_NAMESPACE_ONLY,
    TCL_APPEND_VALUE,
    TCL_LIST_ELEMENT,
    TCL_LEAVE_ERR_MSG,

    # Constants for release.
    TCL_ALPHA_RELEASE,
    TCL_BETA_RELEASE,
    TCL_FINAL_RELEASE,

    # Flags for evaluating scripts/commands.
    TCL_NO_EVAL,
    TCL_EVAL_GLOBAL,
    TCL_EVAL_DIRECT,
    TCL_EVAL_INVOKE,
    TCL_CANCEL_UNWIND,
    TCL_EVAL_NOERR,

    # Flags for settings the result.
    TCL_VOLATILE,
    TCL_STATIC,
    TCL_DYNAMIC,

    # Flags for Tcl variables.
    TCL_GLOBAL_ONLY,
    TCL_NAMESPACE_ONLY,
    TCL_APPEND_VALUE,
    TCL_LIST_ELEMENT,
    TCL_LEAVE_ERR_MSG,

    # Flags for Tcl processing events.
    TCL_DONT_WAIT,
    TCL_WINDOW_EVENTS,
    TCL_FILE_EVENTS,
    TCL_TIMER_EVENTS,
    TCL_IDLE_EVENTS,
    TCL_ALL_EVENTS,

    # Core types.
    ClientData,
    Tcl_CmdDeleteProc,
    Tcl_CmdProc,
    Tcl_Command,
    Tcl_DupInternalRepProc,
    Tcl_FreeInternalRepProc,
    Tcl_FreeProc,
    Tcl_IdleProc,
    Tcl_Interp,
    Tcl_Obj,
    Tcl_ObjCmdProc,
    Tcl_ObjType,
    Tcl_SetFromAnyProc,
    Tcl_Size,
    Tcl_UpdateStringProc,
    WideInt

using Tcl_jll, Tk_jll
using CEnum
using ColorTypes
using Colors
using FixedPointNumbers
using Neutrals
using TypeUtils
using UnsetIndex: Unset, unset

if isdefined(Base, :Memory)
    const BasicVector{T} = Union{Vector{T},Memory{T}}
else
    const Memory{T} = Vector{T}
    const BasicVector{T} = Vector{T}
end

include("libtcl.jl")
include("libtk.jl")
include("utils.jl")
include("objects.jl")
include("lists.jl")
include("interp.jl")
include("variables.jl")
#include("callbacks.jl")
#include("events.jl")
#include("colors.jl")
#include("widgets.jl")
#include("dialogs.jl")
#include("images.jl")
#include("wm.jl")

function __init__()
    # Check that package was built with the same version as the dynamic library.
    version = tcl_version()
    (version.major, version.minor) == (TCL_MAJOR_VERSION, TCL_MINOR_VERSION) || assertion_error(
        "`TclTk` package assumes Tcl $(TCL_MAJOR_VERSION).$(TCL_MINOR_VERSION) while loaded library ",
        "has version $(version), `Project.toml` must be adjusted")

    # Many things do not work properly (segmentation fault when freeing a Tcl object,
    # initialization of Tcl interpreters, etc.) if Tcl internals (encodings, sub-systems,
    # etc.) are not properly initialized. This is done by the following call.
    @ccall libtcl.Tcl_FindExecutable(joinpath(Sys.BINDIR, "julia")::Cstring)::Cvoid

    # The table of known types is updated while objects of new types are created because
    # seeking for an existing type is much faster than creating the mutable TclObj
    # structure. Nevertheless, we know in advance that objects with NULL object type are
    # strings.
    unsafe_register_new_typename(ObjTypePtr(0))

    #FIXME # Compile C functions for callbacks.
    #FIXME release_object_proc[] = @cfunction(unsafe_release, Cvoid, (Ptr{Cvoid},))
    #FIXME eval_command_proc[] = @cfunction(eval_command, TclStatus,
    #FIXME                                  (ClientData, Ptr{Tcl_Interp},
    #FIXME                                   Cint, Ptr{Ptr{Tcl_Obj}}))

    return nothing
end

end # module
