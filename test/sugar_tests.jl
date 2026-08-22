using MacroDefaults

# A stand-in for a downstream macro library: the macro bodies use @preference
# WITHOUT passing a module, and the escaped __module__ must resolve to the
# module that expands THESE macros.
module PrefMacroHost
using MacroDefaults

macro bare()
    @preference("sugar")
end

macro withdefault(default)
    @preference("sugar", default; deprecated_keys = ("oldsugar",))
end

macro boolknob()
    @preference("flag")
end

end

@testset "@preference macro" begin
    with_pref, _ = Fixtures.make_package(Dict("sugar" => "yes", "flag" => false))
    alias_only, _ = Fixtures.make_package(Dict("oldsugar" => "legacy"))
    no_pref, _ = Fixtures.make_package()

    # Expanding PrefMacroHost macros inside each fixture module resolves
    # __module__ to THAT fixture, so its LocalPreferences.toml governs.
    @test Core.eval(with_pref, :(Main.PrefMacroHost.@bare())) == "yes"
    @test Core.eval(no_pref, :(Main.PrefMacroHost.@bare())) === nothing
    @test Core.eval(no_pref, :(Main.PrefMacroHost.@withdefault("fallback"))) == "fallback"
    # Bool values pass through as plain values (not treated as missing)
    @test Core.eval(with_pref, :(Main.PrefMacroHost.@boolknob())) === false
    # deprecated alias: first hit wins, depwarn fires (forced)
    @test (@test_warn "deprecated" Core.eval(
        alias_only, :(Main.PrefMacroHost.@withdefault("fallback")))) == "legacy"

    # vector form of deprecated_keys is accepted too
    @test preference(alias_only, "sugar"; deprecated_keys = ["oldsugar"]) ==
          Some{Any}("legacy")
end

@testset "macroparse" begin
    args = Any[LineNumberNode(1), :(mode = "warn"), :(n = 3)]
    @test macroparse(args, :mode) === Some{Any}("warn")
    @test macroparse(args, :n) === Some{Any}(3)
    @test macroparse(args, :absent) === nothing
    # explicit option beats the macro's default, loses to LocalPreferences
    @test (@something macroparse(args, :mode) "dflt") == "warn"
    @test (@something macroparse(args, :absent) "dflt") == "dflt"
end
