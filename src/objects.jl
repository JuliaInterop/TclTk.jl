"""
    TclObj(val) -> obj

Return a Tcl object storing value `val`. The initial type of the Tcl object, given by
`obj.type`, depends on the type of `val`:

- A string, symbol, or character is stored as a Tcl `:string`.

- A Boolean or integer is stored as a Tcl `:int` or `:wideInt`.

- A non-integer real is stored as a Tcl `:double`.

- A dense vector of bytes (`UInt8`) is stored as a Tcl `:bytearray`.

- A tuple is stored as a Tcl `:list`.

- A Tcl object is returned unchanged. Call `copy` to have an independent copy.

If the content of a Tcl object is valid as a list, the object may be indexed, elements may
be added, deleted, etc.

# Properties

Tcl objects have the following read-only properties:

- `obj.refcnt` is the reference count of `obj`. If `obj.refcnt > 1`, the object is shared
  and must be copied before being modified.

- `obj.ptr` is the pointer to the Tcl object, this is the same as `pointer(obj)`.

- `obj.type` is the *current internal type* of `obj` as a symbol. This type may change
  depending on how the object is used by Tcl. For example, after having evaluated a script
  in a Tcl string object, the object internal state becomes `:bytecode` to reflect that it
  now stores compiled byte code.

# Conversion

Call `convert(T, obj)` to get a value of type `T` from Tcl object `obj`. The content of a
Tcl object may always be converted into a string by calling `convert(String, obj)`,
`string(obj)`, or `String(obj)` which all yield a copy of this string.

# See also

[`tcl_list`](@ref) or [`tcl_concat`](@ref) for building Tcl objects to efficiently store
arguments of Tcl commands.

Methods [`TclTk.Core.new_object`](@ref) and [`TclTk.Core.unsafe_convert`](@ref) may be
extended to convert other types of value to Tcl object.

"""
TclObj(obj::TclObj) = obj
TclObj() = TclObj(null(ObjPtr))
TclObj(val) = _TclObj(new_object(val))
TclObj(objptr::ObjPtr) = _TclObj(objptr)

function Base.copy(obj::TclObj)
    local objptr
    GC.@preserve obj begin
        objptr = unsafe_duplicate(pointer(obj))
    end
    return _TclObj(objptr)
end

function unsafe_duplicate(objptr::ObjPtr)
    if isnull(objptr) || Tcl_GetRefCount(objptr) < 𝟙
        return objptr
    else
        return Tcl_DuplicateObj(objptr)
    end
end

Base.string(obj::TclObj) = String(obj)
function Base.String(obj::TclObj)
    GC.@preserve obj begin
        return unsafe_string(pointer(obj))
    end
end
function Base.unsafe_string(objptr::ObjPtr)
    isnull(objptr) && unexpected_null(objptr)
    # NOTE `unsafe_string` takes care of null `ptr`, so we do not check that.
    len = Ref{Tcl_Size}()
    return unsafe_string(Tcl_GetStringFromObj(objptr, len), len[])
end

Base.convert(::Type{TclObj}, obj::TclObj) = obj
Base.convert(::Type{TclObj}, val::Value) = TclObj(val)::TclObj

Base.convert(::Type{String}, obj::TclObj) = String(obj)::String
Base.convert(::Type{Symbol}, obj::TclObj) = Symbol(obj)::Symbol
function Base.convert(::Type{T}, obj::TclObj) where {T<:Union{Value,NothingOr{<:Value}}}
    GC.@preserve obj begin
        # NOTE `unsafe_convert` takes care of null object pointer.
        return unsafe_convert(T, pointer(obj))
    end
end

# Usual constructors can also perform conversion. FIXME Char, AbstractChar
for type in (:Integer, :Signed, :Unsigned, :AbstractFloat, :Real, :Bool,
             :Int8, :UInt8, :Int16, :UInt16, :Int32, :UInt32, :Int64, :UInt64,
             (isdefined(Base, :Int128) ? (:Int128,) : ())...,
             (isdefined(Base, :UInt128) ? (:UInt128,) : ())...,
             :Float16, :Float32, :Float64, :BigFloat,)
    @eval Base.$type(obj::TclObj) = convert($type, obj)
end
for type in (isdefined(Base, :Memory) ? (:Vector, :Memory) : (:Vector,))
    @eval Base.$type{T}(obj::TclObj) where {T} = convert($type{T}, obj)
end

Base.:(==)(A::TclObj, B::TclObj) = isequal(A, B)
Base.:(==)(A::TclObj, B::Union{AbstractString,Symbol}) = isequal(A, B)
Base.:(==)(A::Union{AbstractString,Symbol}, B::TclObj) = isequal(A, B)

function Base.isequal(A::TclObj, B::TclObj)
    # TODO Optimize depending on internal representation?
    GC.@preserve A B begin
        A_ptr = pointer(A)
        B_ptr = pointer(B)
        (A_ptr == B_ptr) && return true
        (isnull(A_ptr) || isnull(B_ptr)) && return false
        A_len = Ref{Tcl_Size}()
        A_buf = Tcl_GetStringFromObj(A_ptr, A_len)
        B_len = Ref{Tcl_Size}()
        B_buf = Tcl_GetStringFromObj(B_ptr, B_len)
        (A_len[] == B_len[]) || return false
        return iszero(unsafe_memcmp(A_buf, B_buf, B_len[]))
    end
end

Base.isequal(A::Union{AbstractString,Symbol}, B::TclObj) = isequal(B, A)

Base.isequal(A::TclObj, B::AbstractString) = isequal(A, String(B)::String)

function Base.isequal(A::TclObj, B::FastString)
    GC.@preserve A B begin
        A_ptr = pointer(A)
        isnull(A_ptr) && return false
        A_len = Ref{Tcl_Size}()
        A_buf = Tcl_GetStringFromObj(A_ptr, A_len)
        B_len = sizeof(B) # number of bytes in B
        (A_len[] == B_len) || return false
        return iszero(unsafe_memcmp(A_buf, B, B_len))
    end
end

# Extend `print` so that string interpolation for Tcl objects works as in Tcl scripts.
function Base.print(io::IO, obj::TclObj)
    write(io, obj)
    return nothing
end

function Base.write(io::IO, obj::TclObj)
    return GC.@preserve obj unsafe_write(io, pointer(obj))
end

function Base.unsafe_write(io::IO, objptr::ObjPtr)
    isnull(objptr) && return 0
    len = Ref{Tcl_Size}()
    buf = Tcl_GetStringFromObj(objptr, len)
    return Int(unsafe_write(io, buf, len[]))::Int
end

# Extend base methods for objects.
function Base.summary(io::IO, obj::TclObj)
    type = obj.type
    if type ∈ (:int, :wideInt)
        print(io, "Tcl integer object")
    elseif type == :double
        print(io, "Tcl floating-point object")
    elseif type == :bytearray
        print(io, "Tcl byte-array object")
    elseif type == :list
        print(io, "Tcl list of ", length(obj), " object(s)")
    elseif type == :boolean
        write(io, obj)
    elseif type == :null
        print(io, "Tcl null object")
    else
        print(io, "Tcl object")
    end
end

function Base.repr(obj::TclObj)
    io = IOBuffer()
    show(io, obj)
    return String(take!(io))
end

Base.show(io::IO, ::MIME"text/plain", obj::TclObj) = show(io, obj)
function Base.show(io::IO, obj::TclObj)
    print(io, "TclObj(")
    show_value(io, obj)
    print(io, ")")
end

function show_value(io::IO, obj::TclObj; maxlen::Integer=50)
    maxlen = max(3, Int(maxlen)::Int)
    halfmaxlen = div(maxlen - 1, 2)
    type = obj.type
    if type ∈ (:int, :wideInt)
        print(io, convert(WideInt, obj))
    elseif type == :double
        print(io, convert(Cdouble, obj))
    elseif type == :bytearray
        print(io, "UInt8[")
        GC.@preserve obj begin
            len = Ref{Tcl_Size}()
            ptr = Tcl_GetByteArrayFromObj(obj, len)
            len = Int(len[])::Int
            if len ≤ maxlen
                for i in 1:len
                    i > 1 && print(io, ", ")
                    show(io, unsafe_load(ptr, i))
                end
            else
                for i in 1:halfmaxlen
                    i > 1 && print(io, ", ")
                    show(io, unsafe_load(ptr, i))
                end
                print(io, ", ...")
                for i in len-halfmaxlen+1:len
                    print(io, ", ")
                    show(io, unsafe_load(ptr, i))
                end
            end
        end
        print(io, "]")
    elseif type == :list
        print(io, "(")
        len = length(obj)
        if len ≤ maxlen
            for i in 1:len
                i > 1 && print(io, ", ")
                show_value(io, obj[i])
            end
        else
            for i in 1:halfmaxlen
                i > 1 && print(io, ", ")
                show_value(io, obj[i])
            end
            print(io, ", ...")
            for i in len-halfmaxlen+1:len
                print(io, ", ")
                show_value(io, obj[i])
            end
        end
        print(io, ",)")
    elseif type == :boolean
        write(io, obj)
    elseif type == :null
        print(io, "#= null =#")
    else
        show(io, string(obj))
    end
end

# It is forbidden to access to the fields of a `TclObj` by the `obj.key` syntax.
Base.propertynames(obj::TclObj) = (:ptr, :refcnt, :type)
@inline Base.getproperty(obj::TclObj, key::Symbol) = _getproperty(obj, Val(key))
@noinline function Base.setproperty!(obj::TclObj, key::Symbol, val)
    key ∈ propertynames(obj) ? error("attempt to set read-only property") :
        throw(KeyError(key))
end

_getproperty(obj::TclObj, ::Val{key}) where {key} = throw(KeyError(key))

_getproperty(obj::TclObj, ::Val{:ptr}) = getfield(obj, :ptr)

function _getproperty(obj::TclObj, ::Val{:refcnt})
    GC.@preserve obj begin
        ptr = pointer(obj)
        return isnull(ptr) ? -one(Tcl_Obj_refCount_type) : Tcl_GetRefCount(ptr)
    end
end

function _getproperty(obj::TclObj, ::Val{:type})
    GC.@preserve obj begin
        return unsafe_object_type(pointer(obj))
    end
end

"""
    iswritable(obj) -> bool

Return whether Tcl object `obj` is writable, that is whether its pointer is non-null and it
has at most one reference.

"""
Base.isreadable(obj::TclObj) = isreadable(pointer(obj))
Base.isreadable(objptr::ObjPtr) = !isnull(objptr)

function assert_readable(objptr::ObjPtr)
    isnull(objptr) && assertion_error("null Tcl object has no value")
    return objptr
end

"""
    iswritable(obj) -> bool

Return whether Tcl object `obj` is writable, that is whether its pointer is non-null and it
has at most one reference.

"""
Base.iswritable(obj::TclObj) = iswritable(pointer(obj))
Base.iswritable(objptr::ObjPtr) = !isnull(objptr) && Tcl_GetRefCount(objptr) ≤ 𝟙

function assert_writable(objptr::ObjPtr)
    isnull(objptr) && assertion_error("null Tcl object is not writable")
    Tcl_GetRefCount(objptr) > 𝟙 && assertion_error("shared Tcl object is not writable")
    return objptr
end

finalize(obj::TclObj) = set_pointer!(obj, null(ObjPtr))

function set_pointer!(obj::TclObj, newptr::ObjPtr)
    oldptr = getfield(obj, :ptr)
    if newptr != oldptr
        isnull(newptr) || Tcl_IncrRefCount(newptr)
        setfield!(obj, :ptr, newptr)
        isnull(oldptr) || Tcl_DecrRefCount(oldptr)
    end
    nothing
end

"""
    TclTk.Core.unsafe_objptr(arg) -> objptr
    TclTk.Core.unsafe_objptr(arg, descr) -> objptr

Return a pointer to a Tcl object from `arg`. If `arg` is an instance of `TclObj`,
`pointer(arg)` is returned throwing an error if this pointer is null. Otherwise, a new Tcl
object is created from `arg` and the caller is responsible for managing this object so that
it is correctly released when no longer in use. In any case, the returned pointer is
guaranteed to be non-null but may only remain valid while `arg` is not garbage collected.

Optional `descr` provides a description of the argument `arg` for error messages.

# See also

[`TclObj`](@ref), [`TclTk.Core.WrappedObject`](@ref), and [`TclTk.Core.new_object`](@ref),

"""
unsafe_objptr(obj::TclObj) = checked_pointer(obj)
unsafe_objptr(obj::TclObj, descr::AbstractString) = unsafe_objptr(pointer(obj), descr)

unsafe_objptr(val::Any) = new_object(val)
unsafe_objptr(val::Any, descr::AbstractString) = unsafe_objptr(val)

unsafe_objptr(objptr::ObjPtr) = unsafe_objptr(objptr, "Tcl object pointer")
function unsafe_objptr(objptr::ObjPtr, descr::AbstractString)
    isnull(objptr) && unexpected_null(descr)
    return objptr
end

"""
    tryparse(T, obj::TclObj)::Union{T,Nothing}

Attempt to convert a Tcl object `obj` to a Julia value of type `T`. Return a value of type
`T` on success; `nothing on failure.

"""
function Base.tryparse(::Type{T}, obj::TclObj) where {T}
    GC.@preserve obj begin
        return unsafe_tryparse(T, pointer(obj)) # NOTE pointer may be null
    end
end

# Tcl provides accessor functions for a few numeric types:
#
# - Tcl_GetBooleanFromObj for Booleans.
#
# - Tcl_GetIntFromObj for Cint, Tcl_GetLongFromObj for Clong, and Tcl_GetWideIntFromObj
#   for WideInt. However, for Tcl ≥ 9, any non-Boolean integer is stored as a WideInt.
#   So, we use this type for any non-Boolean integer.
#
# - Tcl_GetDoubleFromObj for Cdouble and we use this type for any non-integer real.

function unsafe_tryparse(::Type{Bool}, objptr::ObjPtr)
    if !isnull(objptr)
        val = Ref{Cint}()
        Tcl_GetBooleanFromObj(C_NULL, objptr, val) == TCL_OK && return !iszero(val[])
    end
    return nothing
end

function unsafe_tryparse(::Type{WideInt}, objptr::ObjPtr)
    if !isnull(objptr)
        val = Ref{WideInt}()
        Tcl_GetWideIntFromObj(C_NULL, objptr, val) == TCL_OK && return val[]
    end
    return nothing
end

function unsafe_tryparse(::Type{Cdouble}, objptr::ObjPtr)
    if !isnull(objptr)
        val = Ref{Cdouble}()
        Tcl_GetDoubleFromObj(C_NULL, objptr, val) == TCL_OK && return val[]
    end
    return nothing
end

function unsafe_tryparse(::Type{T}, objptr::ObjPtr) where {T<:Integer}
    val = unsafe_tryparse(WideInt, objptr)
    return val isa WideInt && typemin(T) ≤ val ≤ typemax(T) ? convert(T, val)::T : nothing
end

function unsafe_tryparse(::Type{T}, objptr::ObjPtr) where {T<:Union{AbstractFloat,Rational}}
    val = unsafe_tryparse(Cdouble, objptr)
    return val isa Cdouble ? convert(T, val)::T : nothing
end

function unsafe_tryparse(::Type{Integer}, objptr::ObjPtr)
    type = unsafe_object_type(objptr)
    if type == :boolean
        return unsafe_tryparse(Bool, objptr)
    elseif type ∈ (:int, :wideInt)
        # In Tcl ≥ 9, non-Boolean integers are stored as `WideInt`.
        return unsafe_tryparse(WideInt, objptr)
    elseif type == :string
        # Try to parse an integer.
        i = unsafe_tryparse(WideInt, objptr)
        isnothing(i) || return i
        # Otherwise, maybe a textual Boolean.
        b = unsafe_tryparse(Bool, objptr)
        isnothing(b) || return b
    end
    return nothing
end

function unsafe_tryparse(::Type{Real}, objptr::ObjPtr)
    type = unsafe_object_type(objptr)
    if type == :boolean
        return unsafe_tryparse(Bool, objptr)
    elseif type ∈ (:int, :wideInt)
        # In Tcl ≥ 9, non-Boolean integers are stored as `WideInt`.
        return unsafe_tryparse(WideInt, objptr)
    elseif type == :double
        return unsafe_tryparse(Cdouble, objptr)
    elseif type == :string
        # Try to parse a floating-point.
        x = unsafe_tryparse(Cdouble, objptr)
        if isnothing(x)
            # Otherwise, maybe a textual Boolean.
            b = unsafe_tryparse(Bool, objptr)
            isnothing(b) || return b
        elseif trunc(x) === x
            # Try to parse an integer.
            i = unsafe_tryparse(WideInt, objptr)
            isnothing(i) || return i
        end
        return x
    end
    return nothing
end

"""
    TclTk.Core.new_object(x) -> ptr

Return a pointer to a new Tcl object storing value `x`. The new object has a reference count
of `0`.

# See also

[`TclObj`](@ref), [`TclTk.Core.new_list`](@ref), [`TclTk.Core.Tcl_GetRefCount`](@ref),
[`TclTk.Core.Tcl_IncrRefCount`](@ref), and [`TclTk.Core.Tcl_DecrRefCount`](@ref).

"""
new_object

"""
    TclTk.Core.unsafe_convert(T, objptr) -> val

Return a value of type `T` from Tcl object pointer `objptr`.

The `unsafe` prefix on this function indicates that object pointer `objptr` must not be null
and must remain valid during the call to this function.

"""
unsafe_convert(::Type{TclObj}, objptr::ObjPtr) = _TclObj(objptr)
unsafe_convert(::Type{T}, x) where {T} = Base.unsafe_convert(T, x)::T # fallback

# Strings.
#
# There are two alternatives to create Tcl string objects: `Tcl_NewStringObj` or
# `Tcl_NewUnicodeObj`. After some testings, the following works correctly. To build a
# Tcl object from a Julia string, use `Ptr{UInt8}` instead of `Cstring` and provide the
# number of bytes with `ncodeunit(str)`.
#
new_object(str::AbstractString) = new_object(String(str))
function new_object(str::Union{String,SubString{String}})
    # We must preserve `str` because we direct pass its address and size.
    GC.@preserve str begin
        return Tcl_NewStringObj(pointer(str), ncodeunits(str))
    end
end

unsafe_convert(::Type{String}, objptr::ObjPtr) = unsafe_string(objptr)
unsafe_convert(::Type{Symbol}, objptr::ObjPtr) = Symbol(unsafe_string(objptr))

# Symbols are considered as Tcl strings.
new_object(sym::Symbol) = Tcl_NewStringObj(sym, -1)

# Characters are equivalent to Tcl strings of unit length.
new_object(c::AbstractChar) = new_object(string(c))
function unsafe_convert(::Type{T}, objptr::ObjPtr) where {T<:AbstractChar}
    if !isnull(objptr)
        # FIXME Optimize this to avoid allocating a Julia string.
        val = unsafe_string(objptr)
        length(val) == 1 && return convert(T, first(val))
    end
    unsafe_convert_error(T, objptr)
end

# Reals.

function unsafe_convert(::Type{T}, objptr::ObjPtr) where {T<:Real}
    val = unsafe_tryparse(T, objptr)
    val isa T || unsafe_convert_error(T, objptr)
    return val
end

new_object(val::Bool) = Tcl_NewBooleanObj(val)

# In Tcl ≥ 9, non-Boolean integers are stored as `WideInt`.
new_object(val::Integer) = Tcl_NewWideIntObj(val)

# Non-integer reals are considered as double precision floating-point numbers.
new_object(val::Real) = Tcl_NewDoubleObj(val)

# Enumeration are like integers.
new_object(val::Enumeration{T}) where {T} = new_object(Integer(val))
unsafe_convert(::Type{T}, objptr::ObjPtr) where {S,T<:Enumeration{S}} =
    T(unsafe_convert(S, objptr))::T

# Tuples are stored as Tcl lists.
function new_object(tup::Tuple)
    list = new_list()
    try
        for item in tup
            unsafe_append_element(list, item)
        end
    catch
        Tcl_DecrRefCount(list)
        rethrow()
    end
    return list
end

# Dense vector of bytes are stored as Tcl `bytearray` object.
new_object(vec::AbstractVector{UInt8}) = new_object(convert(Memory{UInt8}, vec))
new_object(vec::DenseVector{UInt8}) = Tcl_NewByteArrayObj(vec, length(vec))
function unsafe_convert(::Type{T}, objptr::ObjPtr) where {T<:BasicVector{UInt8}}
    # Assume object is an array of bytes.
    len = Ref{Tcl_Size}()
    ptr = Tcl_GetByteArrayFromObj(objptr, len)
    len = Int(len[])::Int
    vec = T(undef, len)
    len > 0 && GC.@preserve vec unsafe_memcpy(pointer(vec), ptr, len)
    return vec
end
function unsafe_convert(::Type{T}, objptr::ObjPtr) where {E,T<:BasicVector{E}}
    # Assume object is a list.
    A = UnsafeList(objptr)
    B = T(undef, length(A))
    @inbounds for i in eachindex(A, B)
        B[i] = unsafe_convert(E, A[i])
    end
    return B
end

# Convert to fully specified Tuple.
@generated function unsafe_convert(::Type{T}, objptr::ObjPtr) where {N,T<:NTuple{N,Any}}
    types = fieldtypes(T)
    expr = Expr(:tuple, [:(unsafe_convert($(types[i]), A[$i])) for i in 1:N]...,)
    quote
        A = UnsafeList(objptr)
        length(A) == N || unsafe_convert_error(T, objptr)
        return $expr
    end
end

function unsafe_convert(::Type{NothingOr{T}}, objptr::ObjPtr) where {T}
    if !isnull(objptr)
        if T == String
            len = Ref{Tcl_Size}()
            ptr = Tcl_GetStringFromObj(objptr, len)
            iszero(len[]) && return nothing
            return unsafe_string(ptr, len[])
        else
            unsafe_isempty(objptr) && return nothing
            try
                return unsafe_convert(T, objptr)
            catch
                # error is reported below
            end
        end
    end
    unsafe_convert_error(Union{Nothing,T}, objptr)
end

# Yield whether Tcl object at `objptr` is empty. `objptr` must not be null. See
# `Tcl_GetStringFromObj` in `generic/tclObj.c` for the rationale.
function unsafe_isempty(objptr::ObjPtr)
    return !isnull(Tcl_Obj_bytes(objptr)) && iszero(Tcl_Obj_length(objptr))
end

# Generic and error catcher methods for other Julia types.
@noinline new_object(val::T) where {T} =
    argument_error("cannot convert a Julia value of type `$T` to a Tcl object")
@noinline unsafe_convert(::Type{T}, objptr::ObjPtr) where {T} =
    unsafe_convert_error(T, objptr)

@noinline function unsafe_convert_error(::Type{T}, objptr::ObjPtr) where {T}
    io = IOBuffer()
    print(io, "cannot convert ")
    if isnull(objptr)
        print(io, "null Tcl object")
    else
        maxlen = 32
        print(io, "Tcl object \"")
        str = unsafe_string(objptr) # FIXME avoid allocating a huge Julia string
        len = length(str)
        if len ≤ maxlen
            escape_string(io, str)
        else
            start = firstindex(str)
            stop = nextind(str, start, maxlen - 1)
            escape_string(io, SubString(str, start, stop))
            print(io, "[…]")
        end
        print(io, '"')
    end
    print(io, " to Julia value of type `", T, '`')
    argument_error(String(take!(io)))
end

#----------------------------------------------------------------------- Fetching value(s) -

"""
    fetch(T, obj::TclObj) -> x::T
    fetch(T, obj::TclObj, i::Integer) -> x::T
    fetch(T, obj::TclObj, inds) -> x::T

Return a Julia value of type `T` from Tcl object `obj`. With no other argument than `T` and
`obj`, this is exactly the same as calling `convert(T, obj)`. If an index `i` is specified,
the `i`-th element of `obj` (considered as a list) is converted and returned. If indices
`inds` are specified (e.g., an index range), the sub-list `obj[inds]` is converted and
returned.

Compared to `convert(T, obj)`, `convert(T, obj[i])`, or `convert(T, obj[inds])`, calling
`fetch` is more general as `T` can be the type of an object (such as a widget or an image).
For basic types (numbers, string, etc.) and if an index `i` or indices `inds` are specified,
`fetch` is a bit faster than `convert` as temporaries are avoided.

As a special case, if `Nothing` is specified in `T`, then the corresponding value is
returned as `nothing` without attempting any conversion. This may be used to *skip* items
when `obj` is a Tcl list and `T` is a tuple type.

# Examples

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

julia> fetch(Tuple{Bool,Int16,Nothing,Symbol}, x, 1:4)
(false, -7, nothing, :text)

```

`fetch` is useful for implementing a Tcl callback. For example, if `args` is the Tcl object
with the arguments received by a callback bound to an event with `"%W %x %y"`, then:

```julia
w = fetch(Canvas, args, 2)
x = fetch(Int,    args, 3)
y = fetch(Int,    args, 4)
```

retrieves the 2nd, 3rd, and 4th elements of `args` set with the calling widget (here a
canvas) and the pointer position (for a callback, the 1st element of `args` is the name of
the associated Tcl command). This can also be done in a single statement by:

```julia
w, x, y = fetch(Tuple{Canvas,Int,Int}, args, 2:4)
```

# See also

[`TclTk.Callback`](@ref).

"""
function Base.fetch(::Type{T}, obj::TclObj) where {T}
    if T <: TkObject
        # Call the constructor for Tk objects.
        return T(obj)::T
    elseif T <: Nothing
        # Special behavior: do not attempt any conversion.
        return nothing
    else
        # For other types, it is sufficient to call `convert`.
        return convert(T, obj)::T
    end
end

function Base.fetch(::Type{T}, obj::TclObj, ::Colon=:) where {T<:Tuple}
    # To fetch a tuple, the object must be considered as a list.
    GC.@preserve obj begin
        return unsafe_fetch(T, pointer(obj))::T
    end
end

function Base.fetch(::Type{T}, obj::TclObj, i::Integer) where {T}
    # First fetch i-th element of the list to check for bounds error, then fetch a value of
    # type T out of the item.
    GC.@preserve obj begin
        item = unsafe_getindex(obj, i)
        isnull(item) && throw(BoundsError(obj, i))
        return unsafe_fetch(T, item)::T
    end
end

@generated function Base.fetch(::Type{T}, obj::TclObj,
                               inds::Union{AbstractVector{<:Integer},
                                           Tuple{Vararg{Integer}}}) where {N,T<:NTuple{N,Any}}
    # To fetch with indices, the object must be considered as a list.
    types = fieldtypes(T)
    expr = Expr(:tuple, [:(unsafe_fetch($(types[i]), list[inds[off + $i]])) for i in 1:N]...)
    quote
        len = length(inds)
        len == N || argument_error("cannot fetch a $N-tuple from a $len-element Tcl sub-list")
        GC.@preserve obj begin
            list = UnsafeList(pointer(obj))
            off = firstindex(inds)::Int - 1
            return ($expr)::T
        end
    end
end

# `unsafe_fetch` implements `fetch` but for an object pointer.
function unsafe_fetch(::Type{T}, objptr::ObjPtr) where {T}
    if T <: TkObject
        # Call the constructor for Tk objects.
        return T(_TclObj(objptr))::T
    elseif T <: Nothing
        # Special behavior: do not attempt any conversion.
        return nothing
    else
        # Default is to call `unsafe_convert`.
        return unsafe_convert(T, objptr)::T
    end
end

@generated function unsafe_fetch(::Type{T}, objptr::ObjPtr) where {N, T <: NTuple{N,Any}}
    # Convert to fully specified Tuple.
    types = fieldtypes(T)
    expr = Expr(:tuple, [:(unsafe_fetch($(types[i]), list[$i])) for i in 1:N]...)
    quote
        list = UnsafeList(objptr)
        len = length(list)
        len == N || argument_error("cannot fetch a $N-tuple from a $len-element Tcl list")
        return $expr
    end
end

#-------------------------------------------------------------------------- Tcl type names -

"""
    TclTk.Core.unsafe_object_type(objptr) -> sym::Symbol

Return the symbolic type name of Tcl object pointer `objptr`. The result can be:

- `:null` for a null Tcl object pointer.

- `:string` for an unspecific object type (i.e., null type pointer null).

- `:boolean`, `:int`, `:double`, `:wideInt`, `:bignum`, `:bytearray`, `:list`, `:bytecode`,
  etc. for an object with a specific internal representation.

If `objptr` is not null, it must be valid for the duration of the call (i.e., protected form
being garbage collected).

""" unsafe_object_type

# The table of known types is updated while objects of new types are created because seeking
# for an existing type is much faster than creating the mutable `TclObj` structure so the
# overhead is negligible.
const known_types = Tuple{ObjTypePtr,Symbol}[]

function unsafe_object_type(objptr::ObjPtr)
    return isnull(objptr) ? :null : unsafe_object_type(Tcl_Obj_typePtr(objptr))
end

function unsafe_object_type(typePtr::ObjTypePtr)
    global known_types
    for (ptr, sym) in known_types
        ptr == typePtr && return sym
    end
    return unsafe_register_new_typename(typePtr)
end

@noinline function unsafe_register_new_typename(typePtr::ObjTypePtr)
    if isnull(typePtr)
        sym = :string
    else
        # NOTE Type name is a C string at offset 0 of structure `Tcl_ObjType`.
        namePtr = unsafe_load(Ptr{Tcl_ObjType_name_type}(typePtr + Tcl_ObjType_name_offset))
        isnull(namePtr) && unexpected_null("Tcl object type name")
        sym = Symbol(unsafe_string(namePtr))
        sym === :booleanString && (sym = :boolean) # deal with oddities
    end
    push!(known_types, (typePtr, sym))
    return sym
end
