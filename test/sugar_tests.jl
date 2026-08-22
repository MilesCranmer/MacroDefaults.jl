using MacroDefaults

# A stand-in for a downstream macro library: the macro body uses @preference
# WITHOUT passing a module, and the escaped __module__ must resolve to the
# module that expands THIS macro.
module PrefMacroHost
using MacroDefaults

macro prefonly()
    @something @preference("sugar") "fallback"
end

end

@testset "@preference macro" begin
    with_pref, _ = Fixtures.make_package(Dict("sugar" => "yes"))
    no_pref, _ = Fixtures.make_package()

    # Expanding PrefMacroHost.@prefonly inside each fixture module resolves
    # __module__ to THAT fixture, so its LocalPreferences.toml governs.
    @test Core.eval(with_pref, :(Main.PrefMacroHost.@prefonly())) == "yes"
    @test Core.eval(no_pref, :(Main.PrefMacroHost.@prefonly())) == "fallback"
end

@testset "macroparse" begin
    args = Any[LineNumberNode(1), :(mode = "warn"), :(n = 3)]
    @test macroparse(args, :mode) === Some{Any}("warn")
    @test macroparse(args, :n) === Some{Any}(3)
    @test macroparse(args, :absent) === nothing
    # precedence slotting: explicit option beats default, loses to preference
    @test (@something macroparse(args, :mode) "dflt") == "warn"
    @test (@something macroparse(args, :absent) "dflt") == "dflt"
end
