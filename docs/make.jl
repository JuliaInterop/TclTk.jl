using Documenter

push!(LOAD_PATH, normpath(joinpath(@__DIR__, "..", "src")))

using TclTk

DEPLOYDOCS = (get(ENV, "CI", nothing) == "true")

makedocs(
    sitename = "a Julia interface to Tcl/Tk",
    format = Documenter.HTML(
        canonical = "https://juliainterop.github.io//TclTk.jl",
        edit_link = "main",
        prettyurls = DEPLOYDOCS,
    ),
    authors = "Éric Thiébaut and contributors",
    pages = [
        "index.md",
        "objects.md",
        "lists.md",
        "interpreters.md",
        "variables.md",
        "callbacks.md",
        "widgets.md",
        "winfo.md",
        "dialogs.md",
        "images.md",
        "public.md",
        "develop.md",
    ]
)

if DEPLOYDOCS
    deploydocs(
        repo = "github.com/JuliaInterop/TclTk.jl.git",
        devbranch = "main",
    )
end
