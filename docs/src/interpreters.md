# Tcl scripts and commands

## Managing the Tcl interpreter

Tcl scripts and commands are executed by a Tcl *interpreter* which is automatically launched
when needed. In principle, an application may have multiple Tcl interpreters but a given
interpreter must only be used in the thread where the interpreter was created; otherwise,
Tcl would *panic* (thus aborting the program). To prevent this, the `TclTk` package uses a
single Tcl interpreter that is shared by all Julia tasks (and hence all threads). A sticky
Julia task is dedicated to managing this shared interpreter and any call to a function that
requires a Tcl interpreter is executed in this task. For calls outside the Tcl interpreter
task, there is an overhead (about 1-2 μs) but this simplifies a lot the life of the end
user.


## Evaluation of commands

Direct execution of a Tcl command may be done by:

```julia
tcl_exec(T=Nothing, cmd, args...; kwds...)
```

which makes the shared Tcl interpreter execute the command `cmd` with arguments `args...`
and keywords `kwds...` and yield a result of type `T` (a Tcl object by default). Any `key =>
val` pair in `args...` and `key=val` in `kwds...` is converted in the pair of arguments
`-key` and `val` in the command list (note the hyphen before the key name). Otherwise, each
of `args...` is a token of the command and is handled as done by the [`tcl_list`](@ref)
function. The specific handling of pairs and keywords is very useful for specifying options
for [widgets](#widgets).

The execution of a Tcl command stores a result (or an error message) in the interpreter and
returns a status. The behavior of [`tcl_exec`](@ref) depends on the type
`T` of the expected result:

* If `T` is `Tuple{TclStatus,R}`, the status and the result of the Tcl command are returned
  as a 2-tuple and with the result converted to type `R`. In practice, `R` is one of
  `TclObj`, `String`, or `Nothing`. No conversion of the result is attempted if `R` is
  `Nothing` which is useful when the caller is only interested in the status.

* Otherwise, if the command status is [`TCL_OK`](@ref TclStatus), the result of the command
  is returned as a value of type `T`. No conversion of the result is attempted if `T` is
  `Nothing`.

* Otherwise, if the command status is not [`TCL_OK`](@ref TclStatus), a [`TclError`](@ref)
  exception is thrown.

Hence, the default behavior (with `T = Nothing`) amounts to discarding the result yet
throwing errors if any.


## Evaluation of scripts

Evaluation of Tcl scripts may be done in two different ways:

```julia
tcl_evalfile(T=Nothing, filename)
```

evaluates the Tcl script in file named `filename`, while:

```julia
tcl_eval(T=Nothing, args...)
```

concatenates `args...` (as done by the [`tcl_concat`](@ref) function) in the form of
a script which is evaluated by the shared Tcl interpreter.

The optional argument `T` is to specify the expected result and is considered exactly as
done by [`tcl_exec`](@ref).
