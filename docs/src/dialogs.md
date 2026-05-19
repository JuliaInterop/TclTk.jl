# Dialogs

The `TclTk` package exports a number of dialog widgets provided by `Tk`. Dialog options are
specified as `key => val` pairs where `key` is the option name (a string, a symbol, or a Tcl
object) without its leading hyphen and `val` is the option value. The value returned
returned when the dialog is closed depend on the type of dialog, it is usually a string but
it may also be a vector of strings (for instance, if multiple selection is allowed in the
`tk_getOpenFile` dialog).

For example:

```julia
answer = tk_messageBox(:message => "Really quit?", :icon => :question, :type => :yesno,
                       :detail => "Select \"Yes\" to make the application exit")
if answer == "yes"
    quit()
elseif answer == "no"
    tk_messageBox(:message => "I know you like this application!", :type => :ok)
end
```

## Choosing a color

Interactively choosing a color can be done by (`using ColorTypes` is to import `RGB` among
others):

```julia
using ColorTypes
color = tk_chooseColor(:title => "Choose a nice color", :initialcolor => RGB(1.0, 0.867, 0.267))
```

Which gives:

![`Tk_chooseColor` dialog](imgs/tk_chooseColor.png)

If the user cancel the operation of close the dialog window, `nothing` is returned;
otherwise, the returned color can be used to configure a `Tk` widget. For example:

```julia
top = Toplevel(:background => color)
```


## Language for messages

The text of standard labels is automatically chosen ny `Tk` according to locale settings.
You may want to set one of the environment variables `LC_ALL`, `LC_MESSAGES`, or `LANG` to
set the language for dialog widgets before starting `TclTk`. For example:

```julia
ENV["LC_ALL"] = "en_US"
using TclTk
```

## Standard dialogs

The following Tk dialog widgets are available:

```@docs
tk_chooseColor
tk_chooseDirectory
tk_getOpenFile
tk_getSaveFile
tk_messageBox
```
