@testset "UUID resolution" begin
    anon = @eval Main module $(gensym("AnonMod")) end
    @test MacroDefaults._uuid(anon) === nothing
    @test isempty(MacroDefaults.UUIDS)  # Main-rooted modules are never cached

    m, _ = Fixtures.make_package()
    uuid = MacroDefaults._uuid(m)
    @test uuid isa Base.UUID
    @test MacroDefaults._uuid(m) === uuid  # cached
    @test MacroDefaults.UUIDS[m] === uuid

    # A module nested inside the package module resolves to the package UUID
    inner = m.eval(:(module $(gensym("Inner")) end))
    @test MacroDefaults._uuid(inner) === uuid
end
