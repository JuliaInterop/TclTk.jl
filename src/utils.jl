# Useful methods for the Julia interface to Tcl/Tk.

#-------------------------------------------------------------------------------- Pointers -

Base.pointer(obj::TclObj) = getfield(obj, :ptr)

# The string representation of a Tcl object is owned by Tcl's value manager, so getting a C
# string pointer from this string is always safe unless object pointer is null.
Base.unsafe_convert(::Type{Cstring}, obj::TclObj) =
    Base.unsafe_convert(Cstring, pointer(obj))
Base.unsafe_convert(::Type{Cstring}, objptr::ObjPtr) =
    isnull(objptr) ? unexpected_null(objptr) : Cstring(Tcl_GetString(objptr))
Base.unsafe_convert(::Type{ObjPtr}, obj::TclObj) = checked_pointer(obj)
Base.cconvert(::Type{Cstring}, obj::TclObj) = obj
Base.cconvert(::Type{Cstring}, objptr::ObjPtr) = objptr

# For a Tcl object, a valid pointer is simply non-null.
function checked_pointer(obj::TclObj)
    ptr = pointer(obj)
    isnull(ptr) && unexpected_null(ptr)
    return ptr
end

@noinline thread_mismatch() = throw(AssertionError(
    "attempt to use a Tcl interpreter in a different thread"))

"""
    TclTk.Core.isnull(ptr) -> bool

Return whether pointer `ptr` is null.

# See also

[`TclTk.Core.null`](@ref).

"""
isnull(ptr::Union{Ptr,Cstring}) = ptr === null(ptr)

"""
    TclTk.Core.null(ptr) -> nullptr
    TclTk.Core.null(typeof(ptr)) -> nullptr

Return a null-pointer of the same type as `ptr`.

# See also

[`TclTk.Core.isnull`](@ref).

"""
null(ptr::Union{Ptr,Cstring}) = null(typeof(ptr))
null(::Type{Ptr{T}}) where {T} = Ptr{T}(0)
null(::Type{Cstring}) = Cstring(C_NULL)

@noinline unexpected_null(str::AbstractString) = assertion_error("unexpected null ", str)
@noinline unexpected_null(x::Any) = unexpected_null(typeof(x))
@noinline unexpected_null(::Type{InterpPtr}) =
    unexpected_null("Tcl interpreter")
@noinline unexpected_null(::Type{<:Union{TclObj,ObjPtr}}) =
    unexpected_null("Tcl object")
@noinline unexpected_null(::Type{Ptr{T}}) where {T} =
    unexpected_null("pointer to object of type `$T`")
@noinline unexpected_null(::Type{T}) where {T} =
    unexpected_null("object of type `$T`")

function unsafe_memcmp(a, b, nbytes)
    # NOTE `Ptr{UInt8}`, not `Ptr{Cvoid}`, to have it works for `FastString`.
    return @ccall memcmp(a::Ptr{UInt8}, b::Ptr{UInt8}, nbytes::Csize_t)::Cint
end

function unsafe_memcpy(a, b, nbytes)
    return @ccall memcpy(a::Ptr{Cvoid}, b::Ptr{Cvoid}, nbytes::Csize_t)::Ptr{Cvoid}
end

#----------------------------------------------------- Prefixed functions and sub-commands -

(f::PrefixedFunction)(args...; kwds...) = f.func(f.arg1, args...; kwds...)

SubCommand{C}(caller::W) where {C,W} = SubCommand{C,W}(caller)

# NOTE A sub-command may be specialized on its symbolic name (and caller type)
#      to implement specific syntax.
(f::SubCommand{C})(args...; kwds...) where {C} = f.caller(C, args...; kwds...)
(f::SubCommand{C})(::Type{T}, args...; kwds...) where {C,T} =
    f.caller(T, C, args...; kwds...)

#-------------------------------------------------------------------------------- Booleans -

"""
    TclTk.bool(x) -> t::Bool

Convert `x` to a Boolean value according to Tcl rules.

"""
bool(x::Bool) = x
bool(x::Real) = !iszero(x) # this is what is assumed by Tcl
bool(obj::TclObj) = convert(Bool, obj)
bool(s::Symbol) = bool(String(s))
function bool(s::AbstractString)
    x = tryparse(Float64, s)
    isnothing(x) || return bool(x)
    t = lowercase(s)
    t ∈ ("true", "yes", "on") && return true
    t ∈ ("false", "no", "off") && return false
    argument_error("`s` in not a valid Tcl Boolean string")
end

#------------------------------------------------------------------------ Automatic names -

"""
    TclTk.Core.auto_name(pfx = "jl_auto_")

Return a unique name with given prefix. The result is a string of the form `pfx#` where `#`
is a unique number.

"""
function auto_name(pfx::AbstractString = "jl_auto_")
    global auto_name_dict
    T = valtype(auto_name_dict)
    n = get(auto_name_dict, pfx, zero(T)) + one(T)
    auto_name_dict[pfx] = n
    return pfx*string(n)
end

const auto_name_dict = Dict{String,UInt64}()

#---------------------------------------------------------------------------------- Errors -

"""
    TclTk.Core.get_error_message(ex)

Return the error message associated with exception `ex`.

"""
get_error_message(ex::Exception) = sprint(io -> showerror(io, ex))

@noinline argument_error(mesg::AbstractString) = throw(ArgumentError(mesg))
@noinline argument_error(arg, args...) = argument_error(string(arg, args...))

@noinline assertion_error(mesg::AbstractString) = throw(AssertionError(mesg))
@noinline assertion_error(arg, args...) = assertion_error(string(arg, args...))

@noinline dimension_mismatch(mesg::AbstractString) = throw(DimensionMismatch(mesg))
@noinline dimension_mismatch(arg, args...) = dimension_mismatch(string(arg, args...))

"""
    TclTk.Core.unsafe_error(interp)

Throw a Tcl error with a message stored in the result of `interp`.

!!! warning
    This method is *unsafe*: the interpreter pointer must be non-null and valid during the
    call.

"""
@noinline unsafe_error(interp::InterpPtr) = tcl_error(unsafe_result(String, interp))

"""
    TclTk.Core.unsafe_error(interp, mesg)

Throw a Tcl error. The error message is given by the result of `interp` if it refers to a
non-null Tcl interpreter with a non-empty result; otherwise, the error message is `mesg`.

!!! warning
    This method is *unsafe*: if non-null, the interpreter pointer must remain valid during
    the call.

# See also

[`TclTk.Core.unsafe_convert`](@ref) and [`TclTk.Core.unsafe_result`](@ref).

"""
@noinline unsafe_error(interp::InterpPtr, mesg::AbstractString) =
    tcl_error(unsafe_error_message(interp, mesg))

function unsafe_error_message(interp::InterpPtr, mesg::AbstractString)
    if !isnull(interp)
        cstr = Tcl_GetStringResult(interp)
        if !isnull(cstr) && !iszero(unsafe_load(Ptr{UInt8}(cstr)))
            return unsafe_string(cstr)
        end
    end
    return String(mesg)
end
