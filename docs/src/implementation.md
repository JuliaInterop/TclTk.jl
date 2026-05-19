## Orgianization

```julia
module Tcl
    module Core
        # imports definitions from ..LibTcl and ..LibTk
        using ..LibTcl
        using ..LibTk

    end
    module LibTcl
        # provide calls to Tcl library
        include("../deps/tcldefs.jl")
    end
    module LibTk
       # imports definitions from LibTcl
       using ..LibTcl
       # provide calls to Tk library
       include("../deps/tkdefs.jl")
    end
end
```

Most Tcl functions require a Tcl interpreter or that at least one Tcl
interpreter has been created and that `Tcl_Init` has been called.  Simlarly for
Tk, `Tk_init` must have been called otherwise even simple functions like
`Tk_GetUid` wont't work or cause errors like segmentation faults.


A `ccall` like:

```julia
ccall((:SomeFunction, SomeLibrary), SomeReturnType, (Ptr{Cvoid},), x)
```

with an argument `x` of type `T` requires that `T <: Ptr`, `T <: Ref` or
`Base.unsafe_convert(::Type{Ptr{Cvoid}},x::T)` exists.

A `ccall` like:

```julia
ccall((:SomeFunction, SomeLibrary), SomeReturnType, (Ptr{SomeType},), x)
```

where `SomeType` is not `Cvoid` (that is `Nothing`) with an argument `x` of
type `T` requires that `T <: Ptr{Cvoid}`, `T <: Ptr{SomeType}`, `T <:
Ref{SomeType}`, `T <: Array{SomeType}` or
`Base.unsafe_convert(::Type{Ptr{SomeType}},x::T)` exists.

It is possible to wrap a pointer to an opaque structure into an immutable
structure to enforce some kind of type checking:

```julia
struct OpaqueTypeAddress; addr::UInt; end
struct OpaqueTypePointer; addr::Ptr{Cvoid}; end
```

the two are almost equivalent and are fast but be aware that, as the type is
immutable you cannot prevent garbage collection.

From the semantics of `Refvalue{T}` and its definition in `revalue.jl` in Julia
base sources, I deduce that some code like:

```julia
function somefunction(x)
    rx = Ref(x) # same as Ref{typeof(x)}(x)
    ccall((:SomeFunction, SomeLibrary), SomeReturnType, (Ptr{SomeType},), rx)
end
```

is ok even though argument `x` may be a temporary object (e.g., an expression)
because making a mutable object out of it and passing it to `ccall` prevents
`rx` (and therefore `x`) to be garbage collected before `ccall` returns.
