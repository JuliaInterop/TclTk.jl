# Tcl interpreters

## Managing interpreters

Tcl scripts and commands are executed by a Tcl *interpreter* which is an instance of
[`TclInterp`](@ref) in `TclTk`. An application may have multiple Tcl interpreters but a
given interpreter must only be used in the thread where the interpreter was created
otherwise Tcl would *panic* (thus aborting the program). To prevent this, `TclTk` throws an
exception if such an attempt is made. Furthermore, `TclTk` maintains a cached list of
so-called *shared* interpreters, one for each thread, to used as the default interpreter for
a given tread. These shared interpreter are only created when needed. The shared interpreter
of the calling thread can be retrieved by calling the [`TclInterp`](@ref) constructor with
no argument of with the symbol `:shared`:

```julia-repl
julia> interp = TclInterp()
Tcl interpreter (address: 0x000000002274e130, threadid: 1)

julia> interp = TclInterp(:shared)
Tcl interpreter (address: 0x000000002274e130, threadid: 1)

```

To create a *private* Tcl interpreter, call the [`TclInterp`](@ref) constructor with the
symbol `:private`:

```julia-repl
julia> interp = TclInterp(:private)
Tcl interpreter (address: 0x0000000023461410, threadid: 1)

```

The resources associated with a Tcl interpreter are automatically released when the
[`TclInterp`](@ref) object is no longer referenced (that is garbage collected).


## Evaluation of commands

Execution of a Tcl command may be done in three different ways:

```julia
TclTk.exec(T=Nothing, interp=TclInterp(), args...)
interp.exec(T=Nothing, args...)
interp(T=Nothing, args...)
```

which execute the command specified by `args...` with the Tcl interpreter `interp` and yield
a result of type `T` (a Tcl object by default). Any `key => val` pair in `args...` is
converted in the pair of arguments `-key` and `val` in the command list (note the hyphen
before the key name). Otherwise, each of `args...` is a token of the command. The specific
handling of pairs is very useful for specifying options for [widgets](#widgets).

The execution of a Tcl command stores a result (or an error message) in the interpreter and
returns a status. The behavior of [`TclTk.exec`](@ref), or equivalent, depends on the type
`T` of the expected result:

* If `T` is [`TclStatus`](@ref), the status of the evaluation is returned and the command
  result may be retrieved by calling [`TclTk.getresult`](@ref), by `interp.result(...)`, or
  by `interp[...]`.

* If `T` is `Nothing`, an exception is thrown if the status is not [`TCL_OK`](@ref
  TclStatus) and `nothing` is returned otherwise (i.e., the result of the command is
  ignored).

* Otherwise, an exception is thrown if the status is not [`TCL_OK`](@ref TclStatus) and the
  result of the command is returned as a value of type `T` otherwise.

With [`TclTk.exec`](@ref), the shared interpreter of the thread is used by default.


## Evaluation of scripts

Evaluation of Tcl scripts may be done in two different ways:

```julia
TclTk.eval(T=Nothing, interp=TclInterp(), args...)
interp.eval(T=Nothing, args...)
```

which concatenate `args...` (as done by the [`TclTk.concat`](@ref) function) in the form of
script evaluated by the Tcl interpreter `interp` and yield the result of the script as a
value of type `T` (a Tcl object by default). In case of error, the behavior depends on `T`
as for the execution of a Tcl command described above. With [`TclTk.eval`](@ref), the shared
interpreter of the thread is used by default.

## Interpreter result

A Tcl interpreter stores the result of the last executed command or of the last evaluated
script or the last error message. Indexing an interpreter, say `interp`, without anything or
with a type `T`, that is as `interp[]` or `interp[T]`, give access to the interpreter
result, converted to type `T` (`TclObj` by default).

For example:

```julia-repl
julia> interp = TclInterp()
Tcl interpreter (address: 0x00000000260af720, threadid: 1)

julia> interp[] = 43 # set interpreter's result
43

julia> interp[] # retrieve interpreter's result
TclObj(43)

julia> interp[Int] # retrieve interpreter's result as an `Int`
43

julia> interp[String] # retrieve interpreter's result as a `String`
"43"

```

Accessing and mutating the result of an interpreter is done by methods
[`TclTk.getresult(T=TclObj, interp=TclInterp())`](@ref TclTk.getresult) and
[`TclTk.setresult!(interp=TclInterp(), value)`](@ref TclTk.setresult!) which, if no
interpreter is specified, apply to the shared interpreter of the thread.


## Global variables

A Tcl interpreter may also be indexed by a Tcl variable and an optional leading type `T` to
access to global variables stored by the interpreter:

```julia
interp[name]          # get value of global variable
interp[T, name]       # idem but value is converted to type `T`
interp[name] = value  # set value of global variable
haskey(interp, name)  # yield whether global variable exists
delete!(interp, name) # delete global variable
interp[name] = unset  # idem
```

Above `unset` is the singleton provided by the
[`UnsetIndex`](https://github.com/emmt/UnsetIndex.jl) package and exported by the `Tcl`
package

Under the hood, accessing and mutating the value of a global variable is done by the methods
[`tcl_getvar(T=TclObj, interp=TclInterp(), name)`](@ref tcl_getvar) and
[`tcl_setvar(Nothing, interp=TclInterp(), name, value)`](@ref tcl_setvar), checking for the
existence of a global variable is done by the method [`TclTk.exists(interp=TclInterp(),
name)`](@ref TclTk.exists), and deleting a global variable is done by the method
[`tcl_unsetvar(interp=TclInterp(), name)`](@ref tcl_unsetvar). All these methods apply to
the shared interpreter of the thread if no interpreter is specified.

## Linked variables

The [`TclVariable`](@ref) constructor yields an object tightly linked to a global Tcl
variable. For example:

```julia-repl
julia> A = TclVariable{Float64}("THRESHOLD")
TclVariable{Float64}(name: "THRESHOLD", value: #undef)

julia> eltype(A)
Float64

julia> A.name # get the name of the Tcl variable
TclObj("THRESHOLD")

julia> A.interp # get the Tcl interpreter where lives the variable
Tcl interpreter (address: 0x000000003b05c2a0, threadid: 1)

julia> isassigned(A) # does the variable have a value?
false

julia> A[] = 3.125 # let us give it a value
3.125

julia> isassigned(A) # now does it have a value?
true

julia> A
TclVariable{Float64}(name: "THRESHOLD", value: 3.125)

julia> TclTk.eval(Nothing, "set $(A.name) 12.5") # call Tcl to change the variable value

julia> A[] # get the variable value
12.5

julia> delete!(A) # unset the variable value

```

As can be guessed from the above example, `A[]` yields the value of the Tcl variable
(converted to the type of the variable, here `Float64`) while `A[] = x` mutates the value of
the variable.


## Properties

A Tcl interpreter, say `interp::TclInterp` has a number of properties:

- `interp.list(args...)` is a shortcut for [`TclTk.list(interp, args...)`](@ref TclTk.list)
  to build a list of Tcl objects, one for each of `args...`. In this context, the
  interpreter is only used to report errors if any, the returned list is not linked to the
  interpreter.

- `interp.concat(args...)` is a shortcut for [`TclTk.concat(interp, args...)`](@ref
  TclTk.concat) to concatenate arguments `args...` to form a list of Tcl objects. In this
  context, the interpreter is only used to report errors if any, the returned list is not
  linked to the interpreter.

- `interp(T=Nothing, args...)` and `interp.exec(T=Nothing, args...)` are shortcuts for
  [`TclTk.exec(T, interp, args...)`](@ref TclTk.exec) to execute a Tcl command with the
  interpreter and return a result of type `T`, a Tcl object by default. The first of
  `args...` is the Tcl command while the remaining `args...` are the arguments (or tokens)
  of the command.

- `interp.eval(T=Nothing, args...)` is a shortcut for [`TclTk.eval(T, interp,
  args...)`](@ref TclTk.eval) to evaluate the concatenation of `args...` as a Tcl script
  with the interpreter and return a result of type `T`, a Tcl object by default.

- `interp.result(T=TclObj)` is a shortcut for [`TclTk.getresult(T, interp)`](@ref
  TclTk.getresult) and the same as `interp[T]` to get the result stored by the interpreter
  as a value of type `T`. Depending on the last thing done by the interpreter, its result
  may be: empty, the result of the last command evaluated by the interpreter, or the error
  message of the last error occurring in the interpreter. See [`TclTk.setresult!`](@ref) for
  setting the result of a Tcl interpreter.

- `interp.threadid` yields the identifier of the thread where the interpreter lives.

- `interp.ptr` yields the pointer to the Tcl interpreter, this is the same as
  `pointer(interrp)`. Using this property to call a C function is *unsafe* (the object must
  be preserved from being garbage collected).
