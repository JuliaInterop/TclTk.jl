
FIXME Redo bemchmarks.

# Notes for developers


## Management of Tcl objects.

Tcl memory management is such that the program is aborted whenever memory allocation fails
causing the program to abort. It is therefore not necessary to check for the reference
returned by object creation functions (such as `Tcl_NewBooleanObj`) as it can never be
`NULL`. This simplifies the code (no needs to report such errors or throw exceptions and
then catch them, etc.).

Tcl objects have a reference count. Objects are created with a reference count of `0`. The
reference count may be incremented by the private method `TclTk.unsafe_incr_refcnt(ptr)` which
emulates `Tcl_IncrRefCount` C macro and returns the pointer `ptr` to a Tcl object. The
reference count may be decremented by the private method `TclTk.unsafe_decr_refcnt(ptr)` which
emulates `Tcl_DecrRefCount` C macro and frees the object if its reference count becomes less
or equal `0`. Any one who wants to keep a Tcl object alive shall increment its reference
count and eventually decrement it when the object is no longer needed. In Tcl, an object
with a reference count greater or equal `1` is said to be *shared*. Tcl assumes a strict
copy-on-write policy for its objects and will panic (i.e., abort the program) whenever a
shared object is modified. Base method `iswritable(obj)` can be used to check whether `obj`
can be modified (i.e., the corresponding Tcl object is non-null and not shared). At low-level
private method `TclTk.assert_writable(objptr)` throws if `objptr` is null or shared.


## Conversions

### Conversion to Tcl objects

Depending on their types, Julia values can be automatically converted to Tcl objects, at low
level, by the private method `TclTk.new_object(val)` or, at high level, by the constructor
`TclObj(val)`. Implemented automatic conversions include:

* Primary types:
  * `Bool` values are converted into Tcl objects by `Tcl_NewBooleanObj`.
  * `Integer` values are converted into Tcl objects by `Tcl_NewIntObj`, `Tcl_NewLongObj`, or
    `Tcl_NewWideIntObj`. However, on my 64-bit machine, `Tcl_NewBooleanObj`,
    `Tcl_NewIntObj`, `Tcl_NewLongObj`, and `Tcl_NewWideIntObj` all yield an object stored of
    the same internal representation named `int`.
  * Other `Real` values are converted to `Cdouble` by `Tcl_NewDoubleObj`.
  * Strings and keywords are converted to Tcl strings with `Tcl_NewStringObj`.
  * Characters are converted to `String` of length 1.

* Other types:
  * Vectors and tuples with elements of such primary types are converted into `List`.
  * Pairs `key => val` can be converted as `-key val` (for Tk widget options). If `key` is a
    symbol, it may starts with a leading underscore `_` which is discarded (this is to allow
    for options whose names match a Julia reserved keyword).

* Other conversions:
  * `TclTk.bytearray(arr)` yields a Tcl byte array whose bytes are given by `arr`.

### Conversion from Tcl objects

The internal type of Tcl objects created by Julia is known at creation time but this type
may change later (provided it does not change the string representation of the object if it
is shared). Besides, it is not possible to reliably infer the type of Tcl objects retrieved
from Tcl interpreter result. Therefore, automatic conversion of a Tcl object into a Julia
value/object would not be type-stable and is not implemented. However, conversion to a given
type is implemented at different levels:

* At low level, private method, `TclTk.Core.unsafe_convert(T, ptr)` can be called to convert
  Tcl object pointer `ptr` into a Julia value of given type `T`. `ptr` may also be a pointer
  to a Tcl interpreter to convert its result. Conversion by `T(ptr)` and `convert(T, ptr)`
  is not extended to not break pointer arithmetic and because they would be *unsafe*.

* At high level, method `convert(T, obj::TclObj)` is implemented to convert a `obj` into a
  Julia value of given type `T`.

The `TclList` object is special: it is created a a Tcl list and used as such (i.e., as a
Julia iterable) even though its elements have unknown internal type.


## Threads

A given Tcl interpreter can only be used in the thread where is was created. Tcl will panic
(i.e., abort the program) if this constraint does not hold. In the Julia wrapper, this
constraint is checked for Tcl interpreter objects in `ccall` by `Base.unsafe_convert`. The
private `TclTk.finalize` method (hence, `Tcl_DeleteInterp`) may however be called by the
garbage collector from another thread and no error can be thrown there. For now, this prints
a warning and leave the interpreter un-deleted. This is a potential memory leak.

This constraint does not affect Tcl objects.

## Evaluation

* `Tcl_EvalObjEx(interp, obj, TCL_EVAL_GLOBAL)` converts `obj` internal type to `:bytecode`
   unless the content of `obj` is not valid as a Tcl script and whatever the internal type
   and the reference counts of `obj`. Set `TCL_EVAL_DIRECT` in flags to avoid conversion to
   `:bytecode`.

## Timings

* `TclObj(true)`: 55ns on median
* `Tcl_Preserve(interp_ptr)` followed by `Tcl_Preserve(interp_ptr)`: 53ns on average

## Things to document

```julia
interp.eval([T], script)
```
evaluate script with Tcl interpreter `interp` and convert result to type `T`.
Identical to:

```julia
tcl_eval([T], interp, script)
```

## Lists

When building lists, the optional interpreter (can be NULL) is only used for error message.
We can use the shared interpreter of the thread for that, perhaps saving/restoring its state
but that's take time.

### Pre-compiled scripts

It is possible to store compiled scripts which run much faster.  For that
you have to store the script as a string Tcl object in a Julia variable.
For instance (the backslash is to let Tcl interpolate the `$` sign):

```julia
script = TclObj("expr {sin(\$x)}")
TclTk.setvar!("x", 2)
using BenchmarkTools
@benchmark tcl_eval(TclStatus, script)
```

reports (on my machine) a maximum execution time of 7.3 µs but a median time of
500 ns (about 15 times faster).  This is due to the fact that the script is
compiled by Tcl the first time it is called (this took 7.3 µs) and the result
of this compilation is saved with the object so that next evaluations are much
faster (about 15 times faster in this case).  This compilation remains valid if
you change the variable value:

```julia
TclTk.setvar!("x", 3); tcl_eval(script)   # yields  0.141120...
TclTk.setvar!("x", 4); tcl_eval(script)   # yields -0.756802...
```

Note that using the `raw` string decoration leads to more readable scripts.
For instance:

```julia
script = TclObj(raw"expr {sin($x)}")
```

## Performances

```julia
using TclTk, BenchmarkTools
@btime GC.gc() # 237.687 ms (0 allocations: 0 bytes)
```

```julia
using TclTk, BenchmarkTools
tcl = TclInterp()

# Setting a Tcl variable
@btime TclTk.setvar!($tcl,"x", 9)   #  150.214 ns (0 allocations: 0 bytes)
@btime $tcl("set x 9")           #  994.500 ns (2 allocations: 48 bytes)
@btime tcl_eval($tcl, "set x 9") #  993.154 ns (2 allocations: 48 bytes)
@btime tcl_eval("set x 9")       # 1060     ns (2 allocations: 48 bytes)
@btime tcl_eval(TclStatus,"set x 9") # 910.718 ns (0 allocations: 0 bytes)

@btime $tcl(Int,"set x 9")      # 943.852 ns (0 allocations: 0 bytes)

# Getting a Tcl variable (as an Int):
@btime TclTk.getvar(Int,$tcl,"x") # 134.454 ns (0 allocations: 0 bytes)
@btime $tcl(Int,"set x")        # 825.184 ns (0 allocations: 0 bytes)
@btime $tcl(Int,"set", "x")     # 824.192 ns (0 allocations: 0 bytes)

# Getting a Tcl variable (as a string):
@btime TclTk.getvar($tcl,"x")     # 215.452 ns (1 allocation: 16 bytes)
@btime $tcl("set x")            # 809.149 ns (1 allocation: 16 bytes)
@btime $tcl("set", "x")         # 907.765 ns (1 allocation: 16 bytes)

```













Do not use Tcl objects until you have created a Tcl interpreter, otherwise
`TclFreeObj` called


Make a string and a substring with some UTF characters

    s = "hello Éric, ça va ?"
    sb = SubString(s,7,11)
    sizeof(s)  -> 21
    length(s)  -> 19
    sizeof(sb) ->  5
    length(sb) ->  4

C `strlen` count the number of bytes (and passing a `Cstring` is all right
even with a sub-string):

    Int(ccall(:strlen, Csize_t, (Cstring,), s))  -> 21
    Int(ccall(:strlen, Csize_t, (Cstring,), sb)) ->  5

There are two alternatives to create Tcl string objects: `Tcl_NewStringObj` or
`Tcl_NewUnicodeObj`.  But `Tcl_NewUnicodeObj` deals with `Tcl_UniChar` (which
rae fixed size multi-byte characters) while `Tcl_NewStringObj` deals with
`char` and is able to recognize embedded UTF sequences and embedded null bytes
if the number of bytes is provided (otherwise null bytes should be represented
by the 2-byte sequence `\700\600`).  Looking in its C implementaion, function
`Tcl_NewStringObj` uses `strlen` to determine the number of bytes to copy, so
using it on Julia string is OK (as standard C library `strlen(str)` yields
Julia `sizeof(str)` for a string `str`, cf. above).  Using `Tcl_NewStringObj`
to pass Julia strings (all `AbstractString`?) to Tcl seems coorect as Tcl
command `string length $str` called by `TclTk.evaluate("string","length",str)`
correctly yields the number of characters while Tcl command `string bytelength
$str` called by `TclTk.evaluate("string","bytelength",str)` correctly yields the
number of bytes (not including the final null).

However embedded nulls are not allowed by Julia when converting `Vector{UInt8}`
to `Cstring`.

    t = "hello Éric, ça va\000 ?"
    Int(ccall(:strlen, Csize_t, (Cstring,), t))    -> error

It is possible to pretend that argument is a `Ptr{UInt8}` but the first
embedded null is considered as the end of the string by the standard C library:

    Int(ccall(:strlen, Csize_t, (Ptr{UInt8},), t)) -> 19
    sizeof(t) -> 22

## Check whether a string contains NULL's

```julia
function check1(s::AbstractString)
    @inbounds @simd for c in s
        c == '\u0' && return true
    end
    return false
end
function check2(s::AbstractString)
    @inbounds @simd for i in 1:length(s)
        s[i] == '\u0' && return true
    end
    return false
end
s1 = "hello world!"
s2 = "hello w\u0rld!"
```

Then with `s` being `s1` or `s2`, the mean median times are:
* `check1(s)` takes 82ns;
* `check2(s)` takes 84ns;
* `search(s,'\u0')` takes 35ns;
* `Base.containsnul(s)` takes 20ns;

So `Base.containsnul(s)` is the clear winner except that its timing does not
depend on the position of the null.


## Benchmarking

    use BenchmarkTools

Minimum time to create a simple object, increment its reference count and
decrement its reference count (thus freeing the memory):

    Type          Time
    ------------------
    integer       31ns
    float         31ns
    irrational    31ns
    rational      59ns
    nothing       35ns
    empty string  32ns
    string        52ns
    symbol       170ns
    ------------------

The longest time is for symbols because we need to create its string
representation in Julia.

Minimum time to create a simple object, increment its reference count, get its
string representation (according to Tcl) and decrement its reference count
(thus freeing the memory):

    function tclstr(str::String)
        ptr = TclTk.Core.__newobj(str)
        TclTk.Imp.Tcl_IncrRefCount(ptr)
        result = unsafe_string(ccall((:Tcl_GetString, TclTk.libtcl), Cstring,
                                     (Ptr{Void},), obj.ptr))
        TclTk.__decrrefcount(obj)
        return result
    end

    Type          Time      string(...)
    -----------------------------------
    integer      119-151ns      43-72ns
    float        188-354ns    282-435ns
    irrational       343ns       1001ns
    rational         217ns        309ns
    nothing           89ns        133ns
    empty string      90ns          8ns
    string           113ns          8ns
    symbol           223ns        116ns
    -----------------------------------

Note that for real numbers the time depends on the length of the result.  This
is also true for strings and symbols but not as much sensitive (except perhaps
very long strings).


Tcl timings:
```
set $name $value   0.4µs    (after compiling)
unset $name        0.4µs    (after compiling)
```

```julia
tcl_eval("concat hello world!")         1.2 µs
tcl_eval("list hello world!")          16   µs
tcl_exec("concat", "hello", "world!")   7   µs
tcl_exec("list", "hello", "world!")    24   µs
```

## Private methods

Private (or low level) methods are not intended for the end-user, they are not
exported and their names start by a double underscore.  These methods are
usually helper functions or directly call the functions of the Tcl C library.
In principle, these methods do not throw exceptions but return a value which
may be used to figure out whether the call was a success or a failure.  A
notable exception are the `__newobj`, `__newbytearrayobj`, `__newlistobj`,
`__newstringobj` and `__objptr` methods which ensures that the returned object
pointer is non-NULL and throw an exception otherwise.  This is needed to
simplify the management of failures.

# Calls to the Tcl C library

## Reference count

Tcl objects count their number of references.  Creating an object yields a
*temporary* object, that is an object with a reference count equals to zero.
To hold an object, increment its reference count, this guarantees that the
object will not get destroyed by calling a function with this object as
argument.  To release an object, decrease its reference count and, if the
reference count becomes 0 (or -1 if the object was a temporary object), destroy
the object.  Incrementing the reference count is done by `Tcl_IncrRefCount`
while decrementing the reference count (and eventually free the object) is done
by `Tcl_DecrRefCount`.  Unfortunately, these are 2 macros (for efficiency
reasons I suppose) so we have to emulate them which requires to figure out
where is stored the reference count of an object (it is easy it is the first
member of the `Tcl_Obj` structure and it is a `Cint`).  To eventually destroy
the object the (undocumented) function `TclFreeObj` has to be called.

A function **do manage** the reference count of an object argument if it takes
of increasing (on entry) and decreasing (on return) the reference count of this
object.  A function **do not manage** the reference count of an object argument
if it does not touch the reference count of this object.  A managed object
argument can be a temporary object creating on the fly.  If a temporary object
is passed as an argument, you have to decrease its reference count after the
function returns.


## Functions called

The following functions of the Tcl C library are called by **TclTk.jl**.


### Basics

* `Tcl_Preserve`, `Tcl_Release` and `Tcl_EventuallyFree` implement a reference
  count mechanism for other things than Tcl objects.

* `Tcl_SetObjResult` does manage the reference count of its object argument so
  it is OK to directly pass a temporary object.

* `Tcl_SetResult` takes a C string as argument.  The only thing to do is to
  check for embedded nuls.

* `Tcl_GetObjResult` yields an object whose reference count must be incremented
  only if we want to keep a long-term reference to it.

* `Tcl_Init` is called once to initialize a Tcl interpreter.

* `Tcl_CreateInterp`, `Tcl_DeleteInterp`, `Tcl_InterpActive` and
  `Tcl_InterpDeleted` deal with interpreters.  Non-permanent interpreters
  could have their reference count managed by calls to `Tcl_Preserve`,
  `Tcl_Release` and `Tcl_EventuallyFree`.

  Although it is possible to call `Tcl_Preserve`, `Tcl_Release` and
  `Tcl_EventuallyFree` to manage non-permanent interpreters, this would require
  passing the address of `Tcl_DeleteInterp` to `Tcl_EventuallyFree`.  The
  another (easier) solution is to count on Julia garbage collector, which is
  what is done in **TclTk.jl**.  Note that the 2 solutions require to write a
  finalizer.

* `Tcl_DoOneEvent` executes next pending Tcl event.  It is called by
  `TclTk.do_events` until there are no more pending events.


## Scripts and commands

`Tcl_CreateCommand`
`Tcl_DeleteCommand`

* `Tcl_EvalObjEx` does manage the reference count of its object argument so it
  is OK to just pass a temporary object.

* `Tcl_EvalObjv` does not touch the reference count of the items in the `objv`
  array, hence it is OK to pass an array of temporary items but you'll have to
  free these items after the call.  More usual is to pass an array of items
  obtained by `Tcl_ListObjAppendElement`.


## Objects

* `Tcl_GetObjType` does not manipulate objects.

* `Tcl_GetBooleanFromObj`, `Tcl_GetDoubleFromObj`, `Tcl_GetIntFromObj`,
  `Tcl_GetLongFromObj`, `Tcl_GetStringFromObj` and `Tcl_GetWideIntFromObj` do
  not touch the reference count of the object argument.  A temporary object
  argument will not be freed.

* `Tcl_ListObjAppendElement` increments the reference count of the inserted
  elements but does not touch the reference count of the list.  Therefore it
  can be used to build a temporary list, not forgetting to release the list
  when no longer used.

* `Tcl_ListObjGetElements` does not touch the reference count of the list
  object and of its elements.

* `Tcl_ListObjIndex` does not touch the reference count of the list object and
  of the returned element.

* `Tcl_ListObjLength` does not touch the reference count of the list object.

* `Tcl_NewBooleanObj`, `Tcl_NewByteArrayObj`, `Tcl_NewDoubleObj`,
  `Tcl_NewIntObj`, `Tcl_NewListObj`, `Tcl_NewLongObj`, `Tcl_NewStringObj` and
  `Tcl_NewWideIntObj` create a new temporary object with no references.


### Variables

* `Tcl_GetVar`, `Tcl_GetVar2` and `Tcl_GetVar2Ex` call `Tcl_ObjGetVar2`.

* `Tcl_ObjGetVar2` receives up to 2 objects to represent the parts of the
  variable name.  From the code of `Tcl_ObjGetVar2` it is not clear whether it
  considers or not the reference count of the parts of the variable name.  From
  memory leakage tests, it seems that `Tcl_ObjGetVar2` does not free the parts
  of the variable name when provided as temporary objects.  This means
  `Tcl_ObjGetVar2` does not increase (on entry) and decrease (on return) the
  reference count of these objects.  See `Tcl_ObjSetVar2` for how to manage the
  name parts.

* `Tcl_SetVar` calls `Tcl_ObjSetVar2`, `Tcl_SetVar2` calls `Tcl_SetVar2Ex`
  which calls `Tcl_ObjSetVar2`.

* `Tcl_ObjSetVar2` (according to C code) does not manage the reference count of the variable
  name parts but does manage the reference count of the variable value. As a consequence,
  the value can be a temporary object; any name part which is a temporary object must have
  its reference count increasing before calling `Tcl_ObjSetVar2` and decreasing after
  (although increasing is not strictly necessary, it is safer).

* `Tcl_UnsetVar` and `Tcl_UnsetVar2` takes C strings as argument.  The only
  thing to do is to check for embedded nuls.  In that case, evaluate the
  command `"unset name"`.
