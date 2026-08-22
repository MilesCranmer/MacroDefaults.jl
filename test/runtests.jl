using Test
using MacroDefaults

include("fixtures.jl")
using .Fixtures: make_package

include("uuid_tests.jl")
include("preference_tests.jl")
include("module_default_tests.jl")
include("contract_tests.jl")
include("invalidation_tests.jl")
include("sugar_tests.jl")
