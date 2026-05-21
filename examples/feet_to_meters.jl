# Adapted from https://tkdocs.com/tutorial/firstexample.html

using TclTk

function calc_function(args::TclObj)
    feet = tcl_getvar(Float64, "feet")
    resolution = 1e3
    tcl_setvar("meters", round(feet*0.3048*resolution)/resolution)
end
calc_callback = TclCallback(calc_function)

top = Toplevel()
top.title("Feet to Meters")

frame = Frame(top, padding=(3, 3, 12, 12))
frame.grid(column=0, row=0, sticky="nwes")

feet = Entry(frame, width=7, textvariable="feet")
feet.grid(column=2, row=1, sticky="we")

meters = Label(frame, textvariable="meters")
meters.grid(column=2, row=2, sticky="we")

calc = Button(frame, text="Calculate", command=calc_callback.name)
calc.grid(column=3, row=3, sticky="w")

flbl = Label(frame, text="feet")
flbl.grid(column=3, row=1, sticky="w")

islbl = Label(frame, text="is equivalent to")
islbl.grid(column=1, row=2, sticky="e")

mlbl = Label(frame, text="meters")
mlbl.grid(column=3, row=2, sticky="w")

TclTk.grid(:columnconfigure, top, 0, weight=1)
TclTk.grid(:rowconfigure, top, 0, weight=1)
TclTk.grid(:columnconfigure, frame, 2, weight=1)
for w in frame.children
    TclTk.grid(:configure, w, padx=5, pady=5)
end
tcl_exec(:focus, feet)
bind(top, "<Return>", calc_callback.name)
