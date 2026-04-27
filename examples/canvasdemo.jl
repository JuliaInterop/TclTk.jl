using Colors, TclTk

# Make sure Tk package is loaded and event loop is running.
interp = tk_start()

# Top-level widget with title.
top = Toplevel(background="#282c34")
wm.title(top, "Canvas demo")

# Create a canvas widget. The "closeenough" settings (in pixels) is to facilitate the
# selection of a marker to delete.
canvas = Canvas(top, cursor=:target, background="#282c34", closeenough=7)

# Frame widget for the message and counter.
bar = Frame(top, borderwidth=1, relief=:raised)

# Create a message widget.
mesg = Message(bar, text="""
Click on an empty location to add a marker.
Click on a marker to delete it.""", aspect=600)

# Create a Tcl variable to track the number of markers.
counter = TclTk.Variable{Int}(interp, "::NUMBER_OF_MARKERS")
counter[] = 0

# Create a label to display the number of markers.
count = Label(bar, background="white", borderwidth=1, relief=:sunken,
              anchor=:center, width=5, text=0, textvariable=counter.name)

# Arrange widgets in their parent.
canvas.pack(side=:top, expand=true, fill=:both)
bar.pack(side=:bottom, expand=false, fill=:x)
mesg.pack(side=:left, expand=true, fill=:both)
count.pack(side=:right, expand=false, fill=:both, padx=5, pady=5)

# Function to add a marker in a canvas.
function add_marker(canvas::Canvas, xm, ym;
                    tag="marker", radius=4, adjust::Bool=false,
                    fill=Colors.JULIA_LOGO_COLORS.green,
                    activefill=Colors.JULIA_LOGO_COLORS.red)
    r = convert(Float64, radius)
    if adjust
        # Convert coordinates to canvas coordinates.
        x = canvas.canvasx(Float64, xm)
        y = canvas.canvasy(Float64, ym)
    else
        # Convert coordinates to `Float64` for generality and type-stability.
        x = convert(Float64, xm)
        y = convert(Float64, ym)
    end
    return canvas.create(Int, :rectangle, x - r, y - r, x + r, y + r,
                         tags=tag, fill=fill, width=0, activefill=activefill, activewidth=0)
end

# Callback function to be called with: %W %x %y.
function on_click(interp::TclInterp, args::TclObj)
    # Extract arguments (1st is name of procedure, unused here).
    canvas, xm, ym = interp.fetch(Tuple{Canvas,Float64,Float64}, args, 2:4)

    # Convert coordinates to canvas coordinates.
    x = canvas.canvasx(Float64, xm)
    y = canvas.canvasy(Float64, ym)

    # Current number of markers.
    number_of_markers = Int(interp["NUMBER_OF_MARKERS"])

    # If there is any "marker" item among the "current" ones, delete the first of these; otherwise
    # add a new marker.
    list = canvas.find(:withtag, "current && marker")
    if isempty(list)
        add_marker(canvas, x, y; adjust=false)
        counter[] += 1
    else
        canvas.delete(list[1])
        counter[] -= 1
    end
end

# Create the counterpart of the callback in the Tcl interpreter.
on_click_callback = TclTk.Callback(on_click, interp, "on_click")

# Bind event to callback.
bind(canvas, "<ButtonPress-1>", "on_click %W %x %y")
