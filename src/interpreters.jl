#
# basics.jl -
#
# Implement interface to Tcl interpreter, evaluation of scripts, callbacks...
#

#---------------------------------------------------------- Management of Tcl interpreters -

"""
    interp = TclInterp()
    interp = TclInterp(:shared | :private)

Return a Tcl interpreter. If argument is `:shared` or unspecified, an interpreter shared by
all tasks running on the current thread is returned. If argument is `:private`, a new
private interpreter is created.

!!! warning
    A Tcl interpreter can only be used by the thread where it was created.

The resulting object can be used as a function to *execute* a Tcl command. For example:

```julia-repl
julia> interp(:set, :x, 42)
TclObj(42)
```

The result of the command is returned as a Tcl object storing the value `42`. See
[`TclTk.exec`](@ref) for more details about execution of Tcl commands.

To *evaluate* a Tcl script with the interpreter, call `interp.eval(args...)`. The above
example can also be done by:

```julia-repl
julia> interp.eval("set x 42")
TclObj("42")
```

whose result is a Tcl object storing the string `"42"`. See method [`TclTk.eval`](@ref) for
more details about script evaluation.

The `interp` object can also be indexed as an array to access global Tcl variables (the
variable name can be specified as a string or as a symbol):

```julia
interp["x"]          # yields value of variable "x"
interp[:tcl_version] # yields version of Tcl
interp[:x] = 33      # set the value of "x" and yields its value
```

The Tcl interpreter is initialized and will be deleted when no longer in use. If Tk has been
properly installed, then:

```julia
interp.eval("package require Tk")
```

should load Tk extension and create the "." toplevel Tk window. But see [`tk_start`](@ref)
method to load Tk.

"""
TclInterp(sym::Symbol) =
    sym === :shared ? TclInterp() :
    sym === :private ? _TclInterp() :
    argument_error("unexpected argument, shall be `:shared` or `:private`")

# Create a thread-wise shared interpreter.
function TclInterp()
    global _shared_interpreters
    threadid = Threads.threadid()
    if isassigned(_shared_interpreters, threadid)
        # A shared interpreter already exists for this thread, just return it.
        return @inbounds(_shared_interpreters[threadid])
    else
        # A new interpreter must be created. Call a separate (not in-lined) function so that
        # `TclInterp()` remains small and can be in-lined.
        return _new_shared_interpreter()
    end
end

# Private list of shared Tcl interpreters (one for each thread) created on demand.
const _shared_interpreters = TclInterp[]

@noinline function _new_shared_interpreter()
    global _shared_interpreters
    threadid = Threads.threadid()
    length(_shared_interpreters) < threadid && resize!(_shared_interpreters,
                                                       max(threadid, Threads.nthreads()))
    isassigned(_shared_interpreters, threadid) && assertion_error(
        "there is already a shared Tcl interpreter for this thread ($threadid)")
    interp = _TclInterp()
    _shared_interpreters[threadid] = interp
    return interp
end

# Create a new Tcl interpreter object.
function _TclInterp()
    interp = Tcl_CreateInterp()
    isnull(interp) && tcl_error("unable to create Tcl interpreter")
    try
        # Initialize Tcl interpreter to find Tcl library scripts.
        if isdefined(@__MODULE__, :Tcl_jll)
            tcl_library = joinpath(dirname(dirname(Tcl_jll.libtcl_path)), "lib",
                                   "tcl$(TCL_MAJOR_VERSION).$(TCL_MINOR_VERSION)")
            ptr = Tcl_SetVar(interp, "tcl_library", tcl_library, TCL_GLOBAL_ONLY|TCL_LEAVE_ERR_MSG)
            isnull(ptr) && @warn "Unable to set `tcl_library`: $(unsafe_result(String, interp))"
        end
        status = @ccall libtcl.Tcl_Init(interp::Ptr{Tcl_Interp})::TclStatus
        status == TCL_OK || @warn "Unable to initialize Tcl interpreter: $(unsafe_result(String, interp))"
    catch
        Tcl_DeleteInterp(interp)
        rethrow()
    end
    return _TclInterp(interp) # call inner constructor
end

# Make a Tcl interpreter callable.
(interp::TclInterp)(::Type{T}, args...; kwds...) where {T} =
    TclTk.exec(T, interp, args...; kwds...)
(interp::TclInterp)(args...; kwds...) = TclTk.exec(interp, args...; kwds...)

Base.show(io::IO, ::MIME"text/plain", interp::TclInterp) = show(io, interp)
function Base.show(io::IO, interp::TclInterp)
    print(io, "Tcl interpreter (address: ")
    show(io, UInt(pointer(interp)))
    print(io, ", threadid: ", interp.threadid, ")")
end

for f in (:isequal, :(==))
    @eval Base.$f(a::TclInterp, b::TclInterp) = $f(a.ptr, b.ptr)
end

#------------------------------------------------------------------ Interpreter properties -

Base.propertynames(interp::TclInterp) = (:concat, :eval, :exec, :fetch, :list, :ptr,
                                         :result, :threadid)

@inline Base.getproperty(interp::TclInterp, key::Symbol) = _getproperty(interp, Val(key))
_getproperty(interp::TclInterp, ::Val{:concat}) = PrefixedFunction(concat, interp)
_getproperty(interp::TclInterp, ::Val{:eval}) = PrefixedFunction(TclTk.eval, interp)
_getproperty(interp::TclInterp, ::Val{:exec}) = PrefixedFunction(exec, interp)
_getproperty(interp::TclInterp, ::Val{:fetch}) = SubCommand{:fetch}(interp)
_getproperty(interp::TclInterp, ::Val{:list}) = PrefixedFunction(list, interp)
_getproperty(interp::TclInterp, ::Val{:ptr}) = getfield(interp, :ptr)
_getproperty(interp::TclInterp, ::Val{:result}) = PrefixedFunction(getresult, interp)
_getproperty(interp::TclInterp, ::Val{:threadid}) = getfield(interp, :threadid)
_getproperty(interp::TclInterp, ::Val{key}) where {key} = throw(KeyError(key))

# Properties are read-only, only `finalize` (see below) may change their values.
@noinline function Base.setproperty!(interp::TclInterp, key::Symbol, val)
    key ∈ propertynames(interp) || throw(KeyError(key))
    error("attempt to set read-only field `$key` in Tcl interpreter")
end

function finalize(interp::TclInterp)
    if !same_thread(interp)
        @warn "`finalize` called by wrong thread for Tcl interpreter"
    else
        ptr = pointer(interp)
        if !isnull(ptr)
            setfield!(interp, :ptr, null(ptr)) # we do not want to free more than once
            setfield!(interp, :threadid, 0) # make this interpreter is no longer usable
            setfield!(interp, :tkstarted, false)
            Tcl_DeleteInterp(ptr)
            Tcl_Release(ptr)
        end
    end
    return nothing
end

#---------------------------------------------------------------------- Interpreter result -

"""
    interp[] -> obj::TclObj
    interp.result() -> obj::TclObj
    TclTk.getresult() -> obj::TclObj
    TclTk.getresult(interp) -> obj::TclObj

    interp.result(T) -> val::T
    TclTk.getresult(T) -> val::T
    TclTk.getresult(T, interp) -> val::T
    TclTk.getresult(interp, T) -> val::T

Retrieve the result of interpreter `interp` as a value of type `T` or as a Tacl object if
`T` is not specified. `TclTk.getresult` returns the result of the shared interpreter of the
thread.

# See also

[`TclInterp`](@ref) and [`TclObj`](@ref).

"""
getresult() = getresult(TclInterp())
getresult(::Type{T}) where {T} = getresult(T, TclInterp())
getresult(interp::TclInterp) = getresult(TclObj, interp)
getresult(interp::TclInterp, ::Type{T}) where {T} = getresult(T, interp)
function getresult(::Type{T}, interp::TclInterp) where {T}
    GC.@preserve interp begin
        return unsafe_result(T, interp)
    end
end

# Make `interp[]` yield result.
Base.getindex(interp::TclInterp) = getresult(TclObj, interp)
Base.getindex(interp::TclInterp, ::Type{T}) where {T} = getresult(T, interp)
function Base.setindex!(interp::TclInterp, val)
    setresult!(interp, val)
    return interp
end

"""
    TclTk.Impl.unsafe_result(T, interp) -> val

Return the result of Tcl interpreter `interp` as a value of type `T`.

The function is *unsafe*: interpreter must be valid (non-null pointer) and remain so during
the call to this function.

"""
function unsafe_result(::Type{String}, interp::Union{TclInterp,InterpPtr})
    return unsafe_string(Tcl_GetStringResult(interp))
end

function unsafe_result(::Type{T}, interp::Union{TclInterp,InterpPtr}) where {T}
    return unsafe_convert(T, Tcl_GetObjResult(interp))
end

#------------------------------------------------------------------------ Global variables -

# Manage to make any Tcl interpreter usable as an indexable collection with respect to its
# global variables.
function Base.haskey(interp::TclInterp, name::VarName)
    return exists(interp, name)
end

function Base.delete!(interp::TclInterp, name::VarName)
    unsetvar!(interp, name; nocomplain=true)
    return interp
end

function Base.getindex(interp::TclInterp, name::VarName)
    return getvar(interp, name)
end

function Base.getindex(interp::TclInterp, ::Type{T}, name::VarName) where {T}
    return getvar(T, interp, name)
end

function Base.setindex!(interp::TclInterp, value, name::VarName)
    setvar!(Nothing, interp, name, value)
    return interp
end

function Base.setindex!(interp::TclInterp, ::Unset, name::VarName)
    unsetvar!(interp, name; nocomplain=true)
    return interp
end

"""
    TclTk.setresult!(interp = TclInterp(), value) -> nothing

Set the result stored in Tcl interpreter `interp` with `value`.

If not specified, `interp` is the shared interpreter of the calling thread.

"""
setresult!(value) = setresult!(TclInterp(), value)

# To set Tcl interpreter result, we call `Tcl_SetObjResult` for any object, as
# `Tcl_SetResult` is a macro since Tcl 9.
function setresult!(interp::TclInterp, value)
    # We call `unsafe_objptr` to save creating a mutable `TclObj` structure to temporarily
    # wrap the new Tcl object if value is not a Tcl object.
    GC.@preserve interp value begin
        # `checked_pointer` may throw so it must be called before `unsafe_objptr` which may
        # create a new Tcl object for the value.
        interp_ptr = checked_pointer(interp)
        value_ptr = unsafe_objptr(value)
        # As can be seen in `generic/tclResult.c`, `Tcl_SetObjResult` does manage the
        # reference count of its object argument so it is OK to directly pass a
        # temporary object for the value.
        Tcl_SetObjResult(interp_ptr, value_ptr)
    end
    return nothing
end

"""
    TclTk.isdeleted(interp=TclInterp()) -> bool::Bool

Return whether Tcl interpreter `interp` has been deleted.

# See also

[`TclInterp`](@ref), [`TclTk.isactive`](@ref), and [`TclTk.issafe`](@ref).

"""
isdeleted(interp::TclInterp=TclInterp()) =
    isnull(pointer(interp)) || !iszero(Tcl_InterpDeleted(interp))

"""
    TclTk.isactive(interp=TclInterp()) -> bool::Bool

Return whether Tcl interpreter `interp` is active, i.e. is currently executing some script.

# See also

[`TclInterp`](@ref), [`TclTk.issafe`](@ref), and [`TclTk.isdeleted`](@ref).

"""
isactive(interp::TclInterp=TclInterp()) =
    !isnull(pointer(interp)) && !iszero(Tcl_InterpActive(interp))

"""
    TclTk.issafe(interp=TclInterp()) -> bool::Bool

Return whether Tcl interpreter `interp` is *safe*, i.e. is suitable for executing untrusted
code.

# See also

[`TclInterp`](@ref), [`TclTk.isactive`](@ref), and [`TclTk.isdeleted`](@ref).

"""
issafe(interp::TclInterp=TclInterp()) =
    !isnull(pointer(interp)) && !iszero(Tcl_IsSafe(interp))

#------------------------------------------------------------------- Evaluation of scripts -

"""
    TclTk.exec(T=Nothing, interp=TclInterp(), args...) -> res::T
    interp.exec(T=Nothing, args...) -> res::T
    interp(T=Nothing, args...) -> res::T

Make a list out of the arguments `args...`, evaluate this list as a Tcl command with
interpreter `interp`, and return a value of type `T`. Any `key => val` pair in `args...` is
converted in the pair of arguments `-key` and `val` in the command list (where the leading
hyphen before the key name is added if needed).

The evaluation of a Tcl command stores a result (or an error message) in the interpreter and
returns a status. The behavior of `TclTk.exec` depends on the type `T` of the expected
result:

* If `T` is `TclStatus`, the status of the evaluation is returned and the command result may
  be retrieved by calling [`TclTk.getresult`](@ref) or via `interp.result(...)`.

* If `T` is `Nothing`, an exception is thrown if the status is not [`TCL_OK`](@ref
  TclStatus) and `nothing` is returned otherwise (i.e., the result of the command is
  ignored).

* Otherwise, an exception is thrown if the status is not [`TCL_OK`](@ref TclStatus) and the
  result of the command is returned as a value of type `T` otherwise.

# See also

See [`TclTk.list`](@ref) for the rules to build a list (apart from the accounting of pairs).

See [`TclTk.eval`](@ref) for another way to evaluate a Tcl script. The difference with
[`TclTk.eval`](@ref) is that each input argument is interpreted as a different *token* of
the Tcl command and the accounting of `key => val` pairs.

"""
function exec(::Type{T}, interp::TclInterp, args...; kwds...) where {T}
    GC.@preserve interp begin
        interp_ptr = checked_pointer(interp)
        list_ptr = Tcl_IncrRefCount(new_list())
        status = try
            for arg in args
                unsafe_append_exec_arg(interp_ptr, list_ptr, arg)
            end
            for (key, val) in kwds
                unsafe_append_element(interp_ptr, list_ptr, with_hyphen(key))
                unsafe_append_element(interp_ptr, list_ptr, val)
            end
            Tcl_EvalObjEx(interp_ptr, list_ptr, TCL_EVAL_DIRECT | TCL_EVAL_GLOBAL)
        finally
            Tcl_DecrRefCount(list_ptr) # free list object
        catch
            rethrow()
        end
        return unsafe_eval_result(T, status, interp_ptr)
    end
end

# Provide optional leading arguments.
exec(args...; kwds...) = exec(TclInterp(), args...; kwds...)
exec(::Type{T}, args...; kwds...) where {T} = exec(T, TclInterp(), args...; kwds...)
exec(interp::TclInterp, args...; kwds...) = exec(Nothing, interp, args...; kwds...)

# Re-order leading arguments.
exec(interp::TclInterp, ::Type{T}, args...; kwds...) where {T} =
    exec(T, interp, args...; kwds...)

function unsafe_append_exec_arg(interp::InterpPtr, list::ObjPtr, arg)
    unsafe_append_element(interp, list, arg)
    return nothing
end

function unsafe_append_exec_arg(interp::InterpPtr, list::ObjPtr,
                                (key, val)::Pair{<:Word,<:Any})
    unsafe_append_element(interp, list, with_hyphen(key))
    unsafe_append_element(interp, list, val)
    return nothing
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
    TclTk.eval(T=Nothing, interp=TclInterp(), args...) -> res::T
    interp.eval(T=Nothing, args...) -> res::T

Concatenate arguments `args...` into a list, evaluate this list as a Tcl script with
interpreter `interp`, and return a value of type `T`.

The evaluation of a Tcl script stores a result (or an error message) in the interpreter and
returns a status. The behavior of `TclTk.eval` depend on the type `T` of the expected result:

* If `T` is `TclStatus`, the status of the evaluation is returned and the script result may
  be retrieved by calling [`TclTk.getresult`](@ref) or via `interp.result(...)`.

* If `T` is `Nothing`, an exception is thrown if the status is not [`TCL_OK`](@ref
  TclStatus) and `nothing` is returned otherwise (i.e., the result of the script is
  ignored).

* Otherwise, an exception is thrown if the status is not [`TCL_OK`](@ref TclStatus) and the
  result of the script is returned as a value of type `T` otherwise.

# See also

See [`TclTk.concat`](@ref) for the rules to concatenate arguments into a list (apart from the
accounting of pairs).

See [`TclTk.exec`](@ref) for another way to execute a Tcl command where each of `args...` is
considered as a distinct command argument.

"""
TclTk.eval

# Provide optional leading arguments.
TclTk.eval(args...) = TclTk.eval(TclInterp(), args...)
TclTk.eval(::Type{T}, args...) where {T} = TclTk.eval(T, TclInterp(), args...)
TclTk.eval(interp::TclInterp, args...) = TclTk.eval(Nothing, interp, args...)

# Re-order leading arguments.
TclTk.eval(interp::TclInterp, ::Type{T}, args...) where {T} = TclTk.eval(T, interp, args...)

# Evaluate script provided as a (symbolic) string.
function TclTk.eval(::Type{T}, interp::TclInterp, script::FastString) where {T}
    # For a script given as a string, `Tcl_EvalEx` is slightly faster than `Tcl_Eval` (says
    # the doc.) and, more importantly, the script may contain embedded nulls.
    GC.@preserve interp script begin
        interp_ptr = checked_pointer(interp)
        status = Tcl_EvalEx(interp_ptr, script, sizeof(script),
                            TCL_EVAL_DIRECT | TCL_EVAL_GLOBAL)
        return unsafe_eval_result(T, status, interp_ptr)
    end
end
function TclTk.eval(::Type{T}, interp::TclInterp, script::AbstractString) where {T}
    return TclTk.eval(T, interp, string(script))
end

# Evaluate script provided as a Tcl object.
function TclTk.eval(::Type{T}, interp::TclInterp, script::TclObj) where {T}
    GC.@preserve interp script begin
        interp_ptr = checked_pointer(interp)
        status = Tcl_EvalObjEx(interp_ptr, script,
                               TCL_EVAL_DIRECT | TCL_EVAL_GLOBAL)
        return unsafe_eval_result(T, status, interp_ptr)
    end
end

# Evaluate script provided as more than one arguments. Concatenate arguments in a Tcl list
# object. Then, call `Tcl_EvalObjEx` which do manage the reference count of its object
# argument.
function TclTk.eval(::Type{T}, interp::TclInterp, args...) where {T}
    GC.@preserve interp begin
        interp_ptr = checked_pointer(interp)
        list_ptr = unsafe_new_list(unsafe_append_eval_arg, interp_ptr, args...)
        status = Tcl_EvalObjEx(interp_ptr, Tcl_IncrRefCount(list_ptr),
                               TCL_EVAL_DIRECT | TCL_EVAL_GLOBAL)
        Tcl_DecrRefCount(list_ptr)
        return unsafe_eval_result(T, status, interp_ptr)
    end
end

function unsafe_append_eval_arg(interp::InterpPtr, list::ObjPtr, arg)
    unsafe_append_list(interp, list, arg)
    return nothing
end

# `unsafe_eval_result(T, status, interp)` yields the value of type `T` returned by
# `TclTk.exec` or `TclTk.eval` or throws depending on `T` and of the `status` of the script
# or command evaluated by `interp`.
function unsafe_eval_result(::Type{TclStatus}, status::TclStatus, interp::InterpPtr)
    return status
end

function unsafe_eval_result(::Type{Nothing}, status::TclStatus, interp::InterpPtr)
    status == TCL_OK && return nothing
    status == TCL_ERROR && unsafe_error(interp)
    throw_unexpected(status)
end

function unsafe_eval_result(::Type{T}, status::TclStatus, interp::InterpPtr) where {T}
    status == TCL_OK && return unsafe_result(T, interp)
    status == TCL_ERROR && unsafe_error(interp)
    throw_unexpected(status)
end

@noinline throw_unexpected(status::TclStatus) =
    tcl_error("unexpected return status: $status")

#----------------------------------------------------------------------- Fetching value(s) -

"""
    fetch(T, obj::TclObj) -> x::T
    fetch(T, obj::TclObj, i::Integer) -> x::T
    fetch(T, obj::TclObj, inds::AbstractVector{<:Integer}) -> x::T

Return a Julia value of type `T` from Tcl object `obj`. With no other argument than `T` and
`obj`, this is exactly the same as calling `convert(T, x)`. If an index `i` is specified,
convert the `i`-th element of `obj` considered as a list. If a vector of indices (e.g. an
index range) `inds` is specified, convert the sub-list `obj[inds]`.

Compared to `convert(T, obj[i])`, or `convert(T, obj[inds])`, calling `fetch` avoids
temporaries and is thus a bit faster.

Examples:

```julia-repl
julia> x = TclObj((false, -7, 1.5, "text", ('a', 2)))
TclObj((0, -7, 1.5, "text", ("a", 2,),))

julia> fetch(Bool, x, 1)
false

julia> convert(Tuple{Char,Int}, x[5])
('a', 2)

julia> fetch(Tuple{Char,Int}, x, 5) # same as above but a bit faster and allocation free
('a', 2)

julia> fetch(Tuple{String,Float64,Tuple{Char,Int}}, x, (4,3,5))
("text", 1.5, ('a', 2))

julia> fetch(Tuple{Bool,Int16,Float32,Symbol}, x, 1:4)
(false, -7, 1.5f0, :text)

```

# See also

[`TclTk.Callback`](@ref).

"""
function Base.fetch(::Type{T}, obj::TclObj) where {T}
    # For simple types, it is sufficient to call `convert`.
    return convert(T, obj)::T
end

function Base.fetch(::Type{T}, obj::TclObj, ::Colon) where {T<:Tuple}
    # To fetch a tuple, the object must be considered as a list.
    GC.@preserve obj begin
        return unsafe_convert(T, pointer(obj))::T
    end
end

function Base.fetch(::Type{T}, obj::TclObj, i::Integer) where {T}
    # First fetch i-th element of the list to check for bounds error, then fetch a value of
    # type T out of the item.
    GC.@preserve obj begin
        itemptr = unsafe_getindex(obj, i)
        isnull(itemptr) && throw(BoundsError(obj, i))
        return unsafe_convert(T, itemptr)::T
    end
end

@generated function Base.fetch(::Type{T}, obj::TclObj,
                               inds::Union{AbstractVector{<:Integer},
                                           Tuple{Vararg{Integer}}}) where {N,T<:NTuple{N,Any}}
    # To fetch with indices, the object must be considered as a list.
    types = fieldtypes(T)
    expr = Expr(:tuple, [:(unsafe_convert($(types[i]), list[inds[off + $i]]))
                         for i in 1:N]...,)
    quote
        length(inds) == N || argument_error(
            "cannot fetch a $N-tuple from a $(length(inds))-element Tcl sub-list")
        GC.@preserve obj begin
            list = UnsafeList(pointer(obj))
            off = firstindex(inds)::Int - 1
            return ($expr)::T
        end
    end
end

"""
    fetch(T, interp::TclInterp, obj::TclObj) -> x::T
    fetch(T, interp::TclInterp, obj::TclObj, i::Integer) -> x::T
    fetch(T, interp::TclInterp, obj::TclObj, inds::AbstractVector{<:Integer}) -> x::T

    interp.fetch(T, obj::TclObj) -> x::T
    interp.fetch(T, obj::TclObj, i::Integer) -> x::T
    interp.fetch(T, obj::TclObj, inds::AbstractVector{<:Integer}) -> x::T

Return a Julia value of type `T` from Tcl object `obj` living in Tcl interpreter `interp`.
If an index `i` is specified, convert the `i`-th element of `obj` considered as a list. If a
vector of indices (e.g. an index range) `inds` is specified, convert the sub-list
`obj[inds]`.

Compared to `convert(T, obj)`, `convert(T, obj[i])`, or `convert(T, obj[inds])`, calling
`fetch` is more general as `T` can be the type of an object (such as a widget or an image)
that lives in an interpreter and a bit faster as `fetch` avoids temporaries.

For example, if `interp` and `args` are the arguments received by a callback bound to an
event with `"%W %x %y"`, then:

```julia
w = interp.fetch(Canvas, args, 2)
x = interp.fetch(Int,    args, 3)
y = interp.fetch(Int,    args, 4)
```

retrieves the 2nd, 3rd, and 4th elements of `args` set with the calling widget (here a
canvas) and the pointer position (for a callback, the 1st element of `args` is the name of
the associated Tcl command). This can also be done in a single statement by:

```julia
w, x, y = interp.fetch(Tuple{Canvas,Int,Int}, args, 2:4)
```

# See also

[`TclTk.Callback`](@ref).

"""
function Base.fetch(::Type{T}, interp::TclInterp, obj::TclObj) where {T}
    # For simple types, it is sufficient to call `convert`.
    return convert(T, obj)::T
end

function Base.fetch(::Type{T}, interp::TclInterp, obj::TclObj) where {T<:TkObject}
    # Tk objects can be directly build from the arguments.
    return T(interp, obj)::T
end

function Base.fetch(::Type{T}, interp::TclInterp, obj::TclObj, ::Colon=:) where {T<:Tuple}
    # To fetch a tuple, the object must be considered as a list.
    GC.@preserve interp obj begin
        return unsafe_fetch(T, interp, pointer(obj))::T
    end
end

function Base.fetch(::Type{T}, interp::TclInterp, obj::TclObj, i::Integer) where {T}
    # First fetch i-th element of the list to check for bounds error, then fetch a value of
    # type T out of the item.
    GC.@preserve interp obj begin
        itemptr = unsafe_getindex(obj, i)
        isnull(itemptr) && throw(BoundsError(obj, i))
        return unsafe_fetch(T, interp, itemptr)::T
    end
end

@generated function Base.fetch(::Type{T}, interp::TclInterp, obj::TclObj,
                               inds::Union{AbstractVector{<:Integer},
                                           Tuple{Vararg{Integer}}}) where {N,T<:NTuple{N,Any}}
    # To fetch with indices, the object must be considered as a list.
    types = fieldtypes(T)
    expr = Expr(:tuple, [:(unsafe_fetch($(types[i]), interp, list[inds[off + $i]]))
                         for i in 1:N]...,)
    quote
        length(inds) == N || argument_error(
            "cannot fetch a $N-tuple from a $(length(inds))-element Tcl sub-list")
        GC.@preserve interp obj begin
            list = UnsafeList(pointer(obj))
            off = firstindex(inds)::Int - 1
            return ($expr)::T
        end
    end
end

# Make `fetch` a sub-command of the interpreter.
function (f::SubCommand{:fetch,TclInterp})(::Type{T}, obj::TclObj) where {T}
    return fetch(T, f.caller, obj)
end
function (f::SubCommand{:fetch,TclInterp})(::Type{T}, obj::TclObj,
                                           inds::Union{Colon, Integer,
                                                       AbstractVector{<:Integer},
                                                       Tuple{Vararg{Integer}}}) where {T}
    return fetch(T, f.caller, obj, inds)
end

# Tk objects require the interpreter where they live.
function unsafe_fetch(::Type{T}, interp::TclInterp, objptr::ObjPtr) where {T<:TkObject}
    return T(interp, _TclObj(objptr))
end

# Default is to call `unsafe_convert`.
function unsafe_fetch(::Type{T}, interp::TclInterp, objptr::ObjPtr) where {T}
    return unsafe_convert(T, objptr)
end

# Convert to fully specified Tuple.
@generated function unsafe_fetch(::Type{T}, interp::TclInterp,
                                 objptr::ObjPtr) where {N,T<:NTuple{N,Any}}
    types = fieldtypes(T)
    expr = Expr(:tuple, [:(unsafe_fetch($(types[i]), interp, list[$i])) for i in 1:N]...,)
    quote
        list = UnsafeList(objptr)
        length(list) == N || argument_error(
            "cannot fetch a $N-tuple from a $(length(list))-element Tcl list")
        return $expr
    end
end
