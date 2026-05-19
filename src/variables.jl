# Private type to have `tcl_getvar` yields whether the variable is assigned.
struct _IsAssigned end

"""
   A = TclVariable{T}(name)

Return an object `A` which is linked to the Tcl variable named `name`. The variable value is
given by `A[]` and can be set by `A[] = x`.

Type parameter `T` is the assumed Julia type of the value that can be stored in this
variable. If not specified, `TclObj` is assumed for `T`, hence the variable may store any
type of Tcl object. If variable type parameter is `T = TclObj`, expression `fetch(S, A)`,
with `S` a type, can be used to efficiently convert the value of the variable to type `S`.

Currently, `name` must refer to a simple Tcl variable or to a single element of a Tcl array
(in which case, `name` may be a 2-tuple `(part1, part2)`), not to a Tcl array name.

Property `A.name` yields the name of the Tcl variable.

Call `eltype(A)` to retrieve the type of `A` and `isassigned(A)` or
[`tcl_isassigned(A)`](@ref tcl_isassigned) to check whether `A` has an associated value. To
unset the value of `A`, call `delete!(A)`, [`tcl_unsetvar(A)`](@ref tcl_unsetvar), or do
`A[] = unset`.

Example:

```julia-repl
julia> A = TclVariable{Int}("::GLOBAL_COUNTER")
TclVariable{Int64}(name: "::GLOBAL_COUNTER", value: #undef)

julia> A[] = 0
0

julia> A
TclVariable{Int64}(name: "::GLOBAL_COUNTER", value: 0)

julia> tcl_exec(:incr, A.name, 4) # increment variable with Tcl `incr` command

julia> A[]
4

```

"""
TclVariable(name::VarName) = TclVariable{TclObj}(name)
TclVariable{T}(name::Tuple{2,Name}) where {T} = TclVariable{T}(TclObj("$(name[1])($(name[2]))"))

Base.show(io::IO, ::MIME"text/plain", A::TclVariable) = show(io, A)
function Base.show(io::IO, A::TclVariable{T}) where {T}
    print(io, "TclVariable{", T, "}(name: \"")
    escape_string(io, string(A.name))
    print(io, "\", value: ")
    if isassigned(A)
        show(io, A[])
    else
        print(io, "#undef")
    end
    print(io, ")")
end

Base.eltype(::Type{TclVariable{T}}) where {T} = T

Base.isassigned(A::TclVariable) = tcl_isassigned(A.name)
tcl_isassigned(A::TclVariable) = isassigned(A)

Base.getindex(A::TclVariable{T}) where {T} = tcl_getvar(T, A.name)
Base.fetch(::Type{T}, A::TclVariable) where {T} = tcl_getvar(T, A)
tcl_getvar(A::TclVariable{T}) where {T} = tcl_getvar(T, A)
tcl_getvar(::Type{T}, A::TclVariable{<:Union{T,TclObj}}) where {T} = tcl_getvar(T, A.name)

function Base.setindex!(A::TclVariable, x)
    tcl_setvar(A, x)
    return A
end
tcl_setvar(A::TclVariable, x) = tcl_setvar(Nothing, A, x)
tcl_setvar(::Type{T}, A::TclVariable, x) where {T} = tcl_setvar(T, A.name, x)

Base.delete!(A::TclVariable) = tcl_unsetvar(A; nocomplain=true)
tcl_unsetvar(A::TclVariable; kwds...) = tcl_unsetvar(A.name; kwds...)

"""
    tcl_isassigned(name)

Return whether global Tcl variable named `name` is associated with a value. For a Tcl array
element, `name` may be a 2-tuple `(part1, part2)`.

# See also

[`tcl_getvar`](@ref), [`tcl_setvar`](@ref), and [`tcl_unsetvar`](@ref).

"""
function tcl_isassigned(name::VarName; flags::Integer=isassigned_flags())
    return tcl_getvar(_IsAssigned, name; flags=flags)
end

isassigned_flags() = TCL_GLOBAL_ONLY

"""
    tcl_getvar(T=TclObj, name) -> val::T

Return the value of the global Tcl variable named `name`. For a Tcl array element, `name`
may be a 2-tuple `(part1, part2)`.

Optional argument `T` (`TclObj` by default) can be used to specify the type of the returned
value. Some possibilities are:

* If `T` is `TclObj` (the default), a managed Tcl object is returned. This is the most
  efficient if the returned value is intended to be used in a Tcl list or as an argument of
  a Tcl script or command.

* If `T` is `Bool`, a boolean value is returned.

* If `T` is `String`, a string is returned.

* If `T` is `Char`, a single character is returned (an exception is thrown if Tcl object is
  not a single character string).

* If `T <: Integer`, an integer value of type `T` is returned.

* If `T <: AbstractFloat`, a floating-point value of type `T` is returned.

Note that, except if `T` is `TclObj`, a conversion of the Tcl object stored by the variable
may be needed.

# See also

[`tcl_isassigned`](@ref), [`tcl_setvar`](@ref), and [`tcl_unsetvar`](@ref).

"""
tcl_getvar(name::VarName; kwds...) = tcl_getvar(TclObj, name; kwds...)

getvar_flags() = (TCL_GLOBAL_ONLY|TCL_LEAVE_ERR_MSG)

function tcl_getvar(::Type{T}, name::Name; flags::Integer=getvar_flags()) where {T}
    GC.@preserve name begin
        name_ptr = null(ObjPtr)
        try
            # Increment reference counts.
            name_ptr = Tcl_IncrRefCount(unsafe_objptr(name, "Tcl variable name"))::ObjPtr
            # Call C function in the thread where lives the interpreter (may throw).
            return unsafe_getvar(T, name_ptr, null(ObjPtr), flags)
        finally
            # Decrement reference counts.
            isnull(name_ptr) || Tcl_DecrRefCount(name_ptr)
        end
    end
end

function tcl_getvar(::Type{T}, (part1, part2)::NTuple{2,Name};
                    flags::Integer = getvar_flags()) where {T}
    GC.@preserve part1 part2 begin
        part1_ptr = null(ObjPtr)
        part2_ptr = null(ObjPtr)
        try
            # Retrieve pointers and increment reference counts.
            part1_ptr = Tcl_IncrRefCount(unsafe_objptr(part1, "Tcl array name"))::ObjPtr
            part2_ptr = Tcl_IncrRefCount(unsafe_objptr(part2, "Tcl array index"))::ObjPtr
            # Call C function in the thread where lives the interpreter (may throw).
            return unsafe_getvar(T, part1_ptr, part2_ptr, flags)
        finally
            # Decrement reference counts.
            isnull(part1_ptr) || Tcl_DecrRefCount(part1_ptr)
            isnull(part2_ptr) || Tcl_DecrRefCount(part2_ptr)
        end
    end
end

"""
    tcl_setvar(name, value) -> nothing
    tcl_setvar(T, name, value) -> newvalue::T

Set global Tcl variable `name` to `value`. For a Tcl array element, `name` may be a 2-tuple
`(part1, part2)`.

The Tcl variable is deleted if `value` is `unset`, the singleton provided by the
`UnsetIndex` package and exported by the `Tcl` package.

If a leading argument `T` is specified, the new value of the variable is returned as an
instance of type `T` (can be `TclObj`). The new value may be different from `value` because
of trace(s) associated to this variable.

# See also

[`tcl_getvar`](@ref), [`tcl_isassigned`](@ref), and [`tcl_unsetvar`](@ref).

"""
tcl_setvar(name::VarName, value; kwds...) = tcl_setvar(Nothing, name, value; kwds...)

function tcl_setvar(::Type{T}, name::VarName, ::Unset; kwds...) where {T}
    return convert(T, tcl_unsetvar(name; nocomplain=true, kwds...))
end

setvar_flags() = (TCL_GLOBAL_ONLY|TCL_LEAVE_ERR_MSG)

function tcl_setvar(::Type{T}, name::Name, value; flags::Integer=setvar_flags()) where {T}
    GC.@preserve name value begin
        name_ptr = null(ObjPtr)
        value_ptr = null(ObjPtr)
        try
            # Retrieve pointers and increment reference counts.
            name_ptr = Tcl_IncrRefCount(unsafe_objptr(name, "Tcl variable name"))::ObjPtr
            value_ptr = Tcl_IncrRefCount(unsafe_objptr(value, "Tcl variable value"))::ObjPtr
            # Call C function in the thread where lives the interpreter (may throw).
            return unsafe_setvar(T, name_ptr, null(ObjPtr), value_ptr, flags)
        finally
            # Decrement reference counts.
            isnull(name_ptr) || Tcl_DecrRefCount(name_ptr)
            isnull(value_ptr) || Tcl_DecrRefCount(value_ptr)
        end
    end
end

function tcl_setvar(::Type{T}, (part1, part2)::NTuple{2,Name}, value;
                    flags::Integer = setvar_flags()) where {T}
    GC.@preserve part1 part2 value begin
        part1_ptr = null(ObjPtr)
        part2_ptr = null(ObjPtr)
        value_ptr = null(ObjPtr)
        try
            # Retrieve pointers and increment reference counts.
            part1_ptr = Tcl_IncrRefCount(unsafe_objptr(part1, "Tcl array name"))::ObjPtr
            part2_ptr = Tcl_IncrRefCount(unsafe_objptr(part2, "Tcl array index"))::ObjPtr
            value_ptr = Tcl_IncrRefCount(unsafe_objptr(value, "Tcl array value"))::ObjPtr
            # Call C function in the thread where lives the interpreter (may throw).
            return unsafe_setvar(T, part1_ptr, part2_ptr, value_ptr, flags)
        finally
            # Decrement reference counts.
            isnull(part2_ptr) || Tcl_DecrRefCount(part1_ptr)
            isnull(part1_ptr) || Tcl_DecrRefCount(part2_ptr)
            isnull(value_ptr) || Tcl_DecrRefCount(value_ptr)
        end
    end
end

"""
    tcl_unsetvar(name)

Delete global Tcl variable named `name`. For a Tcl array element, `name` may be a 2-tuple
`(part1, part2)`.

# Keywords

Keyword `nocomplain` can be set true to ignore errors. By default, `nocomplain=false`.

Keyword `flag` can be set with bits such as `TCL_GLOBAL_ONLY` (set by default) and
`TCL_LEAVE_ERR_MSG` (set by default unless `nocomplain` is true).

# See also

[`tcl_getvar`](@ref), [`tcl_isassigned`](@ref), and [`tcl_setvar`](@ref).

"""
function tcl_unsetvar(name::Name; nocomplain::Bool=false,
                      flags::Integer=unsetvar_flags(nocomplain))
    GC.@preserve name unsafe_unsetvar(name, C_NULL, flags, nocomplain)
    return nothing
end

function tcl_unsetvar((part1, part2)::NTuple{2,Name}; nocomplain::Bool=false,
                      flags::Integer=unsetvar_flags(nocomplain))
    GC.@preserve part1 part2 unsafe_unsetvar(part1, part2, flags, nocomplain)
    return nothing
end

function unsetvar_flags(nocomplain::Bool)
    return nocomplain ? TCL_GLOBAL_ONLY : (TCL_GLOBAL_ONLY|TCL_LEAVE_ERR_MSG)
end


# The following functions call `tcl_getvar`, `tcl_setvar`, or `tcl_unsetvar` in the thread
# where lives the Tcl interpreter and return a value of the required type (or throw).

function unsafe_getvar(::Type{T}, part1::Ptr{Tcl_Obj}, part2::Ptr{Tcl_Obj},
                       flags::Integer) where {T}
    with_interpreter() do interp
        value = @ccall libtcl.Tcl_ObjGetVar2(interp::Ptr{Tcl_Interp}, part1::Ptr{Tcl_Obj},
                                             part2::Ptr{Tcl_Obj}, flags::Cint)::Ptr{Tcl_Obj}
        if T <: _IsAssigned
            return !isnull(value)
        else
            isnull(value) && throw_variable_error(interp, "get", part1, part2, flags)
            return unsafe_convert(T, value)
        end
    end
end

function unsafe_setvar(::Type{T}, part1::Ptr{Tcl_Obj}, part2::Ptr{Tcl_Obj},
                       value::Ptr{Tcl_Obj}, flags::Integer) where {T}
    with_interpreter() do interp
        newval = @ccall libtcl.Tcl_ObjSetVar2(interp::Ptr{Tcl_Interp}, part1::Ptr{Tcl_Obj},
                                              part2::Ptr{Tcl_Obj}, value::Ptr{Tcl_Interp},
                                              flags::Cint)::Ptr{Tcl_Obj}
        isnull(newval) && throw_variable_error(interp, "set", part1, part2, flags)
        if T == Nothing
            return nothing
        else
            return unsafe_convert(T, newval)
        end
    end
end

function unsafe_unsetvar(part1, part2, flags::Integer, nocomplain::Bool)
    with_interpreter() do interp
        status = @ccall libtcl.Tcl_UnsetVar2(interp::Ptr{Tcl_Interp}, part1::Cstring,
                                             part2::Cstring, flags::Cint)::TclStatus
        status == TCL_OK || nocomplain || throw_variable_error(
            interp, "unset", part1, part2, flags)
        return nothing
    end
end

@noinline function throw_variable_error(interp::Ptr{Tcl_Interp}, op::AbstractString,
                                        part1, part2, flags::Integer)
    if isnull(interp) || iszero(flags & TCL_LEAVE_ERR_MSG)
        varname = unsafe_variable_name(part1, part2)
        mesg = "cannot "*op*" Tcl variable \""*varname*"\""
    else
        mesg = unsafe_get_result(String, interp)
    end
    throw(TclError(mesg))
end

unsafe_variable_name(name::String) = name
unsafe_variable_name(name::Name) = string(name)
unsafe_variable_name((part1,part2)::Tuple{Name,Name}) = "$(part1)($(part2))"
