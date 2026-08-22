@testset "module_default" begin
    m = @eval Main module $(gensym("MDMod")) end

    # fallback used when unset, and the read tombstones the slot
    @test module_default(m, "k", true) === true
    err = try
        set_module_default!(m, "k", false)
        nothing
    catch e
        e
    end
    @test err isa TooLateError
    @test err.mod === m
    @test err.key == "k"

    # set before any read is fine; reads return it; conflicting set now throws
    m2 = @eval Main module $(gensym("MDMod")) end
    set_module_default!(m2, "k", false)
    @test module_default(m2, "k", true) === false
    @test_throws TooLateError set_module_default!(m2, "k", true)

    # idempotent re-set is allowed
    set_module_default!(m2, "k", false)
    @test module_default(m2, "k", true) === false

    # keys are independent
    @test module_default(m2, "other", :d) === :d
end
