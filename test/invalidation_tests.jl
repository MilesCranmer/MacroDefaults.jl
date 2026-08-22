@testset "pkgimage invalidation" begin
    pkgname = "InvalPkg"
    root = mktempdir()                       # active env for child processes
    macrodefaults_dir = pkgdir(MacroDefaults)
    fixture_dir = joinpath(root, "packages", pkgname)
    mkpath(joinpath(fixture_dir, "src"))
    open(joinpath(fixture_dir, "Project.toml"), "w") do io
        println(io, "name = \"$pkgname\"")
        println(io, "uuid = \"$(string(Base.UUID(rand(UInt128))))\"")
        println(io, "version = \"0.1.0\"")
        println(io, "[deps]")
        println(io, "MacroDefaults = \"$(string(Base.PkgId(MacroDefaults).uuid))\"")
    end
    open(joinpath(fixture_dir, "src", "$pkgname.jl"), "w") do io
        println(io, "module $pkgname")
        println(io, "using MacroDefaults: preference")
        println(io, "using Base: @something")
        println(io, "const MODE = @something preference(@__MODULE__, \"inval_mode\") :default")
        println(io, "end")
    end
    open(joinpath(root, "Project.toml"), "w") do io
        println(io, "[deps]")
        println(io, "MacroDefaults = \"$(string(Base.PkgId(MacroDefaults).uuid))\"")
    end
    # One-time setup: develop both packages into the child env and precompile.
    setup = """
    using Pkg
    Pkg.develop(path="$(macrodefaults_dir)")
    Pkg.develop(path="$(fixture_dir)")
    Pkg.precompile()
    """
    run(`$(Base.julia_cmd()) --project=$root --startup-file=no -e $setup`)
    # Each child loads InvalPkg (already precompiled) and asserts on the value
    # that was baked into its precompiled code.
    # Returns true so each child check records as a passing @test; `run`
    # throws on a nonzero exit, which Test reports as an Error.
    child(expr) = (run(`$(Base.julia_cmd()) --project=$root --startup-file=no -e $expr`); true)

    @testset "absent then present" begin
        @test child("using InvalPkg; @assert InvalPkg.MODE === :default")
        open(joinpath(root, "LocalPreferences.toml"), "w") do io
            println(io, "[InvalPkg]")
            println(io, "inval_mode = \"warn\"")
        end
        @test child("using InvalPkg; @assert InvalPkg.MODE === \"warn\"")
    end

    @testset "value change" begin
        open(joinpath(root, "LocalPreferences.toml"), "w") do io
            println(io, "[InvalPkg]")
            println(io, "inval_mode = \"error\"")
        end
        @test child("using InvalPkg; @assert InvalPkg.MODE === \"error\"")
    end
end
