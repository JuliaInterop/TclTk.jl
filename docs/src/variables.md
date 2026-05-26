# Global Tcl variables

## Accessing global variables

`TclTk` exports a few functions to access the global variables of the shared Tcl interpreter:

* [`tcl_getvar`](@ref) is to query the value of a global Tcl variable.

* [`tcl_setvar`](@ref) is to set the value of a global Tcl variable.

* [`tcl_unsetvar`](@ref) is to unset a global Tcl variable.

* [`tcl_isassigned`](@ref) is check whether a global Tcl variable is set.

The syntax is:

```julia
tcl_getvar(var)        # get the value of the global variable as a `TclObj`
tcl_getvar(T, var)     # idem but value is converted to type `T`
tcl_setvar(var, val)   # set the value of the global variable and return `nothing`
tcl_setvar(T, var, val)# idem but return new value as a value of type `T`
tcl_isassigned(var)    # yield whether global variable exists
tcl_unset(var)         # delete global variable
tcl_setvar(var, unset) # idem
```

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

julia> isassigned(A) # does the variable have a value?
false

julia> A[] = 3.125 # let us give it a value
3.125

julia> isassigned(A) # now does it have a value?
true

julia> A
TclVariable{Float64}(name: "THRESHOLD", value: 3.125)

julia> tcl_eval(Nothing, "set $(A.name) 12.5") # have Tcl change the variable value

julia> A[] # get the variable value
12.5

julia> delete!(A) # unset the variable value

```

As can be guessed from the above example, `A[]` yields the value of the Tcl variable
(converted to the type of the variable, here `Float64`) while `A[] = x` mutates the value of
the variable.

## Global Tcl arrays

A Tcl array is similar to a dictionary in Julia. The [`TclArray`](@ref) constructor yields an
abstract dictionary associated with a global Tcl array. The syntax of the constructor is:

```julia
TclArray{K,V}(name, key=>val, ...)
```

where `name`, the name of the global Tcl array, may be followed by any number of `key=>val`
pairs. If not specified, the key and value types (`K` and `V`) default to `TclObj`.

Example:

```julia-repl
julia> A = TclArray{String,TclObj}("ARR", "value"=>2.125, "origin"=>"south-west", "counts"=>4)
TclArray{String,TclObj}("::ARR") with 3 entries:
  "origin" => TclObj("south-west")
  "counts" => TclObj(4)
  "value" => TclObj(2.125)

julia> tcl_eval("parray $(A.name)")
::ARR(counts) = 4
::ARR(origin) = south-west
::ARR(value)  = 2.125

julia> A["count"] = 2
2

julia> delete!(A, "value")

julia> tcl_eval("parray $(A.name)")
::ARR(count)  = 2
::ARR(origin) = south-west

```
