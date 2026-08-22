# MacroDefaults.jl

Declare overridable default settings for your macros. Downstream packages
configure your macros per-package by writing to their own `LocalPreferences.toml`
(using Preferences.jl). Values resolve once, at macro-expansion time, in the
calling package, and are cached for the session.

## For macro authors

```julia
module MyMacros
using MacroDefaults

macro mymacro(args...)
    mode = @something @preference("mymacros_mode") macroparse(args, :mode) "error"
    ...
end

end
```

Precedence reads left to right: the calling package's `LocalPreferences.toml`
entry beats an explicit `@mymacro mode="warn" ...` option, which beats the
hardcoded default. `@preference` may only be used inside a macro body (it
captures `__module__` for you); the underlying function form
`preference(__module__, key)` remains available, as does
`macroparse(args, :key)` for extracting one `key=value` macro option.

The preference key lives in the *calling* package's `LocalPreferences.toml`:

```toml
[PackageThatUsesMyMacros]
mymacros_mode = "warn"
```

Prefer `<package>_<setting>` key names: every library reading a downstream
package's preferences shares one flat namespace.

## For downstream users

Set keys in your package's `LocalPreferences.toml` (typically via
`Preferences.set_preferences!("YourPackage", "mymacros_mode" => "warn")`),
then restart Julia. Values are read once per session and baked into your
package's precompiled code; packages re-precompile automatically when the
preference changes.

## Programmatic per-module defaults

`set_module_default!(mod, key, value)` registers an in-code default that
loses to an explicit preference. Call it before any macro using `key`
expands in `mod`; later conflicting calls throw `TooLateError`. Read it inside your
macro with `@something preference(__module__, key) module_default(__module__, key, fallback)`.
