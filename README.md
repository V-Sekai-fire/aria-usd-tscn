# AriaUsdTscn

TSCN ↔ USD conversion package for Elixir.

## Overview

This package provides bidirectional conversion between Godot TSCN (scene format) and USD. It depends on `aria_usd` for core USD operations.

## Installation

Add `aria_usd_tscn` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:aria_usd_tscn, path: "../apps/aria_usd_tscn"},
    {:aria_usd, git: "https://github.com/V-Sekai-fire/aria-usd.git"}
  ]
end
```

## Usage

```elixir
# Convert USD to TSCN
AriaUsdTscn.usd_to_tscn("model.usd", "output.tscn")

# Convert TSCN to USD (requires pre-parsed TSCN data)
AriaUsdTscn.tscn_to_usd("scene.tscn", "output.usd", tscn_data: parsed_data)
```

## Note

TSCN ↔ USD conversion has loss due to different scene graph representations between Godot and USD.

## Requirements

- Elixir ~> 1.18
- `aria_usd` package
- USD Python bindings (pxr)

## License

MIT

