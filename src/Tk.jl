"""

Module `Tk` defines standard Tk widgets.

"""
module Tk

using ...TclTk
using ..Impl: @TkWidget

# Top-level widgets.
@TkWidget Toplevel      Toplevel      "::toplevel"          ".top"
@TkWidget Menu          Menu          "::menu"              ".mnu"

# Classic Tk widgets.
@TkWidget Button        Button        "::button"            "btn"
@TkWidget Canvas        Canvas        "::canvas"            "cnv"
@TkWidget Checkbutton   Checkbutton   "::checkbutton"       "cbt"
@TkWidget Entry         Entry         "::entry"             "ent"
@TkWidget Frame         Frame         "::frame"             "frm"
@TkWidget Label         Label         "::label"             "lab"
@TkWidget Labelframe    Labelframe    "::labelframe"        "lfr"
@TkWidget Listbox       Listbox       "::listbox"           "lbx"
@TkWidget Menubutton    Menubutton    "::menubutton"        "mbt"
@TkWidget Message       Message       "::message"           "msg"
@TkWidget Panedwindow   Panedwindow   "::panedwindow"       "pwn"
@TkWidget Radiobutton   Radiobutton   "::radiobutton"       "rbt"
@TkWidget Scale         Scale         "::scale"             "scl"
@TkWidget Scrollbar     Scrollbar     "::scrollbar"         "sbr"
@TkWidget Spinbox       Spinbox       "::spinbox"           "sbx"
@TkWidget Text          Text          "::text"              "txt"

end # module
