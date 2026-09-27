# Architecture

## Layers

```
data/*.json ──► sim/defs (GameDataLoader → GameData)       static, read-only
                        │
                        ▼
               sim/state (WorldState, City, Market, Ship…)   mutable, serializable
                        ▲            │
      sim/commands ─────┘            │  read-only access
   (validate + apply)                ▼
            ▲                  ui/ (scenes, panels, map)
            └──── player input ──────┘
      sim/systems: run by Simulation.tick() (hourly: ships; daily: production,
                   consumption, prices)
```

- **`sim/defs`** holds typed definitions loaded once from JSON. `GameDataLoader` collects *all*
  validation errors with `<file>[<index>]: <message>` context. `GameData` exposes ordered arrays for
  deterministic iteration and lookup maps for access by id.
- **`sim/state`** is everything that changes and gets saved. It holds plain data plus small
  helpers, and no rules.
- **`sim/systems`** are stateless rule functions that mutate state for one tick or day.
- **`sim/commands`** are the only way actions enter the simulation. Each command has
  `validate(state) -> String` (an empty string means OK) and `apply(state)`. The UI and the future AI
  both use them.
- **`ui/`** holds Godot scenes. They observe state after each tick and send commands. They never
  mutate state directly.

## Time

`Simulation.tick()` advances one hour and moves every ship at sea (`MovementSystem`). Every 24 ticks it runs the daily systems in a fixed order:
production, then consumption. Prices are not stored. `Pricing` derives them from current stock
whenever they are needed, so they can never go stale. The UI's speed setting decides how many ticks
run per real second, so pausing is simply running zero ticks.

## Determinism

One seeded `RandomNumberGenerator` lives in the world state and is serialized with it. Systems
iterate over ordered arrays. Given the same seed, data and command sequence, two runs produce
identical state. A test will enforce this from M1.

## Saving

`WorldState.to_dict()` / `from_dict()` produce plain JSON-compatible dictionaries with
`save_version`. Definitions are *not* saved. Saves reference goods and cities by id and are
validated against the loaded `GameData` on load.

## Testing

- **Unit tests** (`tests/unit/`) cover single classes and systems with fixtures.
- **Integration tests** (`tests/integration/`) run multi-day scenarios through the command API.
- **Soak** (`tools/soak.gd`, from M1) runs a year headless and asserts the economy invariants.
- `scripts/check.sh` runs formatting, lint, a typed parse check of every script, and the tests.
  CI runs the same script.
