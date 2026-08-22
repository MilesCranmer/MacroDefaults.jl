using Preferences: set_preferences!
using Aqua

@testset "compile-time contract" begin
    m, _ = Fixtures.make_package(Dict("k" => "first"))
    @test preference(m, "k") === Some{Any}("first")
    # Mutating preferences after first read must NOT change the session result
    set_preferences!(String(nameof(m)), "k" => "second")
    @test preference(m, "k") === Some{Any}("first")
    MacroDefaults._reset_for_testing!()
end

@testset "thread safety" begin
    m, _ = Fixtures.make_package(Dict("hammer" => 42))
    set_module_default!(m, "hammer_mod", false)
    failures = Threads.Atomic{Int}(0)
    Threads.@threads for i in 1:256
        try
            v = @something preference(m, "hammer") 0
            v == 42 || Threads.atomic_add!(failures, 1)
            module_default(m, "hammer_mod", nothing) === false ||
                Threads.atomic_add!(failures, 1)
            i % 64 == 0 && set_module_default!(m, "hammer_mod", false)  # idempotent
        catch
            Threads.atomic_add!(failures, 1)
        end
    end
    @test failures[] == 0
    MacroDefaults._reset_for_testing!()
end

@testset "Aqua" begin
    Aqua.test_all(MacroDefaults)
end
