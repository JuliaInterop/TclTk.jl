#
# types.jl -
#
# Definitions of public types and constants for Tcl/Tk.
#

# Major and minor Tcl version.
const TCL_MAJOR_VERSION = CoreDefs.TCL_MAJOR_VERSION
const TCL_MINOR_VERSION = CoreDefs.TCL_MINOR_VERSION

# Release numbers.
const TCL_ALPHA_RELEASE = CoreDefs.TCL_ALPHA_RELEASE
const TCL_BETA_RELEASE  = CoreDefs.TCL_BETA_RELEASE
const TCL_FINAL_RELEASE = CoreDefs.TCL_FINAL_RELEASE

"""
    TclStatus

Type of result returned by evaluating Tcl scripts or commands. Possible values are:

* `TCL_OK`: Command completed normally; the interpreter's result contains the command's
  result.

* `TCL_ERROR`: The command couldn't be completed successfully; the interpreter's result
  describes what went wrong.

Other existing values only used internally:

* `TCL_RETURN`: The command requests that the current function return; the interpreter's
  result contains the function's return value.

* `TCL_BREAK`: The command requests that the innermost loop be exited; the interpreter's
  result is meaningless.

* `TCL_CONTINUE`: Go on to the next iteration of the current loop; the interpreter's result
  is meaningless.

"""
@cenum TclStatus::Cint begin
    TCL_OK       = CoreDefs.TCL_OK
    TCL_ERROR    = CoreDefs.TCL_ERROR
    TCL_RETURN   = CoreDefs.TCL_RETURN
    TCL_BREAK    = CoreDefs.TCL_BREAK
    TCL_CONTINUE = CoreDefs.TCL_CONTINUE
end

struct TclError <: Exception
    msg::String
end

"""
    WrappedObject

Abstract super-type of Julia objects that reflect or wrap a Tcl object.

Such objects implement [`TclTk.Core.unsafe_objptr`](@ref) to yield a checked pointer to
their associated Tcl object.

"""
abstract type WrappedObject end

# Simple decorator to indicate a verified argument.
struct Verified{T}
    value::T
end

# Structure to store a pointer to a Tcl object. (Even though the address should not be
# modified, it is mutable because immutable objects cannot be finalized.) The constructor
# will refuse to build a managed Tcl object with a NULL address.
mutable struct TclObj <: WrappedObject
    ptr::Ptr{CoreDefs.Tcl_Obj}
    global _TclObj
    function _TclObj(ptr::Ptr{CoreDefs.Tcl_Obj})
        if !Core.isnull(ptr)
            _ = Core.unsafe_object_type(ptr) # register object's type
            Core.Tcl_IncrRefCount(ptr)
        end
        return finalizer(Core.finalize, new(ptr))
    end
end

# `TclCallback` must be mutable to have a stable address given by `pointer_from_objref`.
mutable struct TclCallback{F<:Function}
    token::CoreDefs.Tcl_Command
    func::F
end

struct TclVariable{T}
    name::TclObj
end

#-------------------------------------------------------------------------------------------
# Tk widgets and other Tk objects.
#
# Objects of type derived from `TkObject` (i.e., widgets and images) can be indexed by
# option name to access and mutate their configurable options, they also implement
# sub-commands by the syntax `obj.cmd(args...; kwds...)`.

abstract type TkObject <: WrappedObject end
abstract type TkWidget <: TkObject      end

# An image is parameterized by the symbolic image type.
struct TkImage{T} <: TkObject
    name::TclObj
    function TkImage{T}(name::Verified{TclObj}) where {T}
        T isa Symbol || argument_error("image type must be a symbol")
        return new{T}(name.value)
    end
end

"""
    TkBitmap(args...) -> img
    TkImage{:bitmap}(args...) -> img

Return a Tk *bitmap* image. See [`TkImage`](@ref) for more information.

"""
const TkBitmap = TkImage{:bitmap}

"""
    TkPhoto(args...) -> img
    TkImage{:photo}(args...) -> img

Return a Tk *photo* image. See [`TkImage`](@ref) for more information.

"""
const TkPhoto = TkImage{:photo}
