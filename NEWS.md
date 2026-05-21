# User visible changes in `Tcl`

This page describes the most important changes in `Tcl`. The format is based on [Keep a
Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic
Versioning](https://semver.org).

## Unreleased

### Breaking changes

- Since a Tcl interpreter can only be used in the thread where it lives and since, for
  common usage, there is no point in having multiple interpreters, there is now a single
  interpreter shared by all tasks. In the public API, the Tcl interpreter is never
  explicitly specified. When Tcl code is to be evaluated, the calling thread communicates
  with the sticky task which manages the interpreter to have the code evaluated. A similar
  solution is implemented by [Julia Tk package](http://github.com/JuliaGraphics/Tk.jl). See
  [this link](https://github.com/JuliaInterop/TclTk.jl/issues/9) for a discussion. As a
  result, `TclTk.getresult`, `TclTk.setresult!`, `TclTk.isrunning`, `TclTk.resume`,
  `TclTk.suspend`, `TclTk.do_events`, `TclTk.do_events`, and `tk_start` are no longer needed
  and have been removed.

- Widget types are no longer prefixed by `Tk` of `Ttk`. For example, use `Canvas` instead of
  `TkCanvas`. When a type of widget exists in the two packages, the themed one is preferred
  (formerly prefixed with `Ttk`). If another type is preferred, it can still be prefixed by
  the corresponding module. For example, `TclTk.Tk.Button` if `Button` (which is a shortcut
  to `TclTk.Ttk.Button`) does not suit your needs. The Perl script
  [`new_widget_names.pl`](tools/new_widget_names.pl) can be used to convert the widget
  names.

- Out of range indices in lists of Tcl objects are no longer allowed.

- `w.rgb(color)` with `w` a widget now return an `RGB{N0f16}` value instead of a triplet of
  `UInt16`.

- Many public symbols are now prefixed and exported: `TclTk.list` becomes `tcl_list`,
  `TclTk.concat` becomes `tcl_concat`, `TclTk.quote_string` becomes `tcl_quote_string`,
  `TclTk.eval` becomes `tcl_eval`, `TclTk.exec` becomes `tcl_exec`, `TclTk.setvar` becomes
  `tcl_setvar`, `TclTk.getvar` becomes `tcl_getvar`, `TclTk.unsetvar` becomes
  `tcl_unsetvar`, `TclTk.exists` becomes `tcl_isassigned`, and `TclTk.Variable` becomes
  `TclVariable`.

- `list[i => T]`, `list[T, i]`, and `list[i, T]` to retrieve the `i`-th item of the Tcl `list`
  converted to type `T` is now done by `fetch(T, list, i)`.

- To follow Julia conventions, Tk dialog methods are in lowercase: `tk_messageBox`,
  `tk_getOpenFile`, `tk_getSaveFile`, `tk_chooseColor`, and `tk_choosedirectory` renamed as
  `tk_messagebox`, `tk_getopenfile`, `tk_getsavefile`, `tk_choosecolor`, and
  `tk_choosedirectory`.

- `tk_getopenfile` no longer allow for multiple selections, all `tk_getopenfiles` for that.

### Added

- New `wm` function for interacting with the window manager. This function accepts
  sub-commands. For example, `wm.title(w, "Window Title")` to specify the title of the top
  level window `w`.

- Top-level widgets have a default icon set with the logo displayed in the documentation.

- The title of a top-level widget `w` can be queried by `w.title()` and set by
  `w.title("New Title")`.

- Extend `fetch` to retrieve a Julia value or object (possibly living in a Tcl interpreter)
  from a Tcl object possibly sub-indexed. Compared to `convert(T, obj)`, `convert(T,
  obj[i])`, or `convert(T, obj[inds])`, calling `fetch` is more general as `T` can be the
  type of an object (such as a widget or an image) that lives in an interpreter and a bit
  faster as `fetch` avoids temporaries.

### Optimized

- After Tk and Ttk packages have been loaded, `tk_start` runs much faster.


## Version 0.3.0 (2026-03-04)

### Breaking changes

- `TclTk.setvar!` and `TclTk.unsetvar!` replace `TclTk.setvar` and `TclTk.unsetvar` which
  are deprecated.

- 2-part Tcl variable names (a.k.a. Tcl *arrays*) are specified as 2-tuple on the Julia
  side. Specifying such names as two arguments has been deprecated. This was needed for the
  coherence of base methods like `haskey` or `delete!`.

- The default type when retrieving the result stored by an interpreter is `TclObj` (was
  `String`).

- The package uses artifacts `Tcl_jll` and `Tk_jll` to avoid a build step.

- Using a leading underscore for a keyword in calls to `TclTk.exec` (and all methods based
  on it) is no longer a mean to specify an option that is a reserved Julia word. There are
  different possibilities: (i) specify 2 arguments `"-option"` followed by `value` or (ii)
  specify a pair `"option" => value` or `:option => value`.

- If a result is expected and wanted by the caller of `TclTk.eval` and `TclTk.exec`, the
  return type **must** be specified as a first argument; otherwise, `Nothing` is assumed.
  Specific methods that call `TclTk.exec` may have another default type which follows
  logically from the behavior of the method. For example and for a widget `w`,
  `w.configure()` and `w.configure(opt)` return a `TclObj` instance by default as a result
  is expected, while `w.configure(opt=val,...)` returns `nothing`, `TclTk.cget` returns a
  `TclObj` by default, etc. This simplifies a lot of (optimized) calls to these methods.

### Added

- Tcl/Tk options `-key val` in commands can be produced by `key => val` pair arguments or by
  keywords `key=val` in calls to `TclTk.exec` where `key` is a string or a symbol. Using
  pairs instead of keywords may be a matter of style but also a way to specify options that
  are reserved Julia words and, thus, cannot be used for keywords in function calls.

- Abstract vector API for lists of Tcl objects.

- `interp[] = result` to set interpreter's result.

- Checking for equality of instances of `TclInterp`, `TkWidget`, and `TkImage`.

- Non-exported public functions `TclTk.isactive`, `TclTk.isdeleted`, and `TclTk.issafe`.

- Enumerations can be stored as integer Tcl objects and can be retrieved from integer Tcl
  objects.

- `TkPhoto(arr)` returns a Tk image whose pixels are set according to the elements of the
  2-dimensional array `arr`.

- Tests with [`Aqua.jl`](https://github.com/JuliaTesting/Aqua.jl).

- Indexing a Tcl list object can take a type `T` to convert the result to that type. This is
  done by the following statements: `list[i,T]`, `list[T,i]`, or `list[i => T]`. There are
  two advantages: type-stability (the type of the result is inferable) and, compared to
  `convert(T, list[i])`, speed (this avoids allocating a mutable `TclObj` instance).

- `convert` can convert a Tcl list object to a n-tuple.

- `A = TclTk.Variable{T}(name)` yields an object `A` representing the Tcl variable `name`
  with value type `T`. Then, `A[]` yields the value of the Tcl variable (converted to `T`)
  while `A[] = x` mutates the value of the variable.

- Widgets and images can be indexed by option name (leading hyphen can be omitted) to access
  and mutate their configurable options.

- Widgets and images implement sub-commands by the syntax `obj.cmd(args...; kwds...)`.

- An existing widget can be wrapped into a `TkWidget` structure of type `T` with
  `T(interp=TclInterp(), path)` where `path` is the full widget path. `T` may be `TkWidget`
  or a concrete type corresponding to the class of the existing widget.

- Widgets have many more properties reflecting all information that can be given by `winfo`.
  For example, `w.children` yields the ames of the children of `w` or `w.containing(x, y)`
  yields the path name of the widget containing the point at pixel `(x, y)` in the screen of
  `w`.

- More meaningful return value for the `configure` (sub-)command: `TclObj` for
  `w.configure()` or `w.configure(opt)` since a result is expected. `Nothing` for other
  cases (i.e., when there are specified options). This also fixes a bug in
  `TclTk.configure`.


### Fixed

- Indexation of lists of Tcl objects by a vector of Booleans.

- Getting value of a global Tcl variable with a 2-part name.

- Names of Tcl global variables can also be a (real) number.

- Conversion of Tcl objects to/from vectors. If element type is `UInt8`, the byte vector is
  considered to represent the raw content of the Tcl object.

- Some bug fixed with Tk images.

- Type inference fixed for `TclTk.Impl.unsafe_convert(T, objptr)` which yields a value of
  type `T` or throws.

## Version 0.2.0 (2026-02-17)

### Breaking changes

- Instances of `TclObj` no longer have a type parameter as the *type* of a Tcl object
  reflects a cached internal state that may change for efficiency.

- `Tcl.getvalue(obj)` has been replaced by `convert(T, obj)` to get a value of given type
  `T` from Tcl object `obj`.

- List-specialized methods (`llength`, `lappend!`, and `lindex`) have been suppressed in
  favor of the Julia API for collections. Thus, `length`, `append!`, `push!`, `delete!`,
  `getindex`, and `setindex!` shall be used to access Tcl objects as if they are lists.

- `Tcl.getinterp()` has been replaced by `TclInterp()`.

- `Tcl.setresult` has been replaced by `Tcl.setresult!`.

### Fixed

- Raw pointers in C calls are protected by having their owner object preserved from being
  garbage collected.

- Getting a single char from a Tcl object works for multi-byte sequences.

- To protect the content of shared objects, Tcl imposes a strict copy-on-write policy. Not
  following this policy causes Tcl to panic (i.e., abort the program). To avoid this,
  attempts to modify a shared Tcl object are detected and forbidden by throwing an
  exception.

### Changed

- By default, the package uses artifacts `Tcl_jll` and `Tk_jll`. To use other libraries, one
  can set the environment variables `ENV["JL_TLIBTCL"]` and `ENV["JL_TLIBTK"]` to the
  absolute paths of these libraries before calling `pkg> update Tcl` and `pkg> build Tcl`.

- `Tcl.doevents` has been deprecated and replaced by `Tcl.do_events` which returns the
  number of processed events.

- Following Tcl behavior, `obj[i]` yields `missing` if index `i` is out of range.

### Added

- `interp(args...)`, `interp.exec(args...)`, and `Tcl.exec(interp, args...)` execute a Tcl
  command. thing.

- `interp.eval(args...)` and `Tcl.eval(interp, args...)` concatenate arguments and evaluate
  a Tcl script.

- `Tcl.do_one_event(flags)` to process any pending events matching `flags`.

- `TclInterp` constructor can yield the shared interpreted for the thread of the caller or a
  new private interpreter.

- `Tcl.quote_string(str)` yields a proper double-quoted string that can be inserted directly
  in Tcl scripts.

- A Tcl variable may be unset (or deleted) by meany different means (at the user
  convenience). For example: `Tcl.unset(interp, name)`, `Base.delete!(interp, name)`, or
  `interp[name] = unset` (where `unset` is the singleton provided by the `UnsetIndex`
  package and exported by the `Tcl` package).

- Like `String`, common type constructors (`Bool`, `Int`, `Float64`, `Vector{T}`,
  `Memory{T}`, etc.) can also be directly used to convert a Tcl object.

- `tryparse(T, obj)` can be used to attempt converting the content of a Tcl object `obj` to
  a Julia numeric value of type `T`.
