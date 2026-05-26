#
# types.jl -
#
# Definitions of public types and constants for Tcl/Tk.
#

# Major and minor Tcl version.
const TCL_MAJOR_VERSION = Defs.TCL_MAJOR_VERSION
const TCL_MINOR_VERSION = Defs.TCL_MINOR_VERSION

# Release numbers.
const TCL_ALPHA_RELEASE = Defs.TCL_ALPHA_RELEASE
const TCL_BETA_RELEASE  = Defs.TCL_BETA_RELEASE
const TCL_FINAL_RELEASE = Defs.TCL_FINAL_RELEASE

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
    TCL_OK       = Defs.TCL_OK
    TCL_ERROR    = Defs.TCL_ERROR
    TCL_RETURN   = Defs.TCL_RETURN
    TCL_BREAK    = Defs.TCL_BREAK
    TCL_CONTINUE = Defs.TCL_CONTINUE
end

struct TclError <: Exception
    msg::String
end

"""
    WrappedObject

Abstract super-type of Julia objects that reflect or wrap a Tcl object.

Such objects implement [`TclTk.Impl.unsafe_objptr`](@ref) to yield a checked pointer to
their associated Tcl object.

"""
abstract type WrappedObject end

# Structure to store a pointer to a Tcl object. (Even though the address should not be
# modified, it is mutable because immutable objects cannot be finalized.) The constructor
# will refuse to build a managed Tcl object with a NULL address.
mutable struct TclObj <: WrappedObject
    ptr::Ptr{Defs.Tcl_Obj}
    global _TclObj
    function _TclObj(ptr::Ptr{Defs.Tcl_Obj})
        if !Impl.isnull(ptr)
            _ = Impl.unsafe_object_type(ptr) # register object's type
            Impl.Tcl_IncrRefCount(ptr)
        end
        return finalizer(Impl.finalize, new(ptr))
    end
end

# `TclCallback` must be mutable to have a stable address given by `pointer_from_objref`.
mutable struct TclCallback{F<:Function}
    token::Defs.Tcl_Command
    func::F
end

# A "word" in a command (must not be a number) also used for option names.
const Word = Union{AbstractString,Symbol,TclObj}

# An item tag or identifier in a canvas.
const TagOrId = Union{Word,Integer}

# `Name` is anything that can be understood as the name of a variable or of a command.
const Name = Union{Word,Real}

# A Tcl variable name can be specified as `(part1,part2)`.
const VarName = Union{Name,NTuple{2,Name}}

struct TclVariable{T}
    name::TclObj # name of global Tcl variable
    TclVariable{T}(name::Name) where {T} = new{T}(tcl_absname(name))
end

struct TclArray{K,V<:Name} <: AbstractDict{K,V}
    name::TclObj # name of global Tcl array
    TclArray{K,V}(name::Name) where {K,V} = new{K,V}(tcl_absname(name))
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
#
# The handle of an image remains unchanged for the life of the image.
#
# TODO There should be a mean to preserve the image in Tk while its counterpart in Julia
#      exists. Perhaps this can be done with Tcl_Preserve/Tcl_Release.
struct TkImage{T} <: TkObject
    name::TclObj
    handle::Ptr{Cvoid}
    global _TkImage
    function _TkImage(::Val{T}, name) where {T}
        T isa Symbol || argument_error("image type must be a symbol")
        handle = C_NULL::Ptr{Cvoid}
        if T === :photo
            handle = GC.@preserve name begin
                Impl.with_interpreter() do interp
                    @ccall Impl.libtk.Tk_FindPhoto(
                        interp::Ptr{Defs.Tcl_Interp}, name::Cstring)::Ptr{Cvoid}
                end
            end::Ptr{Cvoid}
            handle == C_NULL && TclError("invalid Tk photo name \"$name\"")
        end
        return new{T}(name, handle)
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
