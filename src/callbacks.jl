# TODO Reinstall callbacks when Tcl is re-started?

"""
    callback = TclCallback(f, name=TclTk.auto_name("jl_func_"))

Create a command implemented by the function `f` in the shared Tcl interpreter. The command
is initially named `name` (`callback.name` gives the actual command name even though the
command is renamed).

The Tcl command will call the Julia function `f` as:

```julia
f(args::TclObj)
```

where `args` is a Tcl list object with the arguments of the command. The first element of
`args` is the name of the command in the interpreter.

The method `f(args)` may return up to two values (both optional):

* A `status` of type [`TclStatus`](@ref) (one of `TCL_OK`, `TCL_ERROR`, `TCL_RETURN`,
  `TCL_BREAK` or `TCL_CONTINUE`) to specify the issue of the callback. If omitted, `TCL_OK`
  is assumed for `status`.

* A `result` to be stored in the interpreter's result. If `result` is omitted or `nothing`,
  the interpreter's result is left unchanged (i.e., empty).

If `status` and `result` are both returned by the callback, `status` must be first and
`result` second.

If the method `f(args)` throws any exception, the error message associated with the
exception is stored in the interpreter's result and `TCL_ERROR` is returned by the
interpreter.

# See also

[`TclTk.deletecommand`](@ref), [`TclTk.auto_name`](@ref), and [`TclStatus`](@ref).

"""
function TclCallback(func::Function, name::Name = callback_default_name())
    callback = preserve(TclCallback{typeof(func)}(C_NULL, func))
    try
        # Getting interpreter pointer or C string from `name` may throw, so we use a `try
        # ... catch` block.
        evalproc = eval_command_proc[]
        clientdata = pointer_from_objref(callback)
        deleteproc = release_object_proc[]
        token = with_interpreter() do interp
            token = @ccall libtcl.Tcl_CreateObjCommand(
                interp::Ptr{Tcl_Interp}, name::Cstring, evalproc::Ptr{Tcl_ObjCmdProc},
                clientdata::ClientData, deleteproc::Ptr{Tcl_CmdDeleteProc})::Tcl_Command
            isnull(token) && tcl_error(unsafe_get_result(String, interp))
            return token
        end::Tcl_Command
        setfield!(callback, :token, token)
    catch
        release(callback)
        rethrow()
    end
    return callback
end

callback_default_name() = auto_name("jl_func_")

Base.propertynames(f::TclCallback) = (:func, :token, :name)
function Base.getproperty(f::TclCallback, key::Symbol)
    key === :func   ? getfield(f, :func) :
    key === :name   ? get_name(f) :
    key === :token  ? getfield(f, :token) :
    throw(KeyError(key))
end
@noinline function Base.setproperty!(f::TclCallback, key::Symbol, val)
    key ∈ propertynames(f) || throw(KeyError(key))
    error("attempt to set read-only field `$key`")
end

function get_name(f::TclCallback)
    GC.@preserve f begin
        objptr = Tcl_IncrRefCount(unsafe_objptr(f))
        name = unsafe_string(objptr)
        Tcl_DecrRefCount(objptr)
        return name
    end
end

function unsafe_objptr(f::TclCallback)
    objptr = Tcl_NewStringObj("", 0)
    try
        GC.@preserve f begin # FIXME this should also be done in all unsafe_objptr?
            token = f.token
            with_interpreter() do interp
                @ccall libtcl.Tcl_GetCommandFullName(interp::Ptr{Tcl_Interp},
                                                     token::Tcl_Command,
                                                     objptr::Ptr{Tcl_Obj})::Cvoid
            end
        end
    catch ex
        Tcl_DecrRefCount(objptr) # release object
        throw(ex)
    end
    return objptr
end

Base.show(io::IO, ::MIME"text/plain", f::TclCallback) = show(io, f)
Base.show(io::IO, f::TclCallback) =
    print(io, "TclCallback: `", nameof(f.func), "` (in Julia) => \"", f.name, "\" (in Tcl)")

const release_object_proc = Ref(C_NULL) # set by __init__
const eval_command_proc = Ref(C_NULL) # set by __init__

unsafe_release(ptr::Ptr{Cvoid}) = release(unsafe_pointer_to_objref(ptr))

# This method is the one called by the Tcl interpreter. According to Tcl doc., it is safe to
# use the interpreter when the command is evaluated. This method shall only be called from
# the Tcl interpreter task.
function eval_command(data::ClientData, interp::Ptr{Tcl_Interp},
                      objc::Cint, objv::Ptr{Ptr{Tcl_Obj}})
    try
        # Get the callback object and dispatch on it.
        return eval_command(unsafe_pointer_to_objref(data), interp, objc, objv)::TclStatus
    catch ex
        unsafe_set_result(interp, "(callback error) " * get_error_message(ex))
        return TCL_ERROR
    end
end

# This method is to dispatch on the function type. Errors are caught by the caller.
function eval_command(f::TclCallback, interp::Ptr{Tcl_Interp},
                      objc::Cint, objv::Ptr{Ptr{Tcl_Obj}})
    args = _TclObj(new_list(objc, objv))
    return set_command_result(interp, f.func(args))
end

function set_command_result(interp::InterpPtr, result::Any = nothing)
    unsafe_set_result(interp, result)
    return TCL_OK
end

function set_command_result(interp::InterpPtr, status::TclStatus)
    return status
end

function set_command_result(interp::InterpPtr, (status,result)::Tuple{TclStatus,Any})
    isnothing(result) || unsafe_set_result(interp, result)
    return status
end

"""
    TclTk.deletecommand(name) -> bool::Bool

Delete command named `name` in shared Tcl interpreter and return whether the command existed
before the call.

"""
function deletecommand(name::Name)
    GC.@preserve name begin
        result = with_interpreter() do interp
            @ccall libtcl.Tcl_DeleteCommand(interp::Ptr{Tcl_Interp}, name::Cstring)::Cint
        end::Cint
        return iszero(result)::Bool
    end
end

"""
    TclTk.deletecommand(callback::TclCallback) -> bool::Bool

Delete the Tcl command of `callback` from its interpreter and return whether the command
existed before the call.

# See also

[`TclCallback`](@ref).

"""
function deletecommand(callback::TclCallback)
    # In principle, it is not necessary to preserve `callback` from being garbage collected
    # as it should be referenced by `preserved_objects`.
    GC.@preserve callback begin
        token = callback.token
        result = with_interpreter() do interp
            @ccall libtcl.Tcl_DeleteCommandFromToken(interp::Ptr{Tcl_Interp},
                                                     token::Tcl_Command)::Cint
        end::Cint
        return iszero(result)::Bool
    end
end

# Dictionary of objects shared with Tcl to make sure they are not garbage collected until
# Tcl deletes their reference.
const preserved_objects = Dict{Any,Int}()

"""
    TclTk.Core.preserve(obj) -> obj

Store a global reference on object `obj` to prevent that `obj` be garbage collected. The
number of calls to `TclTk.Core.preserve(obj)` is counted and the object is eventually
released when as many calls to [`TclTk.Core.release(obj)`](@ref) are made.

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
