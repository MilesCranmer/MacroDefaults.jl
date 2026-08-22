module MacroDefaults

using Preferences: load_preference, get_uuid

export preference, module_default, set_module_default!, TooLateError, macroparse, @preference

struct TooLateError <: Exception
    mod::Module
    key::String
end

const LOCK = ReentrantLock()
const UUIDS = Dict{Module,Union{Base.UUID,Nothing}}()                  # nothing = not a package
const PREFS = Dict{Tuple{Base.UUID,String},Union{Some{Any},Nothing}}() # nothing = key absent
const MODULE_DEFAULTS = Dict{Tuple{Module,String},Any}()
const READ = Set{Tuple{Module,String}}()                               # lock-in tombstones

_try_uuid(m) = try get_uuid(m) catch; nothing end
function _uuid(m::Module)
    # Main-rooted modules: never cached, so Preferences.main_uuid[] toggling works.
    Base.moduleroot(m) === Main && return _try_uuid(m)
    Base.@lock LOCK begin
        get!(() -> _try_uuid(m), UUIDS, m)
    end
end
"""
    preference(mod, key; deprecated_keys=()) -> Union{Some{Any}, Nothing}

Cached lookup of `key` in the package preferences of `mod`'s package.
Compile-time contract: the first result per session wins; restart Julia to
pick up changed preferences. Apply defaults with `Base.@something`.

`deprecated_keys` are probed in order when `key` is absent; the first set
entry wins and emits a `depwarn` (forced, even under `--depwarn=no`).
"""
function preference(mod::Module, key::String; deprecated_keys::Tuple{Vararg{String}}=())
    uuid = _uuid(mod)
    uuid === nothing && return nothing
    local dep_key = nothing
    entry = Base.@lock LOCK begin
        get!(PREFS, (uuid, key)) do
            v = load_preference(uuid, key, nothing)
            if v === nothing
                for dk in deprecated_keys
                    v = load_preference(uuid, dk, nothing)
                    v === nothing || (dep_key = dk; break)
                end
            end
            v === nothing ? nothing : Some{Any}(v)
        end
    end
    # Emit outside the lock so user logger code never runs under it.
    dep_key === nothing || Base.depwarn(
        "Preference key `$dep_key` is deprecated; use `$key`.", :preference;
        force=true)
    return entry
end
"""
    module_default(mod, key, fallback)

Read the programmatic per-module default for `key` (see `set_module_default!`),
or `fallback` if none is stored. Reading locks `(mod, key)` against later
conflicting sets.
"""
function module_default(mod::Module, key::String, fallback)
    Base.@lock LOCK begin
        push!(READ, (mod, key))
        get(MODULE_DEFAULTS, (mod, key), fallback)
    end
end

"""
    set_module_default!(mod, key, value)

Register a per-module default for `key`, consulted only when no preference is
set. Throws `TooLateError` if `(mod, key)` was already read and `value`
conflicts with the stored default. Re-setting the same value is allowed.
Call this before any macro using the key has expanded in `mod`.
"""
function set_module_default!(mod::Module, key::String, value)
    Base.@lock LOCK begin
        if (mod, key) in READ &&
           !(haskey(MODULE_DEFAULTS, (mod, key)) &&
             isequal(MODULE_DEFAULTS[(mod, key)], value))
            throw(TooLateError(mod, key))
        end
        MODULE_DEFAULTS[(mod, key)] = value
    end
    return nothing
end

"""
    macroparse(args, key) -> Union{Some{Any}, Nothing}

Extract one keyword-style option from macro arguments: scans `args` for
`Expr(:(=), key, rhs)` and returns `Some(rhs)`, else `nothing`. Slot it
between a preference and a default so an explicit call-site option beats
the default but loses to the caller's LocalPreferences.toml entry:

    mode = @something @preference("mymacros_mode") macroparse(args, :mode) "error"

The right-hand side is returned as-is: literals arrive as values; anything
else arrives as an unevaluated expression for the host to handle.
"""
function macroparse(args, key::Symbol)
    for a in args
        a isa Expr && a.head === :(=) && a.args[1] === key &&
            return Some{Any}(a.args[2])
    end
    return nothing
end

"""
    @preference(key)

Sugar for use INSIDE MACRO BODIES: equivalent to
`preference(__module__, key)` with the calling module captured
automatically. Works because the escaped `__module__` resolves when the
enclosing macro expands, at which point it is bound to that macro's
caller. Anywhere else it raises `UndefVarError`. Returns
`Union{Some{Any}, Nothing}` like [`preference`](@ref).
"""
macro preference(key)
    esc(:(preference(__module__, $key)))
end

# Unexported, test-only. Not part of the public contract.
function _reset_for_testing!()
    Base.@lock LOCK begin
        empty!(UUIDS)
        empty!(PREFS)
        empty!(MODULE_DEFAULTS)
        empty!(READ)
    end
end
end
