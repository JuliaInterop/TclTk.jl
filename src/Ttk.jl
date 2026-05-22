"""

Module `Ttk` defines Themed Tk widgets.

"""
module Ttk

using ...TclTk
using ..Impl: @TkWidget

@TkWidget Button       TButton       "::ttk::button"       "btn"
@TkWidget Checkbutton  TCheckbutton  "::ttk::checkbutton"  "cbt"
@TkWidget Combobox     TCombobox     "::ttk::combobox"     "cbx"
@TkWidget Entry        TEntry        "::ttk::entry"        "ent"
@TkWidget Frame        TFrame        "::ttk::frame"        "frm"
@TkWidget Label        TLabel        "::ttk::label"        "lab"
@TkWidget Labelframe   TLabelframe   "::ttk::labelframe"   "lfr"
@TkWidget Menubutton   TMenubutton   "::ttk::menubutton"   "mbt"
@TkWidget Notebook     TNotebook     "::ttk::notebook"     "nbk"
@TkWidget Panedwindow  TPanedwindow  "::ttk::panedwindow"  "pwn"
@TkWidget Progressbar  TProgressbar  "::ttk::progressbar"  "pgb"
@TkWidget Radiobutton  TRadiobutton  "::ttk::radiobutton"  "rbt"
@TkWidget Scale        TScale        "::ttk::scale"        "scl"
@TkWidget Scrollbar    TScrollbar    "::ttk::scrollbar"    "sbr"
@TkWidget Separator    TSeparator    "::ttk::separator"    "sep"
@TkWidget Sizegrip     TSizegrip     "::ttk::sizegrip"     "szg"
@TkWidget Spinbox      TSpinbox      "::ttk::spinbox"      "sbx"
@TkWidget Treeview     Treeview      "::ttk::treeview"     "trv"

end # module
