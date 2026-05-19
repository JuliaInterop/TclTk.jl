#
# dialogs.jl -
#
# Wrappers for some Tk dialog widgets.
#

"""
    tk_messageBox(pairs...; kwds...) -> answer::String

Pop up a Tk message box dialog and return the name of the selected button.

# Options

Trailing `pairs...` arguments and keywords `kwds...` are to specify some of the following
options:

- Option `:parent` specifies the window of the logical parent of the message box. The
  message box is displayed on top of its parent window.

- Option `:title` specifies the title of the message box. This option is ignored on Mac OS
  X, where platform guidelines forbid the use of a title on this kind of dialog.

- Option `:message` specifies the message to display in this message box. The default value
  is an empty string.

- Option `:detail` specifies an auxiliary message to the main message. The message detail
  will be presented beneath the main message and, where supported by the OS, in a less
  emphasized font than the main message.

- Option `:icon` specifies an icon to display: `:error`, `:info`, `:question` or `:warning`.
  By default, the `:info` icon is displayed.

- Option `:type` specifies which predefined set of buttons is displayed. The following
  values are possible:

  - `:abortretryignore` to display three buttons whose symbolic names are `:abort`, `:retry`
    and `:ignore`.

  - `:ok` to display one button whose symbolic name is `:ok`.

  - `:okcancel` to display two buttons whose symbolic names are `:ok` and `:cancel`.

  - `:retrycancel` to display two buttons whose symbolic names are `:retry` and `:cancel`.

  - `:yesno` to display two buttons whose symbolic names are `:yes` and `:no`.

  - `:yesnocancel` to display three buttons whose symbolic names are `:yes`, `:no` and
    `:cancel`.

- Option `:default` gives the name of the default button for this message window (`:ok`,
  `:cancel`, and so on). See keyword `type` for a list of the button names. If this option
  is not specified, the first button in the dialog will be made the default.

- Option `:command` specifies the prefix of a Tcl command to invoke when the user closes the
  dialog. The actual command consists of string followed by a space and the name of the
  button clicked by the user to close the dialog. This is only available on Mac OS X.

# Examples

```julia
answer = tk_messageBox(message="Really quit?", icon=:question, type=:yesno,
                       detail="Select \"Yes\" to make the application exit")
if answer == "yes"
    quit()
elseif answer == "no"
    tk_messageBox(message="I know you like this application!", type=:ok)
end
```

# See also

[`tk_chooseColor`](@ref), [`tk_chooseDirectory`](@ref), [`tk_getOpenFile`](@ref), and and
[`tk_getSaveFile`](@ref).

"""
function tk_messageBox(pairs::Pair...; kwds...)
    return tcl_exec(String, "tk_messageBox", pairs...; kwds...)
end

"""
    tk_chooseColor(pairs...; kwds...)

Pop up a Tk dialog box for the user to select a color and return the chosen color as an
instance of `TkRGB{UInt8}` or `nothing` if the user cancels the dialog.

# Options

Trailing `pairs...` arguments and keywords `kwds...` are to specify some of the following
options:

- Option `:parent` specifies the logical parent of the message box. The color dialog box is
  displayed on top of its parent window.

- Option `:title` specifies the title of the message box.

- Option `:initialcolor` specifies the color to display in the color dialog when it pops up.
  The value of this option can be a string like `"orange"` or `"#ff03ae"` or an instance of
  a sub-type of `TkColor`.

# See also

[`tk_chooseDirectory`](@ref), [`tk_getOpenFile`](@ref), [`tk_getSaveFile`](@ref), and
[`tk_messageBox`](@ref).

"""
function tk_chooseColor(pairs::Pair...; kwds...) :: Union{RGB{N0f8},Nothing}
    # Evaluate command and get the result as a string.
    color = tcl_exec(String, "tk_chooseColor", pairs...; kwds...)

    # Convert to a color.
    isempty(color) && return nothing
    try
        return parse(RGB{N0f8}, color)
    catch
        error("unexpected color \"$color\"")
    end
end

"""
    tk_chooseDirectory(pairs...; kwds...) -> dir::String

Pop up a Tk dialog box for the user to select a directory and return the chosen directory
name (an empty string if none).

# Options

Trailing `pairs...` arguments and keywords `kwds...` are to specify some of the following
options:

- Option `:parent` specifies the window of the logical parent of the message box. The
  message box is displayed on top of its parent window.

- Option `:title` specifies the title of the message box. This option is ignored on Mac OS
  X, where platform guidelines forbid the use of a title on this kind of dialog.

- Option `:message` specifies the message to display in this message box. The default value
  is an empty string. This is only available on Mac OS X.

- Option `:initialdir` specifies that the directories in directory should be displayed when
  the dialog pops up. If this parameter is not specified, the initial directory defaults to
  the current working directory on non-Windows systems and on Windows systems prior to
  Vista. On Vista and later systems, the initial directory defaults to the last
  user-selected directory for the application. If the parameter specifies a relative path,
  the return value will convert the relative path to an absolute path.

- Option `:mustexist` specifies whether the user may specify non-existent directories. If
  this parameter is true, then the user may only select directories that already exist.

- Option `:command` specifies the prefix of a Tcl command to invoke when the user closes the
  dialog. The actual command consists of string followed by a space and the name of the
  button clicked by the user to close the dialog. This is only available on Mac OS X.

# See also

[`tk_chooseColor`](@ref), [`tk_getOpenFile`](@ref), [`tk_getSaveFile`](@ref), and
[`tk_messageBox`](@ref).

"""
function tk_chooseDirectory(pairs::Pair...; kwds...)
    return tcl_exec(String, "tk_chooseDirectory", pairs...; kwds...)
end

"""
    tk_getOpenFile(pairs...; kwds...)

Pop up a Tk dialog box for the user to select a file to open and return the name of the
chosen file (an empty string if none).

# Options

Trailing `pairs...` arguments and keywords `kwds...` are to specify some of the following
options:

- Option `:parent` specifies the path of the logical parent of the file dialog. The file
  dialog is displayed on top of its parent window. On Mac OS X, this turns the file dialog
  into a sheet attached to the parent window.

- Option `:title` specifies a string to display as the title of the dialog box. If this
  option is not specified, then a default title is displayed.

- Option `:message` Specifies a message to include in the client area of the dialog. This is
  only available on Mac OS X.

- Option `:initialdir` specifies the directory in which the files should be displayed when
  the dialog pops up. If this parameter is not specified, the initial directory defaults to
  the current working directory on non-Windows systems and on Windows systems prior to
  Vista. On Vista and later systems, the initial directory defaults to the last
  user-selected directory for the application. If the parameter specifies a relative path,
  the return value will convert the relative path to an absolute path.

- Option `:initialfile` specifies a filename to be displayed in the dialog when it pops up.

- Option `:multiple` specifies whether the user can choose multiple files from the Open
  dialog. If multiple files are chosen, a vector of strings is returned.

- Option `:defaultextension` specifies a string that will be appended to the filename if the
  user enters a filename without an extension. The default value is the empty string, which
  means no extension will be appended to the filename in any case. This option is ignored on
  Mac OS X, which does not require extensions to filenames, and the UNIX implementation
  guesses reasonable values for this from the `filetypes` option when this is not supplied.

- If a file types listbox exists in the file dialog on the particular platform, option
  `:filetypes` gives the filetypes in this listbox. When the user choose a filetype in the
  listbox, only the files of that type are listed. If this option is unspecified, or if it
  is set to the empty list, or if the File types listbox is not supported by the particular
  platform then all files are listed regardless of their types. See Tk manual for more
  details.

- Option `:typevariable` specifies the name of a global Tcl variable used to preselect which
  filter is used from filterList when the dialog box is opened and is updated when the
  dialog box is closed, to the last selected filter. The variable is read once at the
  beginning to select the appropriate filter. If the variable does not exist, or its value
  does not match any filter typename, or is empty ({}), the dialog box will revert to the
  default behavior of selecting the first filter in the list. If the dialog is canceled, the
  variable is not modified.

- Option `:command` specifies the prefix of a Tcl command to invoke when the user closes the
  dialog after having selected an item. This callback is not called if the user cancelled
  the dialog. The actual command consists of the `command` string followed by a space and
  the value selected by the user in the dialog. This is only available on Mac OS X.

# See also

[`tk_getOpenFile`](@ref), [`tk_chooseColor`](@ref), [`tk_chooseDirectory`](@ref), and
[`tk_messageBox`](@ref).

"""
function tk_getOpenFile(pairs::Pair...; kwds...) :: Union{String, Vector{String}}
    # Determine whether multiple selection is allowed.
    multiple = false
    for (key, val) in pairs
        if key isa Symbol
            key == :multiple || continue
        elseif key isa Union{AbstractString,TclObj}
            key == "multiple" || continue
        else
            continue
        end
        multiple = bool(val)
        break
    end
    for (key, val) in kwds
        key == :multiple || continue
        multiple = bool(val)
        break
    end

    # Execute command.
    obj = tcl_exec(TclObj, "tk_getOpenFile", pairs...; kwds...)

    # Return the result as a string or a vector of string.
    if multiple
        return convert(Vector{String}, obj)
    else
        return String(obj)
    end
end

"""
    tk_getSaveFile(pairs...; kwds...)

Pop up a Tk dialog box for the user to select a file to save and return the name of the
chosen file (an empty string if none).

# Options

Trailing `pairs...` arguments and keywords `kwds...` are to specify some of the following
options:

- For options `:parent`, `:title`, `:message`, `:initialdir`, `:initialfile`,
  `:defaultextension`, `:filetypes`, `:typevariable`, and `:command`, see
  [`tk_getSaveFile`](@ref).

- Option `:confirmoverwrite` configures how the Save dialog reacts when the selected file
  already exists, and saving would overwrite it. A true value requests a confirmation dialog
  be presented to the user. A false value requests that the overwrite take place without
  confirmation.

# See also

[`tk_getSaveFile`](@ref), [`tk_chooseColor`](@ref), [`tk_chooseDirectory`](@ref), and
[`tk_messageBox`](@ref).

"""
function tk_getSaveFile(pairs::Pair...; kwds...)
    return tcl_exec(String, "tk_getSaveFile", pairs...; kwds...)
end
