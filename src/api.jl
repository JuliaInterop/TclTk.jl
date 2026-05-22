# Public API of TclTk package.

#--------------------------------------------------------------------------------- Version -

"""
    tcl_version() -> num::VersionNumber
    tcl_version(Tuple) -> (major, minor, patch, release)::NTuple{4,Cint}

Return the full version of the Tcl C library.

In the second above example, `release` is one of: `TCL_ALPHA_RELEASE`, `TCL_BETA_RELEASE`,
or `TCL_BETA_RELEASE`.

"""
function tcl_version()
    major, minor, patch, release = tcl_version(Tuple)
    if release == TCL_ALPHA_RELEASE
        return VersionNumber(major, minor, patch, ("alpha",))
    elseif release == TCL_BETA_RELEASE
        return VersionNumber(major, minor, patch, ("beta",))
    elseif release != TCL_FINAL_RELEASE
        @warn "unknown Tcl release type $release"
    end
    return VersionNumber(major, minor, patch)
end

function tcl_version(::Type{Tuple})
    major = Ref{Cint}()
    minor = Ref{Cint}()
    patch = Ref{Cint}()
    release = Ref{Cint}()
    @ccall Core.libtcl.Tcl_GetVersion(major::Ptr{Cint}, minor::Ptr{Cint},
                                      patch::Ptr{Cint}, release::Ptr{Cint})::Cvoid
    return (major[], minor[], patch[], release[])
end

"""
    tcl_library(; relative::Bool=false) -> dir

Return the Tcl library directory as inferred from the installation of the Tcl artifact. If
keyword `relative` is `true`, the path relative to the artifact directory is returned;
otherwise, the absolute path is returned.

The Tcl library directory contains a library of Tcl scripts, such as those used for
auto-loading. It is also given by the global variable `"tcl_library"` which can be retrieved
by:

    tcl_getvar(String, "tcl_library") -> dir

"""
function tcl_library(; relative::Bool=false)
    major, minor, patch, rtype = tcl_version(Tuple)
    path = joinpath("lib", "tcl$(major).$(minor)")
    relative && return path
    return joinpath(Core.Tcl_jll.artifact_dir, path)
end

#----------------------------------------------------------------------------------- Lists -
function tcl_concat end
function tcl_list end

#--------------------------------------------------------------------------------- Scripts -
function tcl_eval end
function tcl_evalfile end
function tcl_exec end

#------------------------------------------------------------------------------- Variables -

# The following basic methods are implemented in the `Core` module.
function tcl_getvar end
function tcl_isassigned end
function tcl_setvar end
function tcl_unsetvar end

"""
   A = TclVariable{T}(var)

Return a Julia object `A` linked to the global Tcl variable named `var`. The variable value
is given by `A[]` and can be set by `A[] = x`.

Type parameter `T` is the assumed Julia type of the value that can be stored in this
variable. If not specified, `TclObj` is assumed for `T`, hence the variable may store any
type of Tcl object. If variable type parameter is `T = TclObj`, expression `fetch(S, A)`,
with `S` a type, can be used to efficiently convert the value of the variable to type `S`.

Currently, `var` must refer to a simple Tcl variable or to a single element of a Tcl array
(in which case, `name` may be a 2-tuple `(part1, part2)`), not to a Tcl array name.

Property `A.name` yields the name of the Tcl variable.

Call `eltype(A)` to retrieve the type of `A` and `isassigned(A)` or
[`tcl_isassigned(A)`](@ref tcl_isassigned) to check whether `A` has an associated value. To
unset the value of `A`, call `delete!(A)`, [`tcl_unsetvar(A)`](@ref tcl_unsetvar), or do
`A[] = unset`.

Example:

```julia-repl
julia> A = TclVariable{Int}("::GLOBAL_COUNTER")
TclVariable{Int64}(name: "::GLOBAL_COUNTER", value: #undef)

julia> A[] = 0
0

julia> A
TclVariable{Int64}(name: "::GLOBAL_COUNTER", value: 0)

julia> tcl_exec(:incr, A.name, 4) # increment variable with Tcl `incr` command

julia> A[]
4

```

"""
TclVariable(var::VarName) = TclVariable{TclObj}(var)
TclVariable{T}(var::Tuple{2,Name}) where {T} = TclVariable{T}(TclObj("$(var[1])($(var[2]))"))

Base.show(io::IO, ::MIME"text/plain", A::TclVariable) = show(io, A)
function Base.show(io::IO, A::TclVariable{T}) where {T}
    print(io, "TclVariable{", T, "}(name: \"")
    escape_string(io, string(A.name))
    print(io, "\", value: ")
    if isassigned(A)
        show(io, A[])
    else
        print(io, "#undef")
    end
    print(io, ")")
end

Base.eltype(::Type{TclVariable{T}}) where {T} = T

Base.isassigned(A::TclVariable) = tcl_isassigned(A.name)
tcl_isassigned(A::TclVariable) = isassigned(A)

Base.getindex(A::TclVariable{T}) where {T} = tcl_getvar(A)
Base.fetch(::Type{T}, A::TclVariable) where {T} = tcl_getvar(T, A)
tcl_getvar(A::TclVariable{T}) where {T} = tcl_getvar(T, A)
tcl_getvar(::Type{T}, A::TclVariable{<:Union{T,TclObj}}) where {T} = tcl_getvar(T, A.name)

function Base.setindex!(A::TclVariable, x)
    tcl_setvar(A, x)
    return A
end
tcl_setvar(A::TclVariable, x) = tcl_setvar(Nothing, A, x)
tcl_setvar(::Type{T}, A::TclVariable, x) where {T} = tcl_setvar(T, A.name, x)

Base.delete!(A::TclVariable) = tcl_unsetvar(A; nocomplain=true)
tcl_unsetvar(A::TclVariable; kwds...) = tcl_unsetvar(A.name; kwds...)

#------------------------------------------------------------------------------- Callbacks -
function deletecommand end

#---------------------------------------------------------------------------- Quote string -

"""
    tcl_quote_string(str)

Return string `str` a valid Tcl string surrounded by double quotes that can be directly
inserted in Tcl scripts.

This is similar to `escape_string` but specialized to represent a valid Tcl string
surrounded by double quotes in a script.

"""
function tcl_quote_string(str::AbstractString)
    esc = ('"', '{', '}')
    io = IOBuffer()
    print(io, '"')
    for c::AbstractChar in str
        if c ∈ esc
            print(io, '\\', c)
        elseif isascii(c)
            if isprint(c)
                if c == '\\'
                    print(io, "\\\\")
                else
                    print(io, c)
                end
            elseif c == '\0'
                print(io, "\300\200") # see man page of `Tcl_NewStringObj`
            elseif '\a' <= c <= '\r'
                print(io, '\\', "abtnvfr"[Int(c)-6])
            else
                print(io, "\\x", string(UInt32(c), base = 16, pad = 2))
            end
        elseif !Base.isoverlong(c) && !Base.ismalformed(c) && isprint(c)
            print(io, c)
        else # malformed, overlong, or not printable
            u = bswap(reinterpret(UInt32, c)::UInt32)
            while true
                print(io, "\\x", string(u % UInt8, base = 16, pad = 2))
                (u >>= 8) == 0 && break
            end
        end
    end
    print(io, '"')
    return String(take!(io))
end

#---------------------------------------------------------------------------------- Errors -

Base.showerror(io::IO, ex::TclError) = print(io, "Tcl/Tk error: ", ex.msg)

"""
    TclError(args...)

Return a `TclError` exception with error message given by `string(args...)`.

"""
@noinline TclError(args...) = TclError(string(args...))

"""
    tcl_error(args...)

Throw a `TclError` exception with error message given by `string(args...)`.

"""
tcl_error(args...) = throw(TclError(args...))

#--------------------------------------------------------------------------------- Widgets -

function cget end
function configure end
function grid end
function pack end
function place end
function winfo end
function wm end

#--------------------------------------------------------------------------------- Dialogs -

function tk_choosecolor end
function tk_choosedirectory end
function tk_getopenfile end
function tk_getopenfiles end
function tk_getsavefile end
function tk_messagebox end

#---------------------------------------------------------------------------------- Images -

function expand! end
