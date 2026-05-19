"""
    callback = TclTk.Callback(f, name=TclTk.auto_name("jl_func_"), interp=TclInterp())
    callback = TclTk.Callback(f, interp=TclInterp(), name=TclTk.auto_name("jl_func_"))

Create a command implemented by the function `f` in Tcl interpreter `interp`. The command is
initially named `name` (`callback.name` gives the actual command name even though the
command is renamed).

The Tcl command will call the Julia function `f` as:

```julia
f(interp::TclInterp, args::TclObj)
```

where `interp` is the Tcl interpreter which calls the command and `args` is a Tcl list
object with the arguments of the command. The first element of `args` is the name of the
name of the command in the interpreter.

The method `f(interp, args)` may return up to two values (both optional):

* A `status` of type [`TclStatus`](@ref) (one of `TCL_OK`, `TCL_ERROR`, `TCL_RETURN`,
  `TCL_BREAK` or `TCL_CONTINUE`) to specify the issue of the callback. If omitted, `TCL_OK`
  is assumed for `status`.

* A `result` to be stored in the interpreter's result by calling `TclTk.setresult!(interp,
  result)`. If `result` is omitted or `nothing`, the interpreter's result is left unchanged
  (it may have been set by the callback by [`TclTk.setresult!`](@ref)).

If `status` and `result` are both returned by the callback, `status` must be first and
`result` second.

If the method `f(interp, args)` throws any exception, the error message associated with the
exception is stored in the interpreter's result and `TCL_ERROR` is returned by the
interpreter.

# See also

[`TclTk.deletecommand`](@ref), [`TclTk.auto_name`](@ref), and [`TclStatus`](@ref).

"""
function Callback(func::Function,
                  name::Name = callback_default_name(),
                  interp::TclInterp = TclInterp())
    callback = preserve(Callback{typeof(func)}(interp, C_NULL, func))
    try
        # Getting interpreter pointer or C string from `name` may throw, se we use a `try
        # ... catch` block.
        token = Tcl_CreateObjCommand(interp, name, eval_command_proc[],
                                     pointer_from_objref(callback),
                                     release_object_proc[])
        isnull(token) && tcl_error(interp)
        setfield!(callback, :token, token)
    catch
        release(callback)
        rethrow()
    end
    return callback
end

# Re-order optional arguments.
Callback(func::Function, interp::TclInterp, name::Name = callback_default_name()) =
    Callback(func, name, interp)

callback_default_name() = auto_name("jl_func_")

Base.propertynames(f::Callback) = (:func, :token, :interp, :name)
function Base.getproperty(f::Callback, key::Symbol)
    key === :func   ? getfield(f, :func) :
    key === :interp ? getfield(f, :interp) :
    key === :name   ? get_name(f) :
    key === :token  ? getfield(f, :token) :
    throw(KeyError(key))
end
@noinline function Base.setproperty!(f::Callback, key::Symbol, val)
    key ∈ propertynames(f) || throw(KeyError(key))
    error("attempt to set read-only field `$key`")
end

function get_name(f::Callback)
    GC.@preserve f begin
        objptr = Tcl_NewStringObj("", 0)
        Tcl_GetCommandFullName(f.interp, f.token, Tcl_IncrRefCount(objptr))
        name = unsafe_string(objptr)
        Tcl_DecrRefCount(objptr)
        return name
    end
end

Base.show(io::IO, ::MIME"text/plain", f::Callback) = show(io, f)
Base.show(io::IO, f::Callback) =
    print(io, "TclTk.Callback: `", nameof(f.func), "` (in Julia) => \"", f.name, "\" (in Tcl)")

const release_object_proc = Ref{Ptr{Cvoid}}() # set by __init__
const eval_command_proc = Ref{Ptr{Cvoid}}() # set by __init__

unsafe_release(ptr::Ptr{Cvoid}) = release(unsafe_pointer_to_objref(ptr))

# This method is the one called by the Tcl interpreter. According to Tcl doc., it is safe to
# use the interpreter when the command is evaluated.
function eval_command(fptr::ClientData, iptr::Ptr{Tcl_Interp},
                      objc::Cint, objv::Ptr{Ptr{Tcl_Obj}})
    try
        # Get the callback object and dispatch on it.
        return eval_command(unsafe_pointer_to_objref(fptr), iptr, objc, objv)::TclStatus
    catch ex
        Tcl_SetObjResult(iptr, new_object("(callback error) " * get_error_message(ex)))
        return TCL_ERROR
    end
end

# This method is to dispatch on the function type. Errors are catch by the caller.
function eval_command(f::Callback, iptr::Ptr{Tcl_Interp},
                      objc::Cint, objv::Ptr{Ptr{Tcl_Obj}})
    interp = f.interp
    pointer(interp) == iptr || error("callback called with wrong Tcl interpreter")
    args = _TclObj(new_list(interp, objc, objv))
    return set_command_result(interp, f.func(interp, args))
end

function set_command_result(interp::TclInterp, result::Any = nothing)
    isnothing(result) || setresult!(interp, result)
    return TCL_OK
end

function set_command_result(interp::TclInterp, status::TclStatus)
    return status
end

function set_command_result(interp::TclInterp, (status,result)::Tuple{TclStatus,Any})
    isnothing(result) || setresult!(interp, result)
    return status
end

"""
    TclTk.deletecommand(name, interp=TclInterp()) -> bool
    TclTk.deletecommand(interp, name) -> bool

Delete command named `name` in Tcl interpreter `interp` and return whether the command
existed before the call.

"""
deletecommand(name::Name, interp=TclInterp()) = deletecommand(interp, name)

function deletecommand(interp::TclInterp, name::Name)
    GC.@preserve interp name begin
        return iszero(Tcl_DeleteCommand(interp, name))
    end
end

"""
    TclTk.deletecommand(callback::TclTk.Callback) -> bool

Delete the Tcl command of `callback` from its interpreter and return whether the command
existed before the call.

# See also

[`TclTk.Callback`](@ref).

"""
function deletecommand(callback::Callback)
    # In principle, it is not necessary to preserve `callback` from being garbage collected
    # as it should be referenced by `preserved_objects`.
    GC.@preserve callback begin
        return iszero(Tcl_DeleteCommandFromToken(callback.interp, callback.token))
    end
end

# Dictionary of objects shared with Tcl to make sure they are not garbage collected until
# Tcl deletes their reference.
const preserved_objects = Dict{Any,Int}()

"""
    TclTk.Core.preserve(obj) -> obj

Increment the reference count on object `obj` to prevent that `obj` be garbage collected.

!!! warning
    Any call to `TclTk.Core.release(obj)` must match a previous call to
    [`TclTk.Core.preserve(obj)`](@ref).

"""
function preserve(obj)
    preserved_objects[obj] = get(preserved_objects, obj, 0) + 1
    return obj
end

"""
    TclTk.Core.release(obj)

Decrement the reference count of object `obj`. The resources associated with `obj` may be
garbage collected if it becomes no longer referenced.

!!! warning
    Any call to `TclTk.Core.release(obj)` must match a previous call to
    [`TclTk.Core.preserve(obj)`](@ref).

"""
function release(obj)
    nrefs = get(preserved_objects, obj, 0)
    if nrefs > 1
        preserved_objects[obj] = nrefs - 1
    elseif nrefs == 1
        pop!(preserved_objects, obj)
    else
        @warn "Attempt to release un-referenced object"
    end
    return nothing
end
