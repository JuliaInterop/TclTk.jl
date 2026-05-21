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
    return joinpath(Tcl_jll.artifact_dir, path)
end

#----------------------------------------------------------------------------------- Lists -
function tcl_concat end
function tcl_list end

#--------------------------------------------------------------------------------- Scripts -
function tcl_eval end
function tcl_evalfile end
function tcl_exec end

#------------------------------------------------------------------------------- Variables -
function tcl_getvar end
function tcl_isassigned end
function tcl_setvar end
function tcl_unsetvar end

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
            elseif c == '\e'
                print(io, "\\e")
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
@noinline TclError(arg, args...) = TclError(string(arg, args...))

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

"""
    TclTk.wm(T=Nothing, cmd, w::TkWidget, args...; kwds...) -> res::T
    wm.cmd(T, w::TkWidget, args...; kwds...) -> res::T
    wm.cmd(w::TkWidget, args...; kwds...) -> res

Interact with the window manager to query or control such things as the title for widget
`w`, its geometry, etc. Argument `T` is the expected type for the result. With the syntax
`wm.cmd(w, ...)` the result has a suitable default type that depends on `cmd`.

The window manager command `cmd` is one of ...

"""
function wm end

#--------------------------------------------------------------------------------- Dialogs -

function tk_chooseColor end
function tk_chooseDirectory end
function tk_getOpenFile end
function tk_getSaveFile end
function tk_messageBox end
