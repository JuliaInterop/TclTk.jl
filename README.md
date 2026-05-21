# ![Logo](./src/logo.png) Julia interface to Tcl/Tk

[![Docs](https://img.shields.io/badge/docs-stable-blue.svg)](https://JuliaInterop.github.io/TclTk.jl/)
[![License](http://img.shields.io/badge/license-MIT-brightgreen.svg?style=flat)](LICENSE.md)
[![Build Status](https://github.com/JuliaInterop/TclTk.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/JuliaInterop/TclTk.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/juliainterop/TclTk.jl/graph/badge.svg?token=MVOdKu5PQF)](https://codecov.io/gh/juliainterop/TclTk.jl)
[![Aqua QA](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)

This package provides an optimized Julia interface to [Tcl/Tk](http://www.tcl-lang.org/).
The [documentation is available on-line](https://JuliaInterop.github.io/TclTk.jl/) and
extended examples are given in the [examples](./examples) directory. To whet your appetite,
a few examples are given below.

## Tcl scripts and commands

The traditional *"Hello world!"* example:

``` julia-repl
julia> using TclTk

julia> tcl_eval("puts {Hello world!}")
Hello world!

```

which shows how to evaluate a Tcl script. The above output is not the value returned by the
script as `tcl_eval` returns `nothing` by default. If we are interested by the result of the
evaluated script or expression, `tcl_eval` takes an optional first argument to specify the
type of the expected result. For example:

``` julia-repl
julia> tcl_eval(Float64, "expr {4*atan(1)}")
3.141592653589793
```

The most general return value is a Tcl object which can be reused or converted later:

``` julia-repl
julia> x = tcl_eval(TclObj, "format \"%s/data-%06d.bin\" \"/tmp\" 123")
TclObj("/tmp/data-000123.bin")

julia> String(x) # `string(x)` and `convert(String, x)` work as well
"/tmp/data-000123.bin"
```

Spaces and braces are special characters in Tcl and may have to be properly escaped in
scripts, perhaps with the help of `TclTk.escape_string`. A better solution, if the script is
a single Tcl command, is to call `tcl_exec` which assumes that each argument (after an
optional leading type) is a single Tcl token:

``` julia-repl
julia> msg = "- - } Hello world! { - -"
"- - } Hello world! { - -"

julia> x = tcl_exec(:puts, msg)
- - } Hello world! { - -

julia> x = tcl_exec(String, "format", "%s/%s/data-%06d.bin", ENV["HOME"], "tmp", 123)
"/home/eric/tmp/data-000123.bin"
```

## Widgets and images

Below is a simple example to show an image in a Tk top-level window:

``` julia-repl
julia> using TclTk, TestImages

julia> img = testimage("mandrill"); # read some image data

julia> top = Toplevel(background="#282c34")
Toplevel(".top1")

julia> top.title("A Nice Image")

julia> lab = Label(top, image=TkPhoto(permutedims(img)), cursor="target")
Label(".top1.lab1")

julia> lab.pack(side="top", padx=20, pady=30)

```

The different stages are:

- Load some image data as a Julia array.

- Create a top-level window `top` with a given background color.

- Call window manager `wm.title` command to set the title of the top-level window.

- Create a widget, here a label `lab`, whose parent is `top` to display the image.

- Call the `pack` geometry manager to specify how to display the `lab` widget in its parent
  (leading `Nothing` argument is because we are not interested in the result of this
  command).

It may be noticed that, following Tk conventions, the width and height of an image are its
respective first and second dimensions. The images provided by the `TestImages` have a
different convention and we call `permutedims(img)` to cope with that. Using the apostrophe,
i.e. `img'`, would also do the job.

A Tk widget instance can be called to perform widget actions such as (re-)configuring some
options. For example, let us show the frame of the image with a *sunken* relief:

``` julia-repl
julia> lab.configure(borderwidth=3, relief=:sunken, padding=7, background="beige")

```

The change should be immediate as Tk widgets apply their configuration dynamically.


## Alternatives

There exists [another Julia Tk package](http://github.com/JuliaGraphics/Tk.jl) but with
different design choices and some issues I wanted to avoid (for instance, X conflict with
PyPlot when using Gtk backend, Qt backend is OK). This is why I started this project. I
would be very happy if, eventually, the two projects merge.


## Installation

It is easy to install TclTk from the REPL of Julia's package manager<sup>[[pkg]](#pkg)</sup>
as follows:

```julia
pkg> add TclTk
```

To check whether `TclTk` package works correctly:

```julia
pkg> test TclTk
```

To update to the last version:

```julia
pkg> update TclTk
```

and perhaps test again...

If something goes wrong, it may be because you already have an old version of `TclTk`.
Uninstall `TclTk` as follows:

```julia
pkg> rm TclTk
pkg> gc
pkg> add TclTk
```

before re-installing.

<hr>

- <a name="pkg"><sup>[pkg]</sup></a> To switch from [julia
  REPL](https://docs.julialang.org/en/stable/manual/interacting-with-julia/) to the package
  manager REPL, just hit the `]` key and you should get a `... pkg>` prompt. To revert to
  Julia's REPL, hit the `Backspace` key at the `... pkg>` prompt.
