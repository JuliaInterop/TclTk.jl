# ttkstyle.jl --
#
# This demonstration script creates a toplevel window containing several simple Ttk widgets,
# such as labels, labelframes, buttons, checkbuttons and radiobuttons.
#
# Adapted from Tcl/Tk widget demo (file `ttkbut.tcl`).

w = ".ttkstyle"
tcl_eval("catch {destroy $w}")
top = Toplevel(w)
top.title("Simple Ttk Widgets")
top.iconname("ttkstyle")

# Label can replace Message.
msg = Label(top, #=font=$font,=# wraplength="4i", justify=:left, padding=(5, 3),
            text="Ttk is the new Tk themed widget set. This is a Ttk themed label, and below are three groups of Ttk widgets in Ttk labelframes. The first group are all buttons that set the current application theme when pressed. The second group contains three sets of checkbuttons, with a separator widget between the sets. Note that the \u201cEnabled\u201d button controls whether all the other themed widgets in this toplevel are in the disabled state. The third group has a collection of linked radiobuttons.")
msg.pack(side=:top, fill=:x)

## See Code / Dismiss
#pack [addSeeDismiss $w.seeDismiss $w {enabled cheese tomato basil oregano happiness}]\
#  -side bottom -fill x

## Add buttons for setting the theme
buttons = Labelframe(top, text="Buttons")
for theme in tcl_exec(Vector{String}, "ttk::themes")
    local btn = Button(buttons, text=theme, command="ttk::setTheme $theme")
    btn.pack(pady=2)
end

## Helper procedure for the top checkbutton
setState(args::TclObj) =
    setState(fetch(Tuple{String,Vector{String},String}, args, 2:4)...)

function setState(rootWidget, exceptThese, value)
    rootWidget ∈ exceptThese && return
    ## Non-Ttk widgets (e.g. the toplevel) will fail, so make it silent
    tcl_eval("catch {$rootWidget state $value}")
    ## Recursively invoke on all children of this root that are in the same
    ## toplevel widget
    rootToplevel = tcl_exec(String, :winfo, :toplevel, rootWidget)
    for w in tcl_exec(Vector{String}, :winfo, :children, rootWidget)
        if tcl_exec(String, :winfo, :toplevel, w) == rootToplevel
            setState(w, exceptThese, value)
        end
    end
end
setState_ = TclCallback(setState, "setState")
enabled = TclVariable{Bool}("enabled")
enabled[] = true

## Set up the checkbutton group
checks = Labelframe(top, text="Checkbuttons")
e = Checkbutton(checks, text="Enabled", variable="enabled")
e[:command] = "setState $top $e [expr {\$enabled ? \"!disabled\" : \"disabled\"}]"

## See ttk_widget(n) for other possible state flags
sep1 = Separator(checks)
c1 = Checkbutton(checks, text="Cheese", variable="cheese")
c2 = Checkbutton(checks, text="Tomato", variable="tomato")
sep2 = Separator(checks)
c3 = Checkbutton(checks, text="Basil", variable="basil")
c4 = Checkbutton(checks, text="Oregano", variable="oregano")
TclTk.pack(e, sep1, c1, c2, sep2, c3, c4, fill=:x, pady=2)

## Set up the radiobutton group
radios = Labelframe(top, text="Radiobuttons")
r1 = Radiobutton(radios, text="Great", variable="happiness", value="great")
r2 = Radiobutton(radios, text="Good",  variable="happiness", value="good")
r3 = Radiobutton(radios, text="OK",    variable="happiness", value="ok")
r4 = Radiobutton(radios, text="Poor",  variable="happiness", value="poor")
r5 = Radiobutton(radios, text="Awful", variable="happiness", value="awful")
TclTk.pack(r1, r2, r3, r4, r5, fill=:x, padx=3, pady=2)

## Arrange things neatly
f = Frame(top)
f.pack(fill="both", expand=true)
tcl_exec(:lower, f)
TclTk.grid(buttons, checks, radios, in=f, sticky="nwe", pady=2, padx=3)
TclTk.grid(:columnconfigure, f, (0, 1, 2), weight=1, uniform=true)
