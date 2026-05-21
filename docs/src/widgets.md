# Widgets

## Widget creation

### Top-level widgets

A top-level or a menu widget are created by:

```julia
top = Toplevel([path,] pairs...; kwds...)
menu = Menu([path,] pairs...; kwds...)
```

where `path` is a string like `".top"` or `".menu"` (it must start with a dot and have no
other dots). Arguments `pairs...` and keywords `kwds...` denotes any number of settings
specified as `option => value` pair or `option=value` keyword with `option` an option name
and `value` the option value (for pairs, `option` may be a string or a symbol and the
leading hyphen can be omitted). The `path` argument is optional; if omitted, a widget path
is automatically generated in the form `".$(pfx)$(num)"` where `pfx` is a short prefix
specific to the widget class and `num` is a unique number.

The widget path (given by `w.path` for a widget `w`) is also the name of the Tcl command
implementing the widget behavior and is used for any reference to the widget.

For example, using keywords:

```julia-repl
julia> top = Toplevel(relief="sunken", borderwidth=5, background="cyan")
Toplevel(".top3")

```

or using pairs:

```julia-repl
julia> top = Toplevel(:relief => "sunken", :borderwidth => 5, :background => "cyan")
Toplevel(".top3")

```

Mixing configuration options specified as pairs and keywords but is allowed but not
recommended for readability.

Symbols can also be specified as literal strings and conversely. Thus, `:relief => :sunken`,
`"relief" => "sunken"`, and `:relief => "sunken"` are all the same.


### Other widgets

Non-top level widgets have a parent (a top-level widget, a frame, etc.) which must be
provided to the constructor. For example, a label is created by something like:

```julia
lab = Label(parent, [child,] pairs...; kwds...)
```

where `child` is the path of the widget relative to its parent, it must have no dots. The
relative path, `child`, is optional and is automatically generated if omitted.

The path of the widget is the concatenation of its parent path and the widget relative path
with a dot separator. The widget path is given by the property `w.path` for a widget `w`.
The widget path is unique, if a widget constructor is called with a path of an existing
widget, a Julia object wrapping the same Tk widget is returned. However, the constructor
must correspond to the class of the existing widget. To relax this, a widget instance can be
built for an existing widget by calling the abstract constructor `TkWidget`:

```julia
w = TkWidget(path)
w = TkWidget(parent, child)
```

The latter case is equivalent to have `path = "$(parent).$(child)"` in the former case.


## Widget properties

The syntax `w.key` yields the property `key` for a widget `w`. Available properties are
those managed by the `winfo` Tk command plus the `w.path` property which yields the full
path of the widget `w` (as a Tcl object). Some properties require additional argument. The
list of properties is:

```julia
w.atom(name)       # identifier of atom named `name` in the display of `w`
w.atomname(id)     # textual name of atom identified by `id` in the display of `w`
w.cells            # number of cells in the color map of `w`
w.children         # list of paths of all children of `w`
w.class            # symbolic class name of `w`
w.colormapfull     # whether the colormap of `w` is known to be full
w.containing(x,y)  # path of widget containing point `(x,y)` in the display of `w`
w.depth            # depth of widget `w` (number of bits per pixel).
w.exists           # whether widget with the poath of `w` exists
w.fpixels(d)       # fractional number of pixels in `w` corresponding to distance `d`
w.geometry         # geometry of `w`, in the form `widthxheight+x+y` (un pixels)
w.height           # height of `w` in pixels
w.id               # low-level platform-specific identifier of widget `w`
w.interps          # list of names of all Tcl interpreters for the display of `w`
w.ismapped         # whether `w` is currently mapped
w.manager          # symbolic name of geometry manager currently responsible of `w`
w.name             # name of `w` within its parent
w.parent           # path of parent of `w`
w.path             # path name of `w` (a Tcl object instance)
w.pathname(id)     # path name of the window whose identifier is `id` in the display of `w`
w.pixels(d)        # integer (rounded) number of pixels in `w` corresponding to distance `d`
w.pointerx         # pointer's `x` coordinate if in the same screen as `w`, `-1` otherwise
w.pointeryx        # pointer's coordinates `(x,y)` if in the same screen as `w`, `(-1,-1)` otherwise
w.pointerx         # pointer's `x` coordinate if in the same screen as `w`, `-1` otherwise
w.reqheight        # requested height for `w` instead of its actual height
w.reqwidth         # requested width for `w` instead of its actual width
w.rgb(c)           # colorant corresponding to color `c`, e.g. "gray" or "#234"
w.rootx            # `x`-coordinate of upper-left corner of the border of `w` in its screen
w.rootx            # `y`-coordinate of upper-left corner of the border of `w` in its screen
w.screen           # name of the screen of `w`
w.screencells      # number of cells in the default colormap of the screen of `w`
w.screendepth      # depth (number of bits per pixel) of the screen of `w`
w.screenheight     # height of of the screen of `w`, in pixels
w.screenmmheight   # height of of the screen of `w`, in millimeters
w.screenmmwidth    # width of of the screen of `w`, in millimeters
w.screenvisual     # default visual class of the screen of `w`
w.screenwidth      # width of of the screen of `w`, in pixels
w.server           # infromation about server of the display of `w`
w.toplevel         # path of the top-of-hierarchy widget containing `w`
w.viewable         # whether `w` and all of its ancestors up through the nearest toplevel are mapped
w.visual           # visual class of `w`
w.visualid         # identifier of the visual class of `w`
w.visualsavailable # list of available visual classes and associated depths (bits per pixel)
w.visualsavailable_includeids # list of available visual classes, associated depths, and identifiers
w.vrootheight      # height of the virtual root window (or screen if none) of `w`
w.vrootwidth       # width of the virtual root window (or screen if none) of `w`
w.vrootx           # `x`-offset of the virtual root window associated with `w`
w.vrooty           # `y`-offset of the virtual root window associated with `w`
w.width            # width of `w` in pixels
w.x                # `x`-coordinate of the upper-left corner of the border of `w` in its parent
w.y                # `y`-coordinate of the upper-left corner of the border of `w` in its parent
```

The visual class is one of the following symbolic names: `:directcolor`, `:grayscale`,
`:pseudocolor`, `:staticcolor`, `:staticgray`, or `:truecolor`.

Using properties is more readable than executing the corresponding Tk `winfo` command. Using
the [`tcl_exec`](@ref) method, `w.class` and `w.atomname(id)` are shortcuts for:

```julia
tcl_exec(Symbol, "winfo", "class", w)
tcl_exec(String, "winfo", "atomname", "-displayof", w, id)
```

or with the [`tcl_eval`](@ref) method:

```julia
tcl_eval(Symbol, "winfo class", w)
tcl_eval(String, "winfo atomname -displayof", w, id)
```


## Widget sub-commands

Tk widgets may be invoked to execute sub-commands (the list of which depends on the widget
type). There are different equivalent ways to call a widget sub-command:

```julia
tcl_exec(T=Nothing, widget, subcmd, args...; kdws...)
widget(T=Nothing, subcmd, args...; kdws...)
widget.subcmd(T=Nothing, args...; kdws...)
```

where `widget` is a widget instance, optional leading argument `T` is the expected type of
the result (a Tcl object by default), `subcmd` is the sub-command name (a string, a symbol,
or a Tcl object) and `args...` are the arguments of the sub-command. Compared to properties
(described above) which yields a value of a specific type, most sub-commands return
`nothing` by default. Another return type `T` can be specified. If the returned type is not
known in advance, `T` can be set to `TclObj` or `String`.

For example, retrieving the text associated with a button widget `btn` can be done by one
of:

```julia
tcl_exec(String, btn, :cget, "-text")
btn(String, :cget, "-text")
btn.cget(String, "-text")
```

The `cget` sub-command is special, the leading hyphen in the option name is optional and
the above examples are equivalent to:

```julia
btn.cget(String, "text")
btn.cget(String, :text)
```

The default returned type for the `cget` sub-command is `TclObj`.

Another possibility could be to evaluate a Tcl script as in:

```julia
tcl_eval(String, "$btn cget -text")
```

Top-level widgets implement the `title` and `iconname` sub-commands to query or change the
title or the icon name of the window displayed by the window manager:

```julia
top = Toplevel()
top.title() # yields the current title of the top-level widget
top.title("New Title") # sets the title of the top-level widget
top.iconname() # yields the current icon name of the top-level widget
top.iconname("top") # sets the icon name of the top-level widget
```


## Geometry managers

Non-top level widgets must be managed by a *geometry manager* to become visible. Tk provides
3 different geometry managers to organize widgets within a so-called *container* widget
(their parent by default):

* The *placer* geometry manager, via the [`tk_place`](@ref) function, provides simple fixed
  placement of widgets inside their container.

* The *packer* geometry manager, via the [`tk_pack`](@ref) function, packs the widgets in
  order against the edges of their container.

* The *grid* geometry manager, via the [`tk_grid`](@ref) function, arranges widgets in rows
  and columns inside their container.

These geometry managers take a variable number of arguments, one of which must be a widget
and all widget arguments must live in the same interpreter.

For example packing a label and a button one above the other in a top-level window can be
done by:

```julia
top = Toplevel(background="darkseagreen")
lab = Label(top, text="Some label", background="lightblue")
btn = Button(top, text="Click me", command="puts {Hello world!}")
tk_pack(btn, lab, side=:bottom, padx=90, pady=5)
top.title("Tk `pack` example")
top.iconname("tkpackxmpl")
```

which gives:

![Tk pack example](imgs/tk_pack_example.png)

## Widget configuration

### Configuration at creation

For the following examples, we create a top-level window `top` with embedded label `lab` and
button `btn` widgets as follows:

```julia
using TclTk
top = Toplevel()
top.title("Tk example")
lab = Label(top, text="Some label", background="lightblue")
btn = Button(top, text="Please push me...", command="puts {Button pushed!}")
tk_pack(lab, btn, side=:top, padx=70, pady=5)
```

This shows how `option => value` pairs can be used at widget creation to set some
configurable options.

### The `cget` sub-command

Configuration options of `btn` can be queried by the `cget` sub-command as in the following
examples:

```julia-repl
julia> tcl_exec(btn, :cget, "-text") # each argument is a token
TclObj("Please push me...")

julia> btn(:cget, "-text") # shortcut for the above example
TclObj("Please push me...")

julia> tk_cget(btn, :text) # option name without hyphen
TclObj("Please push me...")

julia> btn[:text] # option name without hyphen
TclObj("Please push me...")

```

As can be seen, any of these statements yields a Tcl object whose content is the value of
the `-text` option. Which syntax is preferred is a matter of taste.

An optional Julia type may be specified to convert the value of the Tcl object:

```julia-repl
julia> tcl_exec(String, btn, :cget, "-text") # each argument is a token
"Please push me..."

julia> btn(String, :cget, "-text") # shortcut for the above example
"Please push me..."

julia> tk_cget(String, btn, :text) # option name without hyphen
"Please push me..."

julia> btn[String, :text]
"Please push me..."

julia> btn[:text, String]
"Please push me..."

julia> btn[:text => String]
"Please push me..."

```

Specifying a Julia type for the expected result is a bit faster than converting the result
to this type as with:

```julia-repl
julia> String(btn[:text])
"Please push me..."

```

### The `configure` sub-command

For an existing widget, re-configuration can be done by via the `configure` sub-command
(often abbreviated to `config`) of the widget:

```julia-repl
julia> tcl_exec(btn, :config, text = "changed text")

```

or equivalently:

```julia-repl
julia> btn(:config, text = "changed text")

```

Any number of option settings can be specified for the `configure`:

```julia-repl
julia> btn(:config, text = "changed text", command="puts {Button clicked again!}")

```

As a shortcut, changing a single option can also be done by the `setindex!` method:

```julia-repl
julia> btn[:text] = "Oh no!"
"Oh no!"

```

Without any `option => value` pairs, the `configure` sub-command yields a list of all current settings:

```julia-repl
julia> btn.configure()
TclObj((("-command", "command", "Command", "", "puts {Button pushed!}",), ("-default", "default", "Default", "normal", "normal",), ("-takefocus", "takeFocus", "TakeFocus", "ttk::takefocus", "ttk::takefocus",), ("-justify", "justify", "Justify", "left", "left",), ("-text", "text", "Text", "", "Do it again",), ("-textvariable", "textVariable", "Variable", "", "",), ("-underline", "underline", "Underline", "", "",), ("-width", "width", "Width", "", "",), ("-image", "image", "Image", "", "",), ("-compound", "compound", "Compound", "", "",), ("-padding", "padding", "Pad", "", "",), ("-state", "state", "State", "normal", "normal",), ("-cursor", "cursor", "Cursor", "", "",), ("-style", "style", "Style", "", "",), ("-class", "", "", "", "",),))

```

Above, first argument `TclObj` of the `btn(...)` call is to specify the type of the result;
otherwise this type is `Nothing` and the result is `nothing`.
