module TclBaseTests

using TclTk
using Colors
using Test

# We need some irrational constants.
const π = MathConstants.π
const φ = MathConstants.φ

@enum Fruit apple=1 orange=2 kiwi=3

@testset "Utilities" begin
    # Version number.
    version = @inferred tcl_version()
    @test version isa VersionNumber
    @test version.major == TCL_MAJOR_VERSION
    @test version.minor == TCL_MINOR_VERSION

    # Path to Tcl library.
    library = @inferred tcl_library()
    @test library isa String
    @test isdir(library)

    # Automatic names.
    p = "some_prefix"
    s = @inferred TclTk.Core.auto_name(p)
    @test s isa String
    @test startswith(s, p)

    # Convert to Boolean.
    @test @inferred(TclTk.bool(true)) === true
    @test @inferred(TclTk.bool(false)) === false
    @test @inferred(TclTk.bool("0")) === false
    @test @inferred(TclTk.bool("0.0")) === false
    @test @inferred(TclTk.bool(0)) === false
    @test @inferred(TclTk.bool(0x00)) === false
    @test @inferred(TclTk.bool(0//1)) === false
    @test @inferred(TclTk.bool(0.0)) === false
    @test @inferred(TclTk.bool(-0.0)) === false
    @test @inferred(TclTk.bool(1)) === true
    @test @inferred(TclTk.bool(-1234)) === true
    @test @inferred(TclTk.bool(π)) === true
    @test @inferred(TclTk.bool(Inf)) === true
    @test @inferred(TclTk.bool("1")) === true
    @test @inferred(TclTk.bool("4.2")) === true
    @test @inferred(TclTk.bool(:true)) === true
    @test @inferred(TclTk.bool(:True)) === true
    @test @inferred(TclTk.bool(:TRUE)) === true
    @test @inferred(TclTk.bool(:yes)) === true
    @test @inferred(TclTk.bool(:Yes)) === true
    @test @inferred(TclTk.bool(:YES)) === true
    @test @inferred(TclTk.bool(:on)) === true
    @test @inferred(TclTk.bool(:On)) === true
    @test @inferred(TclTk.bool(:ON)) === true
    @test @inferred(TclTk.bool(:false)) === false
    @test @inferred(TclTk.bool(:False)) === false
    @test @inferred(TclTk.bool(:FALSE)) === false
    @test @inferred(TclTk.bool(:no)) === false
    @test @inferred(TclTk.bool(:No)) === false
    @test @inferred(TclTk.bool(:NO)) === false
    @test @inferred(TclTk.bool(:off)) === false
    @test @inferred(TclTk.bool(:Off)) === false
    @test @inferred(TclTk.bool(:OFF)) === false
    @test_throws ArgumentError TclTk.bool("")
    @test_throws ArgumentError TclTk.bool("oui")
    @test_throws ArgumentError TclTk.bool("maybe")
    @test @inferred(TclTk.bool(TclObj(true))) === true
    @test @inferred(TclTk.bool(TclObj(false))) === false

    # Quoted strings.
    @test @inferred(tcl_quote_string("")) == "\"\""
    @test @inferred(tcl_quote_string("a")) == "\"a\""
    @test @inferred(tcl_quote_string("  a")) == "\"  a\""
    @test @inferred(tcl_quote_string("a    ")) == "\"a    \""
    @test @inferred(tcl_quote_string(" a  b   ")) == "\" a  b   \""
    @test @inferred(tcl_quote_string("x\\\0w")) == "\"x\\\\\300\200w\""
    let s = "}\"\e\a\b\t\n\v\f\r{"
        @test @inferred(tcl_eval(String, "set dummy $(tcl_quote_string(s))")) == s
    end
    let s = "áéíóúýàèìòùỳäëïöüÿâêîôûŷß"
        @test @inferred(tcl_eval(String, "set dummy $(tcl_quote_string(s))")) == s
    end
    let s = "ÁÉÍÓÚÝÀÈÌÒÙỲÄËÏÖÜŸÂÊÎÔÛŶ"
        @test @inferred(tcl_eval(String, "set dummy $(tcl_quote_string(s))")) == s
    end
    let s = "αβδεϵϕφγηιθκλμνοπχρστυωξψζ"
        @test @inferred(tcl_eval(String, "set dummy $(tcl_quote_string(s))")) == s
    end
    let s = "ΑΒΔΕΦΓΗΙΘΚΛΜΝΟΠΧΡΣΤΥΩΞΨΖ"
        @test @inferred(tcl_eval(String, "set dummy $(tcl_quote_string(s))")) == s
    end
end

@testset "Tcl Objects" begin
    # Julia string and symbols to Tcl object.
    script = "puts {hello world!}"
    symbolic_script = Symbol(script)
    x = @inferred TclObj(script)
    @test x isa TclObj
    @test length(propertynames(x)) == 3
    @test hasproperty(x, :ptr)
    @test hasproperty(x, :refcnt)
    @test hasproperty(x, :type)
    @test x.type == :string
    @test isone(x.refcnt)
    @test isreadable(x)
    @test iswritable(x)
    @test x.ptr === @inferred(pointer(x))
    @test_throws KeyError x.non_existing_field
    @test_throws KeyError x.non_existing_field = 4
    @test_throws ErrorException x.refcnt = 1
    @test script == @inferred string(x)
    @test script == @inferred String(x)
    @test script == @inferred convert(String, x)
    @test x === @inferred TclObj(x)
    @test x == x
    @test x == script
    @test script == x
    @test isequal(x, x)
    @test isequal(x, script)
    @test isequal(script, x)
    @test x == symbolic_script
    @test symbolic_script == x
    @test isequal(x, symbolic_script)
    @test isequal(symbolic_script, x)
    s = SubString(script, firstindex(script), lastindex(script))
    @test x == s
    @test s == x
    @test isequal(x, s)
    @test isequal(s, x)
    y = @inferred TclObj(symbolic_script)
    @test y isa TclObj
    @test y.type == :string
    @test y == x
    @test y == symbolic_script
    @test symbolic_script == y
    @test isequal(y, symbolic_script)
    @test isequal(symbolic_script, y)
    @test y == script
    @test script == y
    @test isequal(y, script)
    @test isequal(script, y)

    # Build Tcl object from pointer.
    n = x.refcnt
    z = @inferred TclObj(pointer(x))
    @test z isa TclObj
    @test x.refcnt == n + 1
    @test z.refcnt == n + 1
    @test pointer(z) == pointer(x)

    # NULL Tcl object.
    nul = @inferred TclObj()
    @test pointer(nul) == C_NULL
    @test nul.refcnt < 0
    @test nul.type == :null
    @test_throws Exception convert(String, nul)
    @test tryparse(Int, nul) === nothing
    @test sprint(show, nul) == "TclObj(#= null =#)"
    @test isempty(nul)

    # copy() yields same but distinct objects (except for a NULL Tcl object)
    n = x.refcnt
    y = @inferred copy(x)
    @test y isa TclObj
    @test y.type == :string
    @test isone(y.refcnt)
    @test x.refcnt == n
    @test y.ptr !== x.ptr
    @test x == y
    @test isequal(x, y)
    z = @inferred copy(nul)
    @test z isa TclObj
    @test z.type == :null
    @test z == nul

    # length() converts object into a list
    @test length(y) === 2 # there are 2 tokens in the script
    @test y.type == :list
    @test firstindex(y) === 1
    @test lastindex(y) === length(y)
    @test @inferred(eltype(y)) === TclObj
    @test @inferred(eltype(typeof(y))) === TclObj
    @test y[1] == "puts"
    @test y[2] == "hello world!"

    # `boolean` type.
    x = @inferred TclObj("true")
    @test x.type == :string
    @test @inferred(repr(x)) == "TclObj(\"true\")"
    @test convert(Bool, x) === true
    @test x.type == :boolean
    @test @inferred(repr(x)) == "TclObj(true)"
    x = @inferred TclObj("false")
    @test x.type == :string
    @test @inferred(repr(x)) == "TclObj(\"false\")"
    @test convert(Bool, x) === false
    @test x.type == :boolean
    @test @inferred(repr(x)) == "TclObj(false)"

    # Destroy object and then calling the garbage collector must not throw.
    z = TclObj(0)
    z = 0 # no longer a Tcl object
    @test try GC.gc(); true; catch; false; end

    # Print, show, etc.
    values = (Int16(-123), 12.125, "hello world!")
    @testset "Print/string conversion of $v::$(typeof(v))" for v in values
        x = @inferred TclObj(v)
        @test "$x" == "$v"
        @test sprint(print, x) == "$v"
        @test summary(x) == sprint(summary, x)
        @test startswith(sprint(show, x), "TclObj(")
        @test startswith(sprint(show, MIME"text/plain"(), x), "TclObj(")
    end
    v = (false, 1, -2.75, "hello you!")
    x = @inferred TclObj(v)
    y = @inferred TclObj("$x")
    @test length(x) == length(y)
    @test x == y
    @test collect(x) == collect(y)

    # Conversions. NOTE Tcl conversion rules are more restricted than Julia.
    # TODO Test unsigned integers.
    values = (true, false, -1, 0x03, Int16(8), Int32(-217),
              typemin(Int8), typemax(Int8),
              typemin(Int16), typemax(Int16),
              typemin(Int32), typemax(Int32),
              typemin(Int64), typemax(Int64),
              0.0f0, 1.0, 2//3, π, big(1.3))
    types = (Bool, Int8, Int16, Int32, Int64, Integer, Float32, Float64, AbstractFloat)
    @testset "Conversion of $x::$(typeof(x)) to $T" for x in values, T in types
        y = @inferred TclObj(x)
        if x isa Integer
            @test y.type ∈ (:int, :wideInt)
        else
            @test y.type == :double
        end
        z = @inferred convert(TclObj, x)
        @test z.type == y.type # same type
        @test z == y           # same content
        if T == Bool
            @test (@inferred Bool convert(Bool, y)) == !iszero(x)
        elseif T <: Integer
            if !(x isa Integer)
                # Floating-point to non-Boolean integer is not allowed by TclTk.
                @test_throws ArgumentError convert(T, y)
            else
                S = (isconcretetype(T) ? T : TclTk.WideInt)
                if typemin(S) ≤ x ≤ typemax(S)
                    @test (@inferred S convert(T, y)) == convert(S, x)
                else
                    @test_throws ArgumentError convert(T, y)
                end
            end
        else # T is non-integer real
            S = (T === AbstractFloat ? Float64 : T)
            @test (@inferred S convert(T, y)) == convert(S, x)
        end
    end

    # Other conversions.
    x = @inferred TclObj("true")
    @test Bool(x) === true # this also trigger conversion of internal type
    @test x.type == :boolean
    @test Real(x) isa Bool
    @test Integer(x) isa Bool
    @test_throws Exception AbstractFloat(x) # this is a restriction of Tcl: "true" -> Boolean is ok, but "true" -> other numeric type is not allowed
    @test tryparse(Bool, x) === true
    @test tryparse(Integer, x) === true
    @test tryparse(Real, x) === true
    @test tryparse(AbstractFloat, x) === nothing
    x = @inferred TclObj("1.25")
    @test Bool(x) === true # this also trigger conversion of internal type
    @test x.type == :double
    @test AbstractFloat(x) isa Cdouble
    @test Real(x) isa Cdouble
    @test_throws Exception Integer(x)
    @test x === @inferred convert(TclObj, x)
    @test x === @inferred convert(Any, x)
    @test tryparse(Bool, x) === true
    @test tryparse(Integer, x) === nothing
    @test tryparse(Real, x) === 1.25
    @test tryparse(AbstractFloat, x) === 1.25
    s = "-17.0" # a string that gives a float with no fractional part
    x = @inferred TclObj(s)
    @test Bool(x) === true # this also trigger conversion of internal type
    @test x.type == :double
    @test AbstractFloat(x) === parse(Cdouble, s)
    @test Real(x) === parse(Cdouble, s)
    @test_throws Exception Integer(x) # FIXME?
    @test x === @inferred convert(TclObj, x)
    @test tryparse(Bool, x) === true
    @test tryparse(Integer, x) === nothing
    @test tryparse(Real, x) === -17.0
    @test tryparse(AbstractFloat, x) === -17.0
    @test Base.unsafe_convert(Ptr{TclTk.Core.Tcl_Obj}, x) === pointer(x)
    c = 'w' # one byte UTF8 char
    x = @inferred TclObj(c)
    @test x.type == :string
    @test x == string(c)
    @test c === @inferred convert(Char, x)
    y = @inferred convert(TclObj, c)
    @test y.type == x.type # same type
    @test y == x           # same content
    c = 'λ' # multi-byte UTF8 char
    x = @inferred TclObj(c)
    @test x.type == :string
    @test x == string(c)
    @test c === @inferred convert(Char, x)
    y = @inferred convert(TclObj, c)
    @test y.type == x.type # same type
    @test y == x           # same content
    @test_throws Exception convert(Char, TclObj("ab"))
    @test_throws Exception TclObj(1.0 - 2.3im)
    @test_throws Exception convert(Complex{Float64}, TclObj(1.0))

    # Conversion to Union{Nothing,T}.
    s = "a non-empty string"
    @test convert(TclTk.NothingOr{String}, TclObj(s)) == s
    @test convert(TclTk.NothingOr{String}, TclObj("")) === nothing
    @test convert(TclTk.NothingOr{Int}, TclObj("")) === nothing
    @test convert(TclTk.NothingOr{Int}, TclObj("-42")) === -42
    @test convert(TclTk.NothingOr{Int16}, TclObj("-42")) === Int16(-42)
    @test_throws ArgumentError convert(TclTk.NothingOr{Int}, TclObj("1.2"))

    # Short/long conversion error messages.
    @test_throws ArgumentError convert(Int, TclObj("yes"))
    @test_throws ArgumentError convert(Int, TclObj("This long string is not an integer and should trigger an exception when attempting to convert it to an integer, you have been warned..."))

    # Symbols as strings.
    sym = :hello
    x = @inferred TclObj(sym)
    @test x.type == :string
    @test x == sym
    @test x == string(sym)
    @test sym === @inferred convert(Symbol, x)
    @test sym === @inferred convert(Symbol, x)
    y = @inferred convert(TclObj, sym)
    @test y.type == x.type # same type
    @test y == x           # same content

    # Tuples.
    x = @inferred TclObj(:hello)
    t = (2, -3, x, 8.25) # a short tuple
    @test x.refcnt == 1
    y = @inferred TclObj(t)
    @test x.refcnt == 2
    @test y.type == :list
    @test length(y) == length(t)
    s = sprint(show, y)
    @test s == "TclObj((2, -3, \"hello\", 8.25,))"
    let i = 1, t_i = t[i], T = typeof(t_i) # 1st item is an `Int`
        @test convert(T, y[i]) == t_i
        @test fetch(T, y, i) === t_i
    end
    let i = 4, t_i = t[i], T = typeof(t_i) # 4th item is a `Float64`
        @test convert(T, y[i]) == t_i
        @test fetch(T, y, i) == t_i
    end
    @test convert(typeof(t), y) == t
    t = (2, -3, x, (0:255)...) # a long tuple
    y = @inferred TclObj(t)
    @test y.type == :list
    @test length(y) == length(t)
    s = sprint(show, y)
    @test startswith(s, "TclObj((2, -3, \"hello\", 0, 1,")
    @test endswith(s, ", 254, 255,))")
    @test match(r"^TclObj\(\(2, -3, .*, \.\.\., .*, 254, 255,\)\)$", s) !== nothing
    @test @inferred(convert(Tuple{Symbol,Int}, TclObj(("hello", 1)))) === (:hello, 1)

    # TODO @test y == t

    # Dense vector of bytes.
    v = [0x00, 0x12, 0xff, 0x4a] # a short vector of bytes
    x = @inferred TclObj(v)
    @test x.type == :bytearray
    @test sprint(show, x) == "TclObj(UInt8[0x00, 0x12, 0xff, 0x4a])"
    @test v == @inferred convert(Vector{UInt8}, x)
    @test v == @inferred Vector{UInt8}(x)
    v = collect(typemin(UInt8):typemax(UInt8)) # a long vector of bytes
    x = @inferred TclObj(v)
    @test x.type == :bytearray
    s = sprint(show, x)
    @test startswith(s, "TclObj(UInt8[0x00, 0x01, 0x02,")
    @test endswith(s, ", 0xfe, 0xff])")
    @test match(r"^TclObj\(UInt8\[0x00, 0x01, .*, \.\.\., .*, 0xfe, 0xff\]\)$", s) !== nothing

    # Colors.
    c = @inferred TclObj TclObj(colorant"pink")
    @test TclObj(colorant"red") ∈ ("#FF0000", "#ff0000")
end

@testset "Tcl Lists" begin
    # NULL object pointer yields empty list.
    let ObjPtr = Ptr{TclTk.Core.Tcl_Obj}
        A = @inferred TclTk.Core.UnsafeList(ObjPtr(0))
        @test length(A) === 0
        @test pointer(A) === Ptr{ObjPtr}(0)
        @test ndims(A) === ndims(typeof(A)) === 1
        @test eltype(A) === eltype(typeof(A)) === ObjPtr
        @test IndexStyle(A) === IndexStyle(typeof(A)) === IndexLinear()
        @test_throws BoundsError A[1]
    end

    # Tcl "list".
    wa = ("", 1, "hello world!", (true, false), -3.75, π)
    wf = (1, "hello", "world!", true, false, -3.75, π) # "concat" version
    wb = @inferred tcl_list(wa...)
    wc = @inferred TclObj(wa)
    @test wb isa TclObj
    @test wc isa TclObj
    @test wb.type == :list
    @test wc.type == :list
    @test @inferred(length(wb)) == length(wa)
    @test @inferred(length(wc)) == length(wa)
    @test wb == wc
    @test all(wb .== wc)
    @test all([wb[i] == TclObj(wa[i]) for i in 1:length(wa)])
    @test all([wc[i] == TclObj(wa[i]) for i in 1:length(wa)])
    @test wb[4].type == :list
    @test wc[4].type == :list
    @test wb[4][1] == TclObj(wa[4][1])
    @test wc[4][2] == TclObj(wa[4][2])

    # Out of range indices throw.
    @test_throws BoundsError wb[0]
    @test_throws BoundsError wb[length(wb)+1]

    # Set index in list.
    wb[1] = 3
    wb[3] = wc[4]
    wb_1 = @inferred TclObj wb[1]
    @test wb_1 isa TclObj
    wb_3 = @inferred TclObj wb[3]
    @test wb_3 isa TclObj
    wc_4 = @inferred TclObj wc[4]
    @test wc_4 isa TclObj
    @test wb_1 == TclObj(3)
    @test wb_3 == wc_4

    # Tcl "concat".
    wd = @inferred tcl_concat(wa...)
    @test wd isa TclObj
    @test wd.type == :list
    @test @inferred(length(wd)) == length(wf)
    @test all([wd[i] == TclObj(wf[i]) for i in 1:length(wf)])

    # List to vectors.
    t = (-1:3...,)
    o = @inferred TclObj(t)
    @test o isa TclObj
    v = @inferred convert(Vector{Int16}, o)
    @test v isa Vector{Int16}
    @test Tuple(v) == t
    v = @inferred convert(Vector{String}, o)
    @test v isa Vector{String}
    @test Tuple(v) == map(string, t)

end

@testset "Tcl Interpreters" begin

    # Lists.
    t = (1, "a b {c d}", 0)
    x = @inferred tcl_list(t...)
    y = @inferred tcl_concat(t...)
    @test x isa TclObj
    @test x.type == :list
    @test length(x) == 3
    @test !isempty(x)
    @test y isa TclObj
    @test length(y) == 5

    # Global variables.
    name, val = "some_name", -12345
    private[name] = val
    @test haskey(private, name)
    @test (@inferred private[name]) isa TclObj
    @test TclObj(val) == @inferred private[name]
    delete!(private, name)
    @test !haskey(private, name)
    name, val = "some_other_name", -13/4
    private[name] = val
    @test haskey(private, name)
    @test TclObj(val) == @inferred private[name]
    private[name] = unset
    @test !haskey(private, name)
    delete!(private, name)

    # Evaluation of scripts.
    name, val = "globvar", 4321
    @test TclObj(val) == @inferred private.eval(TclObj, "set $name $val")
    @test haskey(private, name)
    @test TclObj(val) == @inferred private[name]
    delete!(private, name)
    @test_throws TclError @inferred private.eval("set $name")
    @test TCL_ERROR === @inferred private.eval(TclStatus, "set $name")

    # Execution of commands.
    name, val = "arr(1)", 789
    @test TclObj(val) == @inferred private.exec(TclObj, :set, name, val)
    @test haskey(private, name)
    @test TclObj(val) == @inferred private[name]
    delete!(private, name)
    @test_throws TclError private.exec(:set, name)
    @test TCL_ERROR === @inferred private.exec(TclStatus, "set", name)
    @test TclObj(val) == @inferred private(TclObj, :set, name, val)
    @test haskey(private, name)
    @test TclObj(val) == @inferred private[name]
    delete!(private, name)
    @test_throws TclError private(:set, name)
    @test TCL_ERROR === @inferred private(TclStatus, "set", name)
    @test_throws TclError private(:continue)
    @test_throws TclError private("break")

    # Options and enumeration.
    @test TCL_OK === @inferred private(TclStatus, :return, :code => TCL_OK)
    @test TCL_ERROR === @inferred private(TclStatus, :return, :code => TCL_ERROR)
    @test apple === @inferred private(Fruit, :set, "fruit", apple)
    @test kiwi === @inferred private.eval(Fruit, "set fruit $(Integer(kiwi))")

    # Fetching of values.
    t = (false, -7, 1.5, "text", ('a', 2))
    x = @inferred TclObj(t)
    interp = TclInterp()
    @test length(x) == length(t)
    @test length(x[end]) == 2
    #
    @test @inferred(convert(typeof(t[1]), x[1])) === t[1]
    @test @inferred(fetch(typeof(t[1]), x, 1)) === t[1]
    @test interp.fetch(typeof(t[1]), x, 1) === t[1]
    #
    @test @inferred(convert(typeof(t[2]), x[2])) === t[2]
    @test @inferred(fetch(typeof(t[2]), x, 2)) === t[2]
    @test interp.fetch(typeof(t[2]), x, 2) === t[2]
    #
    @test @inferred(convert(typeof(t[3]), x[3])) === t[3]
    @test @inferred(fetch(typeof(t[3]), x, 3)) === t[3]
    @test interp.fetch(typeof(t[3]), x, 3) === t[3]
    #
    @test @inferred(convert(typeof(t[4]), x[4])) == t[4]
    @test @inferred(fetch(typeof(t[4]), x, 4)) == t[4]
    @test interp.fetch(typeof(t[4]), x, 4) == t[4]
    #
    @test @inferred(convert(typeof(t[5]), x[5])) === t[5]
    @test @inferred(fetch(typeof(t[5]), x, 5)) === t[5]
    @test interp.fetch(typeof(t[5]), x, 5) === t[5]
    #
    inds = [4,3,5]
    s = t[inds]
    @test @inferred(convert(typeof(s), x[inds])) === s
    @test @inferred(fetch(typeof(s), x, [inds...,])) === s
    @test @inferred(fetch(typeof(s), x, (inds...,))) === s
    @test interp.fetch(typeof(s), x, [inds...,]) === s
    @test interp.fetch(typeof(s), x, (inds...,)) === s
    #
    @test @inferred(convert(typeof(t), x)) == t
    @test @inferred(fetch(typeof(t), x)) == t
    @test @inferred(fetch(typeof(t), x, :)) == t
    @test interp.fetch(typeof(t), x) == t
    @test interp.fetch(typeof(t), x, :) == t
    #
    s = (UInt8(t[1]), Int16(t[2]), Float32(t[3]), Symbol(t[4]))
    r = 1:4
    @test @inferred(convert(typeof(s), x[r])) === s
    @test @inferred(convert(typeof(s), x[[true,true,true,true,false]])) === s
    @test @inferred(fetch(typeof(s), x, r)) === s
    @test @inferred(fetch(typeof(s), x, (r...,))) === s
    @test @inferred(fetch(typeof(s), x, [r...,])) === s
    @test interp.fetch(typeof(s), x, r) === s
    @test interp.fetch(typeof(s), x, (r...,)) === s
    @test interp.fetch(typeof(s), x, [r...,]) === s

    # Explicitly delete private interpreter to call finalizer.
    private = 0
    GC.gc()
end

@testset "Events" begin
    # Make sure event handler is not running.
    TclTk.isrunning() && TclTk.suspend()
    @test (@inferred TclTk.isrunning()) === false
    # Create some delayed task.
    TclTk.eval("set jl_counter 0")
    id = TclTk.exec(TclObj, :after, 1, "incr jl_counter")
    sleep(0.1)
    @test TclTk.eval(Int, "set jl_counter") === 0
    TclTk.resume()
    @test (@inferred TclTk.isrunning()) === true
    sleep(0.1) # sleep for a while so that events can be processed
    @test TclTk.eval(Int, "set jl_counter") === 1
    TclTk.suspend()
    @test (@inferred TclTk.isrunning()) === false
end

@testset "Tcl Variables" begin
    # Get default interpreter.
    interp = @inferred TclInterp()

    # Accessing or deleting a non-existing variable is an error.
    tcl_unsetvar("non_existing_variable"; nocomplain=true)
    tcl_unsetvar("non_existing_array"; nocomplain=true)
    @test_throws TclError tcl_getvar("non_existing_variable")
    @test_throws TclError tcl_getvar("non_existing_variable"; flags=TCL_GLOBAL_ONLY)
    @test_throws TclError tcl_getvar(:non_existing_variable)
    @test_throws TclError tcl_getvar(:non_existing_variable; flags=TCL_GLOBAL_ONLY)
    @test_throws TclError tcl_getvar(("non_existing_array", 1))
    @test_throws TclError tcl_getvar(("non_existing_array", 1); flags=TCL_GLOBAL_ONLY)
    @test_throws TclError tcl_getvar(:non_existing_variable)
    @test_throws TclError tcl_getvar(:non_existing_variable; flags=TCL_GLOBAL_ONLY)
    @test_throws TclError tcl_unsetvar(:non_existing_variable)
    @test_throws TclError tcl_unsetvar(:non_existing_variable; flags=TCL_GLOBAL_ONLY)

    # Manage to make any operation on a variable fail. NOTE Errors in `unset` traces are
    # ignored.
    name = "some_name"
    for (op, trace) in TclTk.exec(TclObj, :trace, :info, :variable, name)
        # Remove all existing traces.
        TclTk.exec(:trace, :remove, :variable, name, op, trace)
    end
    trace = "forbidden_operation_on_variable"
    TclTk.eval("""
proc $trace {name1 name2 op} {
    if {\$name2 eq ""} {
        set name "\$name1"
    } else {
        set name "\${name1}(\${name2})"
    }
    error "attempt to \$op variable \\"\$name\\""
}
""")
    tcl_setvar(name, "some_value")
    TclTk.exec(:trace, :add, :variable, name, :read, trace)
    @test_throws TclError tcl_getvar(name)
    TclTk.exec(:trace, :add, :variable, name, :write, trace)
    @test_throws TclError tcl_setvar(name, "some_other_value")
    tcl_unsetvar(name) # this also deletes all traces

    @test_deprecated tcl_setvar("some_name", "some_value")
    @test interp["some_name"] == "some_value"
    @test_deprecated tcl_unsetvar("some_name")
    @test !haskey(interp, "some_name")

    for (name, value) in (("a", 42),
                          ("1", 1),
                          ("", "empty"),
                          ("π", π),
                          ("world is beautiful!", true),
                          # 2-part variable names.
                          (("a", "i"), 42),
                          (("1", "2"), 12),
                          (("", ""), "really empty"),
                          (("π", "φ"), π),
                          (("world is", "beautiful!"), true))

        # First unset variable.
        if name isa Tuple
            @inferred TclTk.exec(TclStatus, "array", "unset", first(name))
        else
            @inferred TclTk.exec(TclStatus, "array", "unset", name)
        end
        @inferred TclTk.exec(TclStatus, "unset", "-nocomplain", name)

        # Symbolic variable name.
        key = name isa Tuple ? map(Symbol, name) : Symbol(name)

        # Set variable.
        if name isa Tuple
            @test_deprecated tcl_setvar(name..., value)
            @test_deprecated tcl_unsetvar(name...)
        end
        @test nothing === @inferred tcl_setvar(name, value)
        obj = @inferred tcl_setvar(TclObj, name, value)
        @test obj isa TclObj
        @test obj == TclObj(value)

        # Get variable.
        T = typeof(value)
        obj = @inferred tcl_getvar(name)
        @test obj isa TclObj
        @test obj == @inferred interp[name]
        @test obj == @inferred interp[key]
        if name isa Tuple
            part1, part2 = name
            x = @inferred interp["$(part1)($(part2))"]
            @test x isa TclObj
            @test obj == x
            y = @test_deprecated tcl_getvar(part1, part2)
            @test y isa TclObj
            @test obj == y
        end
        if value isa Union{String,Integer}
            x = @inferred tcl_getvar(T, name)
            @test x isa T
            @test value == x
            y = @inferred interp[T, name]
            @test y isa T
            @test value == y
        elseif value isa AbstractFloat
            x = @inferred tcl_getvar(T, name)
            @test x isa T
            @test value ≈ x
            y = @inferred interp[T, name]
            @test y isa T
            @test value ≈ y
            @test x == y
        end

        # Test existence and delete variable.
        @test tcl_isassigned(name)
        @test haskey(interp, name)
        @test haskey(interp, key)
        tcl_unsetvar(name)
        @test !tcl_isassigned(name)
        @test !haskey(interp, name)
        @test !haskey(interp, key)

        # Delete with `delete!`.
        interp[name] = value
        @test haskey(interp, name)
        delete!(interp, name)
        @test !haskey(interp, name)

        # Delete with `unset`.
        interp[name] = value
        @test haskey(interp, name)
        interp[name] = unset
        @test !haskey(interp, name)

        # Delete with `tcl_setvar` and `unset`.
        interp[name] = value
        @test haskey(interp, name)
        @test nothing === @inferred tcl_setvar(interp, name, unset)
        @test !haskey(interp, name)

        # Use a Tcl object as the variable name.
        if !(name isa Tuple)
            key = @inferred TclObj(name)
            val = @inferred TclObj(value)
            interp[key] = val
            @test haskey(interp, key)
            obj = @inferred interp[key]
            @test obj isa TclObj
            @test obj == val
            obj = @inferred tcl_getvar(interp, key)
            @test obj isa TclObj
            @test obj == val
            interp[key] = unset
            @test !haskey(interp, key)
            @test nothing === @inferred tcl_setvar(interp, key, val)
            @test haskey(interp, key)
            @test val == @inferred interp[key]
            @test nothing === @inferred tcl_setvar(interp, key, unset)
            @test !haskey(interp, key)
        end
    end

end

const callback_counter = Ref{Int}(0)

function count_callback(interp::TclInterp, args::TclObj)
    global callback_counter
    callback_counter[] += 1
end

function other_count_callback(interp::TclInterp, args::TclObj)
    global callback_counter
    callback_counter[] += 1
    return nothing
end

function yet_another_count_callback(interp::TclInterp, args::TclObj)
    global callback_counter
    callback_counter[] += 1
    return TCL_OK
end

callback_arguments = nothing
function simple_callback(interp::TclInterp, args::TclObj)
    global callback_arguments
    callback_arguments = args
    return TCL_OK, length(args)
end

@testset "Callbacks" begin
    # Create a simple callback in a private interpreter.
    private = @inferred TclInterp(:private)
    f = @inferred TclCallback(count_callback, private)

    # Callback properties.
    @test length(@inferred propertynames(f)) == 4
    @test :func ∈ @inferred propertynames(f)
    @test :token ∈ @inferred propertynames(f)
    @test :interp ∈ @inferred propertynames(f)
    @test :name ∈ @inferred propertynames(f)
    @test f.interp === private
    @test f.func == count_callback
    @test f.token isa Ptr
    @test_throws KeyError f.non_existing_property = 1
    @test_throws Exception f.name = "some_other_name"
    proc = f.name
    @test proc isa String
    @test startswith(proc, "::jl_func_")
    s = sprint(show, f)
    @test match(r"\bCallback:.*::jl_func_.*", s) !== nothing
    s = sprint((io, x) -> show(io, MIME"text/plain"(), x), f)
    @test match(r"\bCallback:.*::jl_func_.*", s) !== nothing

    # Exercise the callback.
    callback_counter[] = 0
    @test 1 == private(Int, proc)
    @test 1 == callback_counter[]
    @test 2 == private(Int, proc, pi)
    @test 2 == callback_counter[]
    @test 3 == private(Int, proc)
    @test 3 == callback_counter[]
    @test 4 == private(Int, proc, "a", "b", (1, 2))
    @test 4 == callback_counter[]

    # Rename the callback in the same namespace and then in another namespace.
    newname = "jl_some_other_func_name"
    f.interp(:rename, f.name, newname)
    @test f.name == "::"*newname
    ns = "another::namespace"
    f.interp.eval("namespace eval ::$ns {}")
    f.interp(:rename, f.name, ns*"::"*newname)
    @test f.name == "::"*ns*"::"*newname

    # Delete command.
    @test TclTk.deletecommand(f) == true
    @test TclTk.deletecommand(private, proc) == false

    # Deal with other returned values.
    f1 = @inferred TclCallback(other_count_callback, private)
    f2 = @inferred TclCallback(yet_another_count_callback, private)
    callback_counter[] = 0
    @test @inferred(private(String, f1.name)) == ""
    @test callback_counter[] == 1
    @test @inferred(private(String, f2.name)) == ""
    @test callback_counter[] == 2
    @test TclTk.deletecommand(f1.interp, f1.name) == true
    @test TclTk.deletecommand(f1.interp, f1.name) == false

    # A more complex callback in the shared interpreter.
    interp = @inferred TclInterp()
    name = "jl_simple_callback"
    f = @inferred TclCallback(simple_callback, name)
    @test f.interp === interp
    proc = f.name
    @test proc isa String
    @test proc == "::"*name
    # Call simple callback with no arguments.
    @test 1 == interp(Int, proc)
    @test callback_arguments isa TclObj
    @test callback_arguments.type == :list
    @test length(callback_arguments) == 1
    @test callback_arguments[1] == proc
    # Call simple callback with 3 arguments.
    @test 4 == interp(Int, proc, "hello", 4.125, true)
    @test callback_arguments isa TclObj
    @test callback_arguments.type == :list
    @test length(callback_arguments) == 4
    @test callback_arguments[1] == proc
    @test callback_arguments[2] == "hello"
    @test callback_arguments[3] == TclObj(4.125)
    @test callback_arguments[4] == TclObj(true)
    @test TclTk.deletecommand(proc) == true
    @test TclTk.deletecommand(proc) == false

    private = 0
    sleep(0.01)
    GC.gc()
end

@testset "Linked variables" begin
    name = "::GLOBAL_COUNTER"
    A = @inferred TclVariable{Int}(name)
    @test eltype(A) === Int
    @test A.name == name
    @inferred tcl_eval("unset -nocomplain $(A.name)")
    @test tcl_isassigned(A) == false
    @test isassigned(A) == false
    s = sprint(show, MIME"text/plain"(), A)
    @test startswith(s, "TclVariable{")
    @test endswith(s, ", value: #undef)")
    A[] = 0
    @test @inferred(A[]) === 0
    @test tcl_isassigned(A) == true
    @test isassigned(A) == true
    s = sprint(show, MIME"text/plain"(), A)
    @test startswith(s, "TclVariable{")
    @test endswith(s, ", value: 0)")
    A[] += 3
    @test @inferred(A[]) === 3
    @test tcl_getvar(eltype(A), A.interp, A.name) == 3
    @inferred tcl_eval("incr $(A.name) -2")
    @test @inferred(A[]) === 1
    B = @inferred TclVariable(A.name, A.interp) # same variable but no given type
    @test @inferred(B[]) isa TclObj
    @test @inferred(convert(eltype(A), B[])) === A[]
    @test @inferred(B[eltype(A)]) === A[]
    x = A[]
    B[] = x + 7
    @test @inferred(A[]) === x + 7
    @test @inferred(B[eltype(A)]) === x + 7

    # Test various ways to unset a variable.
    delete!(A)
    @test !isassigned(A)
    delete!(A) # delete more than once is allowed
    @test !isassigned(A)
    A[] = 0
    @test isassigned(A)
    tcl_unsetvar(A)
    @test !isassigned(A)
    @test_throws Exception tcl_unsetvar(A) # unset more than once is not allowed
    A[] = 0
    @test isassigned(A)
    A[] = unset
    @test !isassigned(A)
    A[] = 0
    @test isassigned(A)

end

end # module
