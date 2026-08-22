module Fixtures

const COUNTER = Ref(0)

"""
    make_package(prefs::Dict{<:String}=Dict{String,Any}()) -> (Module, String)

Create a throwaway package in a temp directory, push the directory onto
`LOAD_PATH`, load the package, and return `(module, directory)`. `prefs`
is written as the package's own section of `LocalPreferences.toml`.
"""
function make_package(prefs::Dict{<:String}=Dict{String,Any}())
    COUNTER[] += 1
    name = "FixturePkg$(COUNTER[])"
    dir = mktempdir()
    open(joinpath(dir, "Project.toml"), "w") do io
        println(io, "name = \"$name\"")
        println(io, "uuid = \"$(string(Base.UUID(rand(UInt128))))\"")
        println(io, "version = \"0.1.0\"")
    end
    mkpath(joinpath(dir, "src"))
    open(joinpath(dir, "src", "$name.jl"), "w") do io
        println(io, "module $name")
        println(io, "end")
    end
    if !isempty(prefs)
        open(joinpath(dir, "LocalPreferences.toml"), "w") do io
            println(io, "[$name]")
            for (k, v) in sort(collect(prefs); by=first)
                if v isa AbstractString
                    println(io, "$k = \"$(escape_string(v))\"")
                else
                    println(io, "$k = $v")
                end
            end
        end
    end
    push!(LOAD_PATH, dir)
    # Base.require sidesteps the stale-binding world-age error that
    # `eval(:(using ...))` + `getfield` hits on Julia 1.12.
    return Base.require(Main, Symbol(name)), dir
end

end
