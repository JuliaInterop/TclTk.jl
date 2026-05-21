module TclTkWidgetTests

using TclTk
using TclTk: Tk, Ttk
using Test
using Colors
using Colors.FixedPointNumbers: N0f8, N0f16
using InteractiveUtils

@testset "Tk Widgets" begin
    w = @inferred Toplevel(".")

    # Properties and winfo fields.
    @test :atomname ∉ propertynames(w)
    id = 1
    name = @inferred w.atomname(id)
    @test name isa String
    #
    @test :atom ∉ propertynames(w)
    @test @inferred(w.atom(name)) === UInt32(id)
    #
    @test :cells ∈ propertynames(w)
    @test w.cells isa Int
    #
    @test :children ∈ propertynames(w)
    @test w.children isa Vector{String}
    #
    @test :colormapfull ∈ propertynames(w)
    @test w.colormapfull isa Bool
    #
    @test :containing ∉ propertynames(w)
    @test @inferred(w.containing(0, 0)) isa String
    #
    @test :depth ∈ propertynames(w)
    @test w.depth isa Int
    #
    @test :exists ∈ propertynames(w)
    @test w.exists isa Bool
    #
    @test :fpixels ∉ propertynames(w)
    @test @inferred(w.fpixels(234)) isa Float64
    #
    @test :geometry ∈ propertynames(w)
    @test w.geometry isa String
    #
    @test :height ∈ propertynames(w)
    @test w.height isa Int
    #
    @test :id ∈ propertynames(w)
    @test w.id isa UInt
    #
    @test :interps ∈ propertynames(w)
    @test w.interps isa Vector{String}
    #
    @test :ismapped ∈ propertynames(w)
    @test w.ismapped isa Bool
    #
    @test :manager ∈ propertynames(w)
    @test w.manager isa Symbol
    #
    @test :name ∈ propertynames(w)
    @test w.name isa String
    #
    @test :parent ∈ propertynames(w)
    @test w.parent isa String
    #
    @test :path ∈ propertynames(w)
    @test w.path isa TclObj
    #
    @test :pathname ∉ propertynames(w)
    if !Sys.iswindows()
        @test @inferred(w.pathname(w.id)) isa String
        @test @inferred(w.pathname(w.id)) == w.path
    end
    #
    @test :pixels ∉ propertynames(w)
    @test @inferred(w.pixels(123.4)) isa Int
    #
    @test :pointerx ∈ propertynames(w)
    @test w.pointerx isa Int
    #
    @test :pointerxy ∈ propertynames(w)
    @test w.pointerxy isa Tuple{Int,Int}
    #
    @test :pointery ∈ propertynames(w)
    @test w.pointery isa Int
    #
    @test :reqheight ∈ propertynames(w)
    @test w.reqheight isa Int
    #
    @test :reqwidth ∈ propertynames(w)
    @test w.reqwidth isa Int
    #
    @test :rgb ∉ propertynames(w)
    @test @inferred(w.rgb("cyan")) isa RGB{N0f16}
    #
    @test :rootx ∈ propertynames(w)
    @test w.rootx isa Int
    #
    @test :rooty ∈ propertynames(w)
    @test w.rooty isa Int
    #
    @test :screen ∈ propertynames(w)
    @test w.screen isa String
    #
    @test :screencells ∈ propertynames(w)
    @test w.screencells isa Int
    #
    @test :screendepth ∈ propertynames(w)
    @test w.screendepth isa Int
    #
    @test :screenheight ∈ propertynames(w)
    @test w.screenheight isa Int
    #
    @test :screenmmheight ∈ propertynames(w)
    @test w.screenmmheight isa Float64
    #
    @test :screenmmwidth ∈ propertynames(w)
    @test w.screenmmwidth isa Float64
    #
    @test :screenvisual ∈ propertynames(w)
    @test w.screenvisual isa Symbol
    #
    @test :screenwidth ∈ propertynames(w)
    @test w.screenwidth isa Int
    #
    @test :server ∈ propertynames(w)
    @test w.server isa String
    #
    @test :toplevel ∈ propertynames(w)
    @test w.toplevel isa String
    #
    @test :viewable ∈ propertynames(w)
    @test w.viewable isa Bool
    #
    @test :visual ∈ propertynames(w)
    @test w.visual isa Symbol
    #
    @test :visualid ∈ propertynames(w)
    @test w.visualid isa UInt32
    #
    @test :visualsavailable ∈ propertynames(w)
    @test w.visualsavailable isa Vector{Tuple{Symbol, Int}}
    #
    @test :visualsavailable_includeids ∈ propertynames(w)
    @test w.visualsavailable_includeids isa Vector{Tuple{Symbol, Int, UInt32}}
    #
    @test :vrootheight ∈ propertynames(w)
    @test w.vrootheight isa Int
    #
    @test :vrootwidth ∈ propertynames(w)
    @test w.vrootwidth isa Int
    #
    @test :vrootx ∈ propertynames(w)
    @test w.vrootx isa Int
    #
    @test :vrooty ∈ propertynames(w)
    @test w.vrooty isa Int
    #
    @test :width ∈ propertynames(w)
    @test w.width isa Int
    #
    @test :x ∈ propertynames(w)
    @test w.x isa Int
    #
    @test :y ∈ propertynames(w)
    @test w.y isa Int

end

firstlastindex(A::Union{AbstractString,AbstractArray}) = firstindex(A), lastindex(A)
function skipfirst(s::AbstractString)
    start, stop = firstlastindex(s)
    return SubString(s, (start ≤ stop ? nextind(s, start) : start), stop)
end

destroy(w::TkWidget) = tcl_exec("::destroy", w)

# Retrieve widget specifications.
root = @inferred Toplevel(".")
for child in root.children
    tcl_eval("catch {destroy $child}")
end

@testset "$T widget" for T in subtypes(TkWidget)
    w = @inferred T(root)
    T == Toplevel && TclTk.wm(:withdraw, w)
    config = Dict{Symbol,String}()
    alias = Dict{Symbol,String}()
    for spec in @inferred w.configure()
        n = @inferred length(spec)
        @test n ∈ (2, 5)
        if n == 2
            # Alias option.
            short, option = @inferred convert(NTuple{2,String}, spec)
            @test startswith(short, '-')
            key = Symbol(skipfirst(short))
            @test !haskey(alias, key)
            alias[key] = option
        else
            option, dbname, dbclass, defvalue, value = @inferred convert(NTuple{5,String}, spec)
            @test startswith(option, '-')
            key = Symbol(skipfirst(option))
            @test !haskey(config, key)
            config[key] = value
        end
    end
    commands = String[]
    status, result = @inferred w(Tuple{TclStatus,TclObj}, "_")
    @test status === TCL_ERROR
    mesg = String(result)
    @test startswith(mesg, r"bad (option|command) \"_\": must be ")
    m = match(r"^.*? (\w+)(,? or |, |$)()", mesg)
    @test !isnothing(m)
    push!(commands, m.captures[1])
    sep = m.captures[2]
    index = last(m.offsets)
    if !isempty(sep)
        while true
            if sep == ", "
                m = match(r"\G(\w+)(,? or |, |$)()", mesg, index)
                isnothing(m) && error("unexpected middle of error message: \"",
                                      escape_string(mesg), "\"")
                push!(commands, m.captures[1])
                sep = m.captures[2]
                index = last(m.offsets)
            else
                m = match(r"\G(\w+)$"m, mesg, index)
                isnothing(m) && error("unexpected end of error message: \"",
                                      escape_string(mesg), "\"")
                push!(commands, m.captures[1])
                break
            end
        end
    end
    destroy(w)
end

end # module
