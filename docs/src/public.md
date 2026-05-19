# Public API

## Objects

```@docs
TclObj
tcl_concat
tcl_list
```

## Interpreters

```@docs
tcl_eval
tcl_exec
tcl_quote_string
```

## Status and exceptions

```@docs
TclStatus
TclError
tcl_error
```

## Variables

```@docs
TclTk.Variable
TclTk.exists
TclTk.getvar
TclTk.setvar!
TclTk.unsetvar!
```

## Callbacks

```@doc
TclTk.Callback
```

## Events

```@docs
tk_start
TclTk.do_events
TclTk.do_one_event
TclTk.resume
TclTk.suspend
```

## Widgets

```@docs
TkWidget
Button
Canvas
Checkbutton
Combobox
Entry
Frame
Label
Labelframe
Listbox
Menu
Menubutton
Message
Notebook
Panedwindow
Progressbar
Radiobutton
Scale
Scrollbar
Separator
Sizegrip
Spinbox
TclTk.Text
Toplevel
Treeview
TclTk.cget
TclTk.configure
TclTk.winfo
```

## Window and geometry managers

```@docs
TclTk.grid
TclTk.pack
TclTk.place
wm
```

## Images

```@docs
TkImage
TkBitmap
TkPhoto
```
