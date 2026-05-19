#
# types.jl -
#
# Definitions of types and constants for Tcl/Tk.
#

const InterpPtr = Ptr{Tcl_Interp}
const ObjTypePtr = Ptr{Tcl_ObjType}
const ObjPtr = Ptr{Tcl_Obj}

#@assert Tcl_Obj_typePtr_type === Tcl_ObjType

struct TclError <: Exception
    msg::String
end

# Simple decorator to indicate a verified argument.
struct Verified{T}
    value::T
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
    ptr::ObjPtr
    global _TclObj
    function _TclObj(ptr::ObjPtr)
        if !isnull(ptr)
            _ = unsafe_object_type(ptr) # register object's type
            Tcl_IncrRefCount(ptr)
        end
        return finalizer(finalize, new(ptr))
    end
end

# A temporary (i.e. inside a `GC.@preserve` block) read-only list of Tcl objects.
struct UnsafeList <: AbstractVector{ObjPtr}
    objv::Ptr{ObjPtr}
    objc::Int
end

# Safe version of `UnsafeList` used as an iterator. The parent holds a reference on the
# object so that the "unsafe" list remains valid.
struct ListIterator
    parent::TclObj
    list::UnsafeList
    function ListIterator(list::TclObj)
        GC.@preserve list begin
            return new(list, UnsafeList(pointer(list)))
        end
    end
end

# `Callback` must be mutable to have a stable address given by `pointer_from_objref`.
mutable struct Callback{F<:Function}
    token::Tcl_Command
    func::F
end

struct Variable{T}
    name::TclObj
end

# Floating-point types.
const FloatingPoint = Union{Irrational,Rational,AbstractFloat}

"""
    TclTk.NothingOr{T}

Singleton type representing the union `Union{Nothing,T}` used to extract the, possibly
empty, value of an object or result of a sub-command.

"""
struct NothingOr{T} end

struct PrefixedFunction{F,T}
    func::F
    arg1::T
end

struct SubCommand{C,W}
    caller::W
end

# A "word" in a command (must not be a number) also used for option names.
const Word = Union{AbstractString,Symbol,TclObj}

# An item tag or identifier in a canvas.
const TagOrId = Union{Word,Integer}

# `Name` is anything that can be understood as the name of a variable or of a command.
const Name = Union{Word,Real}

# A Tcl variable name can be specified as `(part1,part2)`.
const VarName = Union{Name,NTuple{2,Name}}

"""
    TclTk.Impl.FastString

Union of types of objects that can be converted into an UTF-8 `Cstring` by `ccall` without
overheads. More specifically, for an instance `str` of this union, the following hold:

* `Base.unsafe_convert(Cstring, str)` is applicable and fast.

* `Base.unsafe_convert(Ptr{UInt8}, str)` and `sizeof(str)` are applicable and respectively
  give the address of the first byte of `str` and the number of bytes in `str`.

"""
const FastString = Union{String,SubString{String},Symbol}

# Union of types for which `string(x...)` is faster than writing in an `IOBuffer` or calling
# `sprint`.
const FasterString = Union{#=Char,=# String, SubString{String}, Symbol}

# Known enumeration types.
const Enumeration{T} = Union{Enum{T}, CEnum.Cenum{T}}

"""
    TclTk.Value

Union of *extern* types (i.e. not defined by the `TclTk` package) that can be converted into
a Tcl object and conversely.

"""
const Value = Union{AbstractArray, AbstractChar, AbstractString,
                    Colorant, Enumeration, Real, Tuple, Symbol}

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

# Alias for specifying an index range in an image/array view.
const ViewRange{T<:Integer} = Union{Colon,AbstractUnitRange{<:T}}
