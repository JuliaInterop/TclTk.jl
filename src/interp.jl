#------------------------------------------------------------------------------ Tcl events -
#
# Processing of Tcl events must be done repeatedly but can be done from any thread.

# Timer in charge of repeatedly processing Tcl events.
const event_timer = Ref{Timer}()

# Callback repeatedly called by the timer. Can be run from any thread.
function process_events(::Timer)
    flags = TCL_DONT_WAIT|TCL_ALL_EVENTS
    while !iszero(@ccall libtcl.Tcl_DoOneEvent(flags::Cint)::Cint)
        nothing
    end
end

function resume_events(delay::Real=0.1, interval::Real=0.05)
    if !isdefined(event_timer, 1) || !isopen(event_timer[])
        event_timer[] = Timer(process_events, delay; interval=interval)
    end
    return nothing
end

function suspend_events()
    if isdefined(event_timer, 1) && isopen(event_timer[])
        close(event_timer[])
    end
    return nothing
end

#------------------------------------------------------------------------- Tcl interpreter -
#
# Tcl requires that an interpreter be called from the same thread where it was created
# (otherwise the program is aborted). This is achieved by having a task in charge of calling
# all functions of the Tcl library that use an interpreter.

const interpreter_queue = Channel{Any}(10)
const interpreter_task = Ref{Task}() # task in charge of processing Tcl calls with an interpreter
const current_interpreter = Ref{Ptr{Tcl_Interp}}(0) # Tcl interpreter
const interpreter_lock = ReentrantLock() # to protect shared data between tasks
const interpreter_ready = Ref{Bool}(false)

"""
    result = TclTk.Impl.with_interpreter(f)

Manage to call function `f` as `f(interp)` in the thread were lives `interp`, the shared Tcl
interpreter of the application. The returned value is that returned by `f` (except that if
an exception is returned, this exception is thrown). The following do-block syntax is
another way to execute code involving the Tcl interpreter:

    result = TclTk.Impl.with_interpreter() do interp
        ...
    end

"""
function with_interpreter(f::Function)
    # Make sure a Tcl interpreter has been launched.
    lock(interpreter_lock)
    try
        interpreter_ready[] || launch_interpreter()
    finally
        unlock(interpreter_lock)
    end
    if current_task() === interpreter_task[]
        # We are in the same thread as the Tcl interpreter, directly evaluate the function.
        # (The overhead of having another task evaluate the Tcl code is about 1μs.)
        result = f(current_interpreter[])
    else
        result_channel = task_result_channel()
        put!(interpreter_queue, (f, result_channel))
        result = take!(result_channel)
    end
    if result isa Exception
        throw(result)
    end
    return result
end

# Return private channel for the result of a call to `with_interpreter`. This is needed to
# avoid different tasks mixing their results.
function task_result_channel()::Channel{Any}
    # NOTE Having per-task allocated channels saves ~ 8 allocations per call although it is
    #      not much faster than directly calling the channel constructor (7ns versus 34ns).
    key = :tcl_result_channel
    tls = task_local_storage()
    chn = get(tls, key, nothing)
    if chn isa Channel{Any}
        return chn
    elseif chn isa Nothing
        chn = Channel{Any}(1)
        tls[key] = chn
        return chn
    else
        throw(AssertionError("unexpected task local storage for key `$key`, expecting an instance of `Channel{Any}`, got `$(typeof(chn))`"))
    end
end

function shutdown_interpreter()
    lock(interpreter_lock)
    try
        # Instruct interpreter task to exit.
        interpreter_ready[] = false
    finally
        unlock(interpreter_lock)
    end
    if isassigned(interpreter_task) && !istaskdone(interpreter_task[])
        wait(interpreter_task[]; throw=false)
    end
end

# Launch a new Tcl interpreter. This function shall only be called by a task who owns
# `interpreter_lock` and if `interpreter_ready[]` is false. Only the latter assertion is
# verified. This function may throw; otherwise, `interpreter_task[]` is defined after return
# of this function.
@noinline function launch_interpreter()
    # Sanity check.
    interpreter_ready[] && throw(AssertionError("a Tcl interpreter already exists"))

    # Create a Tcl interpreter.
    interp = @ccall libtcl.Tcl_CreateInterp()::Ptr{Tcl_Interp}
    isnull(interp) && tcl_error("unable to create Tcl interpreter")
    try
        # Initialize Tcl interpreter to find Tcl library scripts.
        tcl_library = joinpath(dirname(dirname(Tcl_jll.libtcl_path)), "lib",
                               "tcl$(TCL_MAJOR_VERSION).$(TCL_MINOR_VERSION)")
        ptr = Tcl_SetVar(interp, "tcl_library", tcl_library,
                         TCL_GLOBAL_ONLY|TCL_LEAVE_ERR_MSG)
        isnull(ptr) && tcl_error("unable to set `tcl_library`: ",
                                 unsafe_get_result(String, interp))
        status = @ccall libtcl.Tcl_Init(interp::Ptr{Tcl_Interp})::TclStatus
        status == TCL_OK || tcl_error("unable to initialize Tcl interpreter: ",
                                      unsafe_get_result(String, interp))

        # Initialize Tcl interpreter to find Tk library scripts.
        tk_library = joinpath(dirname(dirname(Tk_jll.libtk_path)), "lib",
                              "tk$(TCL_MAJOR_VERSION).$(TCL_MINOR_VERSION)")
        ptr = Tcl_SetVar(interp, "tk_library", tk_library,
                         TCL_GLOBAL_ONLY|TCL_LEAVE_ERR_MSG)
        isnull(ptr) && tcl_error("unable to set `tk_library`: ",
                                 unsafe_get_result(String, interp))
        # Load Tk and Ttk packages. It is not needed to explicitly load these packages, it
        # is sufficient to call `Tk_Init`.
        status = @ccall libtk.Tk_Init(interp::Ptr{Tcl_Interp})::TclStatus
        status == TCL_OK || tcl_error("unable to initialize Tk interpreter: ",
                                      unsafe_get_result(String, interp))
        # Load Tcl-side helpers for working with Julia interface.
        srcdir = @__DIR__
        path = joinpath(srcdir, "julia.tcl")
        code = replace(read(path, String), "@SRCDIR@" => tcl_quote_string(srcdir))
        status = Tcl_Eval(interp, code)
        isnull(ptr) && tcl_error("unable to load Tcl script in \"$path\": ",
                                 unsafe_get_result(String, interp))

        # Store interpreter in global variable.
        Tcl_Preserve(interp)
        current_interpreter[] = interp
    catch
        Tcl_DeleteInterp(interp)
        rethrow()
    end

    # Create a task to call Tcl functions in a given thread where lives the interpreter. The
    # task itself creates the interpreter?
    task = Task(process_calls)
    task.sticky = true # this task must not migrate to another thread
    schedule(task)
    interpreter_task[] = task
    interpreter_ready[] = true

    # Start processing events.
    resume_events()
    return nothing
end

# Callback called to evaluate a Tcl call requiring an interpreter. Must only be executed in
# the same thread as the interpreter. To terminate the task, it is sufficient to set
# `interpreter_ready[]` to `false` under the control of `interpreter_lock[]`.
function process_calls()
    while interpreter_ready[]
        # Type assertion below reduces allocations.
        f, chn = take!(interpreter_queue)::Tuple{Function,Channel{Any}}
        try
            put!(chn, f(current_interpreter[]))
        catch ex
            put!(chn, ex)
        end
    end
    interp = current_interpreter[]
    if !isnull(interp)
        current_interpreter[] = C_NULL
        Tcl_DeleteInterp(interp)
        Tcl_Release(interp)
    end
    return nothing
end

"""
    TclTk.Impl.unsafe_get_result(T, interp) -> val

Return the result of Tcl interpreter `interp` as a value of type `T`.

This function must only be called from the thread where lives the interpreter and the
interpreter must be valid and remain so during the call to this function.

"""
function unsafe_get_result(::Type{T}, interp::InterpPtr) where {T}
    return unsafe_convert(T, Tcl_GetObjResult(interp))
end

"""
    TclTk.Impl.unsafe_set_result(interp, value)

Set the result of Tcl interpreter `interp` to be `value`. If `value` is `nothing`, reset
interpreter's result.

This function must only be called from the thread where lives the interpreter and the
interpreter and the value must be valid and remain so during the call to this function.

"""
function unsafe_set_result(interp::InterpPtr, value)
    # As can be seen in `generic/tclResult.c`, `Tcl_SetObjResult` does manage the reference
    # count of its object argument so it is OK to directly pass a temporary object for the
    # value.
    GC.@preserve value unsafe_set_result(interp, new_object(value))
end
function unsafe_set_result(interp::InterpPtr, obj::ObjPtr)
    @ccall libtcl.Tcl_SetObjResult(interp::Ptr{Tcl_Interp}, obj::Ptr{Tcl_Obj})::Cvoid
end
function unsafe_set_result(interp::InterpPtr, ::Nothing)
    @ccall libtcl.Tcl_ResetResult(interp::Ptr{Tcl_Interp})::Cvoid
end
#------------------------------------------------------- Evaluation of scripts or commands -

const default_eval_flags = TCL_EVAL_DIRECT | TCL_EVAL_GLOBAL

"""
    tcl_exec(T=Nothing, args...) -> res::T

Make a list out of the arguments `args...`, evaluate this list as a Tcl command, and return
a value of type `T`. Any `key => val` pair in `args...` and keywords in `kwds...` is
converted in the pair of arguments `-key` and `val` in the command list (where the leading
hyphen before the key name is added if needed).

The evaluation of a Tcl command stores a result (or an error message) in the Tcl interpreter
and returns a status. The behavior of `tcl_exec` depends on the type `T` of the expected
result:

* If `T` is `Tuple{TclStatus,R}`, the status and the result of the Tcl command are returned
  as a 2-tuple and with the result converted to type `R`. In practice, `R` is one of
  `TclObj`, `String`, or `Nothing`. No conversion of the result is attempted if `R` is
  `Nothing` which is useful when the caller is only interested in the status.

* Otherwise, if the command status is [`TCL_OK`](@ref TclStatus), the result of the command
  is returned as a value of type `T`. No conversion of the result is attempted if `T` is
  `Nothing`.

* Otherwise, if the command status is not [`TCL_OK`](@ref TclStatus), a [`TclError`](@ref)
  exception is thrown.


# Examples

With `tcl_exec`, storing a value in a global variable can be done by:

```julia-repl
julia> tcl_exec(TclObj, :set, :x, 42)
TclObj(42)
```

whose result is a Tcl object storing the integer `42`.


# See also

See [`tcl_list`](@ref) for the rules to build a list (apart from the accounting of pairs).

See [`tcl_eval`](@ref) for another way to evaluate a Tcl script. The difference with
[`tcl_eval`](@ref) is that each input argument is interpreted as a different *token* of
the Tcl command and the accounting of `key => val` pairs.

"""
tcl_exec(args...; kwds...) = tcl_exec(Nothing, args...; kwds...)
function tcl_exec(::Type{T}, args...; kwds...) where {T}
    # Make a list out of the arguments like in `tcl_list` except that creating an instance
    # of `TclObj` is avoided and pairs are treated differently.
    list = new_list()
    try
        for arg in args
            unsafe_append_tcl_exec_arg(list, arg)
        end
        for kwd in kwds
            unsafe_append_tcl_exec_arg(list, kwd)
        end
        return unsafe_tcl_eval(T, Tcl_IncrRefCount(list))
    finally
        Tcl_DecrRefCount(list) # free the list
    end
end

unsafe_append_tcl_exec_arg(list::ObjPtr, arg) = unsafe_append_element(list, arg)
function unsafe_append_tcl_exec_arg(list::ObjPtr, (key, val)::Pair{<:Word,<:Any})
    unsafe_append_element(list, with_hyphen(key))
    unsafe_append_element(list, val)
end

with_hyphen(s::Word) = with_hyphen(String(s)::String)
with_hyphen(s::String) = (startswith(s, '-') ? s : "-"*s)::String

without_hyphen(s::Word) = without_hyphen(String(s)::String)
function without_hyphen(s::AbstractString)
    start, stop = firstindex(s), lastindex(s)
    return (start > stop || s[start] != '-') ? string(s) :
        string(SubString(s, nextind(s, start), stop))
end

"""
    tcl_eval(T=Nothing, args...) -> res::T

Concatenate arguments `args...` into a list, evaluate this list as a Tcl script, and return
a value of type `T`.

Except for the specific handling of `args...`, the returned result follows the same behavior
as [`tcl_exec`](@ref).


# Examples

With `tcl_eval`, storing a value in a global variable can be done by:

```julia-repl
julia> tcl_eval(TclObj, "set x 42")
TclObj("42")
```

whose result is a Tcl object storing the string `"42"`.


# See also

See [`tcl_concat`](@ref) for the rules to concatenate arguments into a list (apart from the
accounting of pairs).

See [`tcl_exec`](@ref) for another way to execute a Tcl command where each of `args...` is
considered as a distinct command argument.

"""
tcl_eval(args...) = tcl_eval(Nothing, args...)
function tcl_eval(::Type{T}, args...) where {T}
    # Build a list out of the arguments like in `tcl_concat` except that creating an
    # instance of `TclObj` is avoided.
    list = new_list()
    try
        for arg in args
            unsafe_append_list(list, arg)
        end
        return unsafe_tcl_eval(T, Tcl_IncrRefCount(list))
    finally
        Tcl_DecrRefCount(list) # free the list
    end
end

function unsafe_tcl_eval(::Type{T}, obj::ObjPtr,
                         flags::Integer = default_eval_flags) where {T}
    status, result = with_interpreter() do interp
        status = Tcl_EvalObjEx(interp, obj, flags)
        result = Tcl_IncrRefCount(Tcl_GetObjResult(interp))
        return status, result
    end
    try
        return unsafe_eval_result(T, status, result)
    finally
        Tcl_DecrRefCount(result)
    end
end

"""
    tcl_eval(T=Nothing, script::AbstractString) -> res::T

Evaluate a Tcl `script` provided as a string. It returns the same result as
[`tcl_eval`](@ref).

"""
function tcl_eval(::Type{T}, script::AbstractString) where {T}
    status, result = GC.@preserve script begin
        with_interpreter() do interp
            status = Tcl_Eval(interp, script)
            result = Tcl_IncrRefCount(Tcl_GetObjResult(interp))
            return status, result
        end
    end
    try
        return unsafe_eval_result(T, status, result)
    finally
        Tcl_DecrRefCount(result)
    end
end

"""
    tcl_evalfile(T=Nothing, filename) -> res::T

Read the file given by `filename` and evaluate its contents as a Tcl script. The same result
as [`tcl_eval`](@ref) is returned.

"""
tcl_evalfile(filename::AbstractString) = tcl_evalfile(Nothing, filename)
function tcl_evalfile(::Type{T}, filename::AbstractString) where {T}
    status, result = GC.@preserve filename begin
        with_interpreter() do interp
            status = Tcl_EvalFile(interp, filename)
            result = Tcl_IncrRefCount(Tcl_GetObjResult(interp))
            return status, result
        end
    end
    try
        return unsafe_eval_result(T, status, result)
    finally
        Tcl_DecrRefCount(result)
    end
end

function unsafe_eval_result(::Type{Tuple{TclStatus,T}},
                            status::TclStatus, result::ObjPtr) where {T}
    if T === Nothing
        return status, nothing
    else
        return status, unsafe_convert(T, result)::T
    end
end

function unsafe_eval_result(::Type{T},
                            status::TclStatus, result::ObjPtr) where {T}
    if status == TCL_OK
        if T === Nothing
            return nothing
        else
            return unsafe_convert(T, result)::T
        end
    elseif status == TCL_ERROR
        mesg = unsafe_string(result)
        throw(TclError(mesg))
    else
        throw_unexpected(status)
    end
end

@noinline throw_unexpected(status::TclStatus) =
    tcl_error("unexpected return status: $status")
