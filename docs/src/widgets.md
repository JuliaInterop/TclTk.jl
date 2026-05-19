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


## Widget sub-commands

Tk widgets may be invoked to execute sub-commands (the list of which depend on the widget
type). There are different two equivalent ways to call a widget sub-command:

```julia
tcl_exec(T=Nothing, widget, subcmd, args...)
widget(T=Nothing, subcmd, args...)
```

where `widget` is a widget instance, optional leading argument `T` is the expected type of
the result (a Tcl object by default), `subcmd` is the sub-command name (a string, a symbol,
or a Tcl object) and `args...` are the arguments of the sub-command. For example, assuming
`btn` is a button widget, retrieving the associated text can be done by one of:

```julia
tcl_exec(String, btn, :cget, "-text")
btn(String, :cget, "-text")
```

Another possibility could be to evaluate a Tcl script as in:

```julia
tcl_eval(String, "$btn cget -text")
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
btn.pack(btn, lab, side=:bottom, padx=90, pady=5)
top.title("Tk `pack` example")
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
