"""
    tcl_isassigned(var) -> bool::Bool

Return whether global Tcl variable named `var` is associated with a value. For a Tcl array
element, `var` may be a 2-tuple `(part1, part2)`.

# See also

[`tcl_getvar`](@ref), [`tcl_setvar`](@ref), [`tcl_unsetvar`](@ref), and
[`TclVariable`](@ref).

"""
function tcl_isassigned(var::Name)
    GC.@preserve var begin
        part1 = null(ObjPtr)
        part2 = null(ObjPtr)
        try
            # Increment reference counts.
            part1 = Tcl_IncrRefCount(unsafe_objptr(var, "Tcl variable name"))::ObjPtr
            # Call C function in the thread where lives the interpreter (may throw).
            return unsafe_isassigned(part1, part2)
        finally
            # Decrement reference counts.
            isnull(part1) || Tcl_DecrRefCount(part1)
        end
    end
end

function tcl_isassigned(var::NTuple{2,Name})
    GC.@preserve var begin
        part1 = null(ObjPtr)
        part2 = null(ObjPtr)
        try
            # Retrieve pointers and increment reference counts.
            part1 = Tcl_IncrRefCount(unsafe_objptr(var[1], "Tcl array name"))::ObjPtr
            part2 = Tcl_IncrRefCount(unsafe_objptr(var[2], "Tcl array index"))::ObjPtr
            # Call C function in the thread where lives the interpreter (may throw).
            return unsafe_isassigned(part1, part2)
        finally
            # Decrement reference counts.
            isnull(part1) || Tcl_DecrRefCount(part1)
            isnull(part2) || Tcl_DecrRefCount(part2)
        end
    end
end

function unsafe_isassigned(part1::Ptr{Tcl_Obj}, part2::Ptr{Tcl_Obj})
    result = with_interpreter() do interp
        unsafe_isassigned(interp, part1, part2)
    end
    return result::Bool
end

function unsafe_isassigned(interp::Ptr{Tcl_Interp},
                           part1::Ptr{Tcl_Obj}, part2::Ptr{Tcl_Obj})
    flags = TCL_GLOBAL_ONLY
    objptr = @ccall libtcl.Tcl_ObjGetVar2(interp::Ptr{Tcl_Interp}, part1::Ptr{Tcl_Obj},
                                          part2::Ptr{Tcl_Obj}, flags::Cint)::Ptr{Tcl_Obj}
    return !(isnull(objptr)::Bool)
end

"""
    tcl_getvar(T=TclObj, var) -> val::T

Return the value of the global Tcl variable named `var`. For a Tcl array element, `var` may
be a 2-tuple of array and element names.

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

If `T` is unspecified, `var` may be an instance of [`TclVariable`](@ref).

# See also

[`tcl_isassigned`](@ref), [`tcl_setvar`](@ref), [`tcl_unsetvar`](@ref), and
[`TclVariable`](@ref).

"""
tcl_getvar(var::VarName) = tcl_getvar(TclObj, var)

function tcl_getvar(::Type{T}, var::Name) where {T}
    GC.@preserve var begin
        part1 = null(ObjPtr)
        part2 = null(ObjPtr)
        try
            # Increment reference counts.
            part1 = Tcl_IncrRefCount(unsafe_objptr(var, "Tcl variable name"))::ObjPtr
            # Call C function in the thread where lives the interpreter (may throw).
            return unsafe_getvar(T, part1, part2)
        finally
            # Decrement reference counts.
            isnull(part1) || Tcl_DecrRefCount(part1)
        end
    end
end

function tcl_getvar(::Type{T}, var::NTuple{2,Name}) where {T}
    GC.@preserve var begin
        part1 = null(ObjPtr)
        part2 = null(ObjPtr)
        try
            # Retrieve pointers and increment reference counts.
            part1 = Tcl_IncrRefCount(unsafe_objptr(var[1], "Tcl array name"))::ObjPtr
            part2 = Tcl_IncrRefCount(unsafe_objptr(var[2], "Tcl array index"))::ObjPtr
            # Call C function in the thread where lives the interpreter (may throw).
            return unsafe_getvar(T, part1, part2)
        finally
            # Decrement reference counts.
            isnull(part1) || Tcl_DecrRefCount(part1)
            isnull(part2) || Tcl_DecrRefCount(part2)
        end
    end
end

function unsafe_getvar(::Type{T}, part1::Ptr{Tcl_Obj}, part2::Ptr{Tcl_Obj}) where {T}
    result = with_interpreter() do interp
        unsafe_getvar(T, interp, part1, part2)
    end
    return result::T
end

function unsafe_getvar(::Type{T}, interp::Ptr{Tcl_Interp}, part1::Ptr{Tcl_Obj},
                       part2::Ptr{Tcl_Obj}) where {T}
    flags = TCL_GLOBAL_ONLY|TCL_LEAVE_ERR_MSG
    objptr = @ccall libtcl.Tcl_ObjGetVar2(interp::Ptr{Tcl_Interp}, part1::Ptr{Tcl_Obj},
                                          part2::Ptr{Tcl_Obj}, flags::Cint)::Ptr{Tcl_Obj}
    isnull(objptr) && throw(TclError(unsafe_get_result(String, interp)))
    if T <: Nothing
        return nothing
    else
        return unsafe_convert(T, objptr)::T
    end
end

"""
    tcl_setvar(var, val) -> nothing
    tcl_setvar(T, var, val) -> newvalue::T

Set global Tcl variable `var` to value `val`. For a Tcl array element, `var` may be a
2-tuple of array and element names.

The Tcl variable is deleted if `val` is `unset`, the singleton provided by the `UnsetIndex`
package and exported by the `Tcl` package.

If a leading argument `T` other than `Nothing` is specified, the new value of the variable
is returned as an instance of type `T` (can be `TclObj`). The new value may be different
from `val` because of trace(s) associated to this variable.

# See also

[`tcl_getvar`](@ref), [`tcl_isassigned`](@ref), [`tcl_unsetvar`](@ref), and
[`TclVariable`](@ref).

"""
tcl_setvar(var::VarName, val) = tcl_setvar(Nothing, var, val)

function tcl_setvar(::Type{T}, var::Name, ::Unset) where {T}
    return convert(T, tcl_unsetvar(var; nocomplain=true))::T
end

function tcl_setvar(::Type{T}, var::Name, val) where {T}
    GC.@preserve var val begin
        part1 = null(ObjPtr)
        part2 = null(ObjPtr)
        value = null(ObjPtr)
        try
            # Retrieve pointers and increment reference counts.
            part1 = Tcl_IncrRefCount(unsafe_objptr(var, "Tcl variable name"))::ObjPtr
            value = Tcl_IncrRefCount(unsafe_objptr(val, "Tcl variable value"))::ObjPtr
            # Call C function in the thread where lives the interpreter (may throw).
            return unsafe_setvar(T, part1, part2, value)
        finally
            # Decrement reference counts.
            isnull(part1) || Tcl_DecrRefCount(part1)
            isnull(value) || Tcl_DecrRefCount(value)
        end
    end
end

function tcl_setvar(::Type{T}, var::NTuple{2,Name}, ::Unset) where {T}
    return convert(T, tcl_unsetvar(var; nocomplain=true))::T
end

function tcl_setvar(::Type{T}, var::NTuple{2,Name}, val) where {T}
    GC.@preserve var val begin
        part1 = null(ObjPtr)
        part2 = null(ObjPtr)
        value = null(ObjPtr)
        try
            # Retrieve pointers and increment reference counts.
            part1 = Tcl_IncrRefCount(unsafe_objptr(var[1], "Tcl array name"))::ObjPtr
            part2 = Tcl_IncrRefCount(unsafe_objptr(var[2], "Tcl array index"))::ObjPtr
            value = Tcl_IncrRefCount(unsafe_objptr(val, "Tcl array value"))::ObjPtr
            # Call C function in the thread where lives the interpreter (may throw).
            return unsafe_setvar(T, part1, part2, value)
        finally
            # Decrement reference counts.
            isnull(part2) || Tcl_DecrRefCount(part1)
            isnull(part1) || Tcl_DecrRefCount(part2)
            isnull(value) || Tcl_DecrRefCount(value)
        end
    end
end

function unsafe_setvar(::Type{T}, part1::Ptr{Tcl_Obj}, part2::Ptr{Tcl_Obj},
                       value::Ptr{Tcl_Obj}) where {T}
    result = with_interpreter() do interp
         unsafe_setvar(T, interp, part1, part2, value)
    end
    return result::T
end

function unsafe_setvar(::Type{T}, interp::Ptr{Tcl_Interp}, part1::Ptr{Tcl_Obj},
                       part2::Ptr{Tcl_Obj}, value::Ptr{Tcl_Obj}) where {T}
    flags = TCL_GLOBAL_ONLY|TCL_LEAVE_ERR_MSG
    objptr = @ccall libtcl.Tcl_ObjSetVar2(interp::Ptr{Tcl_Interp}, part1::Ptr{Tcl_Obj},
                                          part2::Ptr{Tcl_Obj}, value::Ptr{Tcl_Interp},
                                          flags::Cint)::Ptr{Tcl_Obj}
    isnull(objptr) && throw(TclError(unsafe_get_result(String, interp)))
    if T <: Nothing
        return nothing
    else
        return unsafe_convert(T, objptr)::T
    end
end

"""
    tcl_unsetvar(var)

Delete global Tcl variable named `var`. For a Tcl array element, `var` may be a 2-tuple of
array and element names.

# Keywords

Keyword `nocomplain` can be set true to ignore errors. By default, `nocomplain=false`.

# See also

[`tcl_getvar`](@ref), [`tcl_isassigned`](@ref), [`tcl_setvar`](@ref), and
[`TclVariable`](@ref).

"""
function tcl_unsetvar(var::Name; nocomplain::Bool=false)
    GC.@preserve var unsafe_unsetvar(var, C_NULL, nocomplain)
    return nothing
end

function tcl_unsetvar(var::NTuple{2,Name}; nocomplain::Bool=false)
    GC.@preserve var unsafe_unsetvar(var[1], var[2], nocomplain)
    return nothing
end

function unsafe_unsetvar(part1, part2, nocomplain::Bool)
    with_interpreter() do interp
         unsafe_unsetvar(interp, part1, part2, nocomplain)
    end
    return nothing
end

function unsafe_unsetvar(interp::Ptr{Tcl_Interp}, part1, part2, nocomplain::Bool)
    flags = nocomplain ? TCL_GLOBAL_ONLY : (TCL_GLOBAL_ONLY|TCL_LEAVE_ERR_MSG)
    status = @ccall libtcl.Tcl_UnsetVar2(interp::Ptr{Tcl_Interp}, part1::Cstring,
                                         part2::Cstring, flags::Cint)::TclStatus
    status == TCL_OK || nocomplain || throw(TclError(unsafe_get_result(String, interp)))
    return nothing
end
