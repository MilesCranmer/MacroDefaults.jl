@testset "preference" begin
    @testset "absent and present" begin
        m, _ = Fixtures.make_package(Dict("s" => "warn", "i" => 3, "b" => true))
        @test preference(m, "s") === Some{Any}("warn")
        @test preference(m, "i") === Some{Any}(3)
        @test preference(m, "b") === Some{Any}(true)
        @test preference(m, "missing_key") === nothing
        @test (@something preference(m, "missing_key") 7) == 7
    end

    @testset "deprecated keys" begin
        m1, _ = Fixtures.make_package(Dict("old_key" => "oldval"))
        @test (@test_warn "deprecated" preference(m1, "new_key"; deprecated_keys=("old_key",))) === Some{Any}("oldval")
        # warn fires once per (uuid, key) per session
        @test (@test_nowarn preference(m1, "new_key"; deprecated_keys=("old_key",))) === Some{Any}("oldval")

        m2, _ = Fixtures.make_package(Dict("dep_b" => 2, "dep_a" => 1))
        @test (@test_warn "deprecated" preference(m2, "primary"; deprecated_keys=("dep_a", "dep_b"))) === Some{Any}(1)

        m3, _ = Fixtures.make_package(Dict("primary" => "new", "old_key" => "old"))
        @test preference(m3, "primary"; deprecated_keys=("old_key",)) === Some{Any}("new")
    end

    @testset "no-UUID module" begin
        anon = @eval Main module $(gensym("AnonP")) end
        @test preference(anon, "anything") === nothing
    end
end
