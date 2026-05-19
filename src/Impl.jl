"""

`TclTk.Impl` module hosts the implementation of the `TclTk` package.

"""
module Impl

import ..TclTk

import ..TclTk:
    tcl_concat,
    tcl_eval,
    tcl_exec,
    tcl_getvar,
    tcl_library,
    tcl_list,
    tcl_quote_string,
    tcl_setvar,
    tcl_unsetvar,
    tcl_exists,
    tcl_version

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
include("types.jl")
include("utils.jl")
include("objects.jl")
include("lists.jl")
include("interp.jl")
#include("variables.jl")
#include("callbacks.jl")
#include("events.jl")
#include("colors.jl")
#include("widgets.jl")
#include("dialogs.jl")
#include("images.jl")
#include("wm.jl")

#FIXME @deprecate getinterp(args...; kwds...) TclInterp(args...; kwds...) false

@deprecate setvar(args...; kwds...) setvar!(args...; kwds...) false
@deprecate unsetvar(args...; kwds...) unsetvar!(args...; kwds...) false

@deprecate exists(part1::Name, part2::Name) exists((part1, part2)) false
@deprecate exists(interp::TclInterp, part1::Name, part2::Name) exists(interp, (part1, part2)) false

@deprecate getvar(part1::Name, part2::Name; kwds...) getvar((part1, part2); kwds...) false
@deprecate getvar(T::Type, part1::Name, part2::Name; kwds...) getvar(T, (part1, part2); kwds...) false
@deprecate getvar(interp::TclInterp, part1::Name, part2::Name; kwds...) getvar(interp, (part1, part2); kwds...) false
@deprecate getvar(T::Type, interp::TclInterp, part1::Name, part2::Name; kwds...) getvar(T, interp, (part1, part2); kwds...) false

@deprecate setvar!(part1::Name, part2::Name, value; kwds...) setvar!((part1, part2), value; kwds...) false
@deprecate setvar!(T::Type, part1::Name, part2::Name, value; kwds...) setvar!(T, (part1, part2), value; kwds...) false
@deprecate setvar!(interp::TclInterp, part1::Name, part2::Name, value; kwds...) setvar!(interp, (part1, part2), value; kwds...) false
@deprecate setvar!(T::Type, interp::TclInterp, part1::Name, part2::Name, value; kwds...) setvar!(T, interp, (part1, part2), value; kwds...) false

@deprecate unsetvar!(part1::Name, part2::Name; kwds...) unsetvar!((part1, part2); kwds...) false
@deprecate unsetvar!(interp::TclInterp, part1::Name, part2::Name; kwds...) setvar!(interp, (part1, part2); kwds...) false

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

    # Compile C functions for callbacks.
    release_object_proc[] = @cfunction(unsafe_release, Cvoid, (Ptr{Cvoid},))
    eval_command_proc[] = @cfunction(eval_command, TclStatus,
                                     (ClientData, Ptr{Tcl_Interp},
                                      Cint, Ptr{Ptr{Tcl_Obj}}))
    return nothing
end

end # module
