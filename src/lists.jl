# TODO: Tcl_IncrRefCount -> preserve
# TODO: Tcl_DecrRefCount -> release
# TODO: Tcl_ListObjIndex -> @ccall

"""
     tcl_list(args...) -> list::TclObj

Return a list of Tcl objects such that each of `args...` is a single element of the returned
list. This mimics the behavior of the Tcl `list` command.

# See also

[`tcl_concat`](@ref), [`tcl_eval`](@ref), and [`TclObj`](@ref).

"""
function tcl_list(args...)
    list = new_list()
    try
        for arg in args
            unsafe_append_element(list, arg)
        end
        return _TclObj(list)
    catch ex
        Tcl_DecrRefCount(list)
        rethrow(ex)
    end
end

"""
    tcl_concat(args...) -> list::TclObj

Return a list of Tcl objects obtained by concatenating the elements of the arguments
`arg...` each being considered as a list. This mimics the behavior of the Tcl `concat`
command.

# See also

[`tcl_list`](@ref), [`tcl_eval`](@ref), and [`TclObj`](@ref).

"""
function tcl_concat(args...)
    list = new_list()
    try
        for arg in args
            unsafe_append_list(list, arg)
        end
        return _TclObj(list)
    catch ex
        Tcl_DecrRefCount(list)
        rethrow(ex)
    end
end

Base.IteratorSize(::Type{TclObj}) = Base.HasShape{1}()

Base.length(obj::TclObj) = GC.@preserve obj unsafe_length(pointer(obj))

Base.isempty(obj::TclObj) = length(obj) < 𝟙

Base.size(obj::TclObj) = (length(obj),)

# When iterated or indexed, a Tcl object yield Tcl objects.
Base.IteratorEltype(::Type{TclObj}) = Base.HasEltype()
Base.eltype(::Type{TclObj}) = TclObj

Base.firstindex(obj::TclObj) = 1
Base.lastindex(obj::TclObj) = length(obj)

Base.IndexStyle(obj::TclObj) = IndexStyle(typeof(x))
Base.IndexStyle(::Type{TclObj}) = IndexLinear()

Base.keys(obj::TclObj) = 𝟙:length(obj)

Base.first(obj::TclObj) = obj[firstindex(obj)]
Base.last(obj::TclObj) = obj[lastindex(obj)]

function Base.getindex(obj::TclObj, index::Integer)
    GC.@preserve obj begin
        objptr = unsafe_getindex(obj, index)
        isnull(objptr) && throw(BoundsError(obj, index))
        return _TclObj(objptr)
    end
end

function Base.getindex(obj::TclObj, inds::AbstractVector{<:Integer})
    GC.@preserve obj begin
        A = UnsafeList(pointer(obj))
        result = new_list()
        try
            for i in inds
                checkbounds(A, i)
                unsafe_append_element(result, @inbounds A[i])
            end
        catch
            Tcl_DecrRefCount(result)
            rethrow()
        end
        return _TclObj(result)
    end
end

function Base.getindex(obj::TclObj, flags::AbstractVector{Bool})
    GC.@preserve obj begin
        A = UnsafeList(pointer(obj))
        length(flags) == length(A) || dimension_mismatch(
            "attempt to index $(length(A))-element Tcl list by $(length(flags))-element vector of `Bool`")
        result = new_list()
        offset = firstindex(flags) - firstindex(A)
        try
            @inbounds for i in eachindex(A)
                if flags[offset + i]
                    unsafe_append_element(result, A[i])
                end
            end
        catch
            Tcl_DecrRefCount(result)
            rethrow()
        end
        return _TclObj(result)
    end
end

# NOTE Julia `push!` is similar to Tcl `lappend` command.
function Base.push!(obj::TclObj, args...)
    GC.@preserve obj begin
        objptr = pointer(obj)
        for arg in args
            unsafe_append_element(objptr, arg)
        end
    end
    return obj
end

# NOTE Julia `append!` is similar to Tcl `concat` command.
function Base.append!(obj::TclObj, args...)
    GC.@preserve obj begin
        objptr = pointer(obj)
        for arg in args
            unsafe_append_list(objptr, arg)
        end
    end
    return obj
end

function Base.iterate(obj::TclObj, (itr,i)::Tuple{ListIterator,Int}=(ListIterator(obj),1))
    GC.@preserve itr begin
        A = itr.list # retrieve unsafe list
        checkbounds(Bool, A, i) || return nothing
        item = _TclObj(@inbounds A[i])
        return item, (itr, i + 1)
    end
end

function unsafe_length(objptr::ObjPtr)
    isnull(objptr) && return 0
    len = Ref{Tcl_Size}()
    Tcl_ListObjLength(null(InterpPtr), objptr, len) == TCL_OK || invalid_list()
    return Int(len[])::Int
end

@noinline invalid_list() = tcl_error("Tcl object is not a valid list")

function unsafe_getindex(obj::Union{TclObj,ObjPtr}, index::Integer)
    objref = Ref{ObjPtr}(0)
    if index ≥ 𝟙
        status = Tcl_ListObjIndex(C_NULL, obj, index - 𝟙, objref)
        status == TCL_OK || invalid_list()
    end
    return objref[]
end

"""
    TclTk.Impl.UnsafeList(objptr::ObjPtr) -> A

Return a vector of pointers to Tcl objects to access the content of `objptr` considered as a
pointer to a Tcl list of objects.

If `objptr` is null, the returned vector `A` is empty. Otherwise, the caller is responsible
of insuring that `objptr` remains valid while `A` is in use.

The returned vector may be indexed for reading: `A[i]` yields a pointer to the `i`-th object
of the list but `A[i] = x` is forbidden.

"""
function UnsafeList(objptr::ObjPtr)
    objc = Ref(zero(Tcl_Size))
    objv = Ref(null(Ptr{ObjPtr}))
    if !isnull(objptr)
        status = Tcl_ListObjGetElements(C_NULL, objptr, objc, objv)
        status == TCL_OK || tcl_error("failed to retrieve Tcl list elements")
    end
    return UnsafeList(objv[], objc[])
end

# Abstract vector API.
Base.pointer(A::UnsafeList) = A.objv
Base.length(A::UnsafeList) = A.objc
Base.size(A::UnsafeList) = (length(A),)
Base.IndexStyle(::Type{UnsafeList}) = IndexLinear()
Base.firstindex(A::UnsafeList) = 1
Base.lastindex(A::UnsafeList) = length(A)

@inline function Base.getindex(A::UnsafeList, i::Int)
    @boundscheck checkbounds(A, i)
    return unsafe_load(pointer(A), i)
end

function Base.setindex!(obj::TclObj, value, index::Integer)
    i = Int(index)::Int
    GC.@preserve obj value begin
        # With `index < 1`, Tcl would insert the value at the beginning of the list. With
        # `index > length(obj)`, Tcl would append the value to the end of the list. This
        # behavior is unusual for Julia and we impose that `index` be in bounds.
        objptr = pointer(obj)
        firstindex(obj) ≤ i ≤ unsafe_length(objptr) || throw(BoundsError(obj, i))
        # The ref. count is incremented and finally decremented, to protect against
        # exceptions that may be thrown by `unsafe_replace_list`.
        valptr = Tcl_IncrRefCount(unsafe_objptr(value))
        try
            unsafe_replace_list(objptr, i - 1, 1, 1, Ref(valptr))
        finally
            Tcl_DecrRefCount(valptr)
        end
    end
    return obj
end

function Base.delete!(obj::TclObj, index::Integer)
    if index ≥ 𝟙
        GC.@preserve obj begin
            unsafe_replace_list(pointer(obj), index - 𝟙, 1, 0, C_NULL)
        end
    end
    return obj
end

# NOTE In `Tcl_ListObjReplace` applied to destination `list` considered as a list:
#
# * If `first ≥ length(obj)`, no elements are deleted and the objects in `objv` are appended
#   to the list.
#
# * If `first ≤ 0` it is assumed to be `0`, that is the index of the first list element.
#
# * If `count ≤ 0` or `first ≥ length(list)`, no elements are deleted.
#
# * The objects in `objv` are inserted before index `first` replacing the `count` elements
#   of the list initially stored at and after index `first`.
#
# Thus, `Tcl_ListObjReplace` can be used to append, prepend, or insert elements and, at the
# same time, possibly delete elements.
#
function unsafe_replace_list(list::ObjPtr, first::Integer,
                             count::Integer, objc::Integer, objv)
    assert_writable(list) # required by Tcl copy-on-write policy
    status = @ccall libtcl.Tcl_ListObjReplace(
        C_NULL::Ptr{Tcl_Interp}, list::Ptr{Tcl_Obj}, first::Tcl_Size, count::Tcl_Size,
        objc::Tcl_Size, objv::Ptr{Ptr{Tcl_Obj}})::TclStatus
    status == TCL_OK || tcl_error("failed to replace Tcl list element(s)")
    return nothing
end

"""
    TclTk.Impl.new_list() -> list

Return a pointer to a Tcl object storing an empty list.

    TclTk.Impl.new_list(f, args...) -> list

Return a pointer to a Tcl object storing a list built by calling `f(list, arg)` for each
`arg` in `args...`. Typically, `f` is [`TclTk.Impl.unsafe_append_element`](@ref) or
[`TclTk.Impl.unsafe_append_list`](@ref).

!!! warning
    The returned object is not managed and has a zero reference count. The caller is
    responsible of taking care of that.

"""
new_list() = Tcl_NewListObj(0, C_NULL)

# Build a list from a given vector of objects. FIXME unused?
function new_list(objc::Integer, objv::Ptr{Ptr{Tcl_Obj}})
    return new_list(unsafe_append_element, objc, objv)
end

function new_list(f::Function, args...)
    list = new_list()
    try
        for arg in args
            f(list, arg)
        end
    catch
        Tcl_DecrRefCount(list) # free list object
        rethrow()
    end
    return list
end

function new_list(f::Function, objc::Integer, objv::Ptr{Ptr{Tcl_Obj}})
    list = new_list()
    try
        for i in 1:objc
            f(list, unsafe_load(objv, i))
        end
    catch
        Tcl_DecrRefCount(list) # free list object
        rethrow()
    end
    return list
end

# Appending a new item to a list with `Tcl_ListObjAppendElement` or `Tcl_ListObjAppendList`
# increments the reference count of the item, this is the only side effect for the item.
# That is to say, the appended item is not duplicated, just shared. So, to manage the memory
# associated with the item, we can increment its reference count before appending and
# decrement it after with no measurable effects on the performances (but useful to free
# object in case of errors). Incrementing and decrementing the reference count is not
# necessary for a managed object but such an object must be preserved from being garbage
# collected.

"""
    TclTk.Impl.unsafe_append_element(list, item) -> nothing

Private method to append `item` as a single element to the Tcl object `list`.

The following conditions are asserted: `list` must be *writable* (i.e., a non-null pointer
to a non-shared Tcl object) and `item` must be *readable* (i.e., a non-null pointer to a Tcl
object).

!!! warning
    Unsafe method: `list` and `item` must remain valid during the call to this method (e.g.,
    preserved from being garbage collected).

!!! warning
    The method may throw and the caller is responsible of managing the reference count of
    `item` to have it automatically deleted in case of errors if it is a fresh object
    created by `new_object(val)`.

# See also

[`TclTk.Impl.unsafe_append_list`](@ref) and [`TclTk.Impl.new_list`](@ref).

"""
function unsafe_append_element(list::ObjPtr, arg)
    unsafe_append(Tcl_ListObjAppendElement, list, arg)
end

"""
    TclTk.Impl.unsafe_append_list(list, iter) -> nothing

Private method to concatenate the elements of `iter` to the end of the Tcl object `list`.

# See also

[`TclTk.Impl.unsafe_append_element`](@ref) and [`TclTk.Impl.new_list`](@ref).

"""
function unsafe_append_list(list::ObjPtr, arg)
    unsafe_append(Tcl_ListObjAppendList, list, arg)
end

function unsafe_append_list(list::ObjPtr, iter::Tuple)
    for item in iter
        unsafe_append_element(list, item)
    end
end

# NOTE The computational burden of `Tcl_ListObjAppendElement` and
# `Tcl_ListObjAppendList` is such that not incrementing and finally decrementing the
# reference count of a wrapped object is a negligible optimization.
function unsafe_append(f::Union{typeof(Tcl_ListObjAppendElement),
                                typeof(Tcl_ListObjAppendList)},
                       list::ObjPtr, arg)
    assert_writable(list) # required by copy-on-write policy
    objptr = if arg isa WrappedObject
        unsafe_objptr(arg)
    elseif arg isa Function
        # Setting a callback involves (i) passing the name of the corresponding Tcl
        # command and (ii) creating this command in the target interpreter if it
        # does not exists.
        tcl_error("appending a callback is not yet implemented")
    else
        Tcl_IncrRefCount(unsafe_objptr(arg))
    end
    status = f(C_NULL, list, objptr)
    arg isa WrappedObject || Tcl_DecrRefCount(objptr)
    status == TCL_OK || tcl_error(f)
    return nothing
end

tcl_error(::typeof(Tcl_ListObjAppendElement)) =
    tcl_error("failed to append item to Tcl list")

tcl_error(::typeof(Tcl_ListObjAppendList)) =
    tcl_error("failed to concatenate Tcl lists")
