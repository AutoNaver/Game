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
  `validate(state) -> String` (an empty string means OK) and `apply(state)`. The UI and the rival
  houses' AI (`RivalSystem`) both use them.
- **`ui/`** holds Godot scenes. They observe state after each tick and send commands. They never
  mutate state directly.

## Map

`data/map.json` defines the map frame and projection (`MapDef`). Cities are given as `[lon, lat]`
and projected to **map units = kilometres** from the frame's north-west corner, so ship speeds are
km/h. `tools/map/render_map.py` renders `assets/map/baltic.png` from Natural Earth coastlines with
the same projection, so the picture and the simulation always line up.

Ships sail along **sea lanes** (`data/sea_lanes.json`): cities and open-sea waypoints joined by
straight lanes. `SeaChart` finds the shortest route (Dijkstra, deterministic tie-break) and
`Navigation` moves ships along it at a steady pace. `tools/map/check_lanes.py` and
`tests/unit/test_sea_lanes.gd` check that no lane crosses land away from a harbour.

## Time

`Simulation.tick()` advances one hour and moves every ship at sea (`MovementSystem`; storms slow
ships to and from their city). Then ships
on trade routes act at their stops (`RouteSystem`, ADR 0007), and the rival houses' docked ships
trade and sail (`RivalSystem`, ADR 0008). Both issue ordinary commands through
`Simulation.execute` like any player action. Every 24 ticks it runs the daily systems in a fixed
order: world events (`EventSystem`, ADR 0011), spoilage of goods in ships and kontors
(`SpoilageSystem`), city production, the traders' workshops (`WorkshopSystem`), consumption, city
satisfaction and population (`PopulationSystem`, ADR 0010), off-map trade (`OffMapTradeSystem`),
`PriceHistorySystem`, which records each market's closing price for the UI's charts, and finally the rivals' daily step (kontor supplies, closing and expansion). Current
prices are not stored: `Pricing` derives them from current stock whenever they are needed, so they
can never go stale. The UI's speed setting decides how many ticks run per real second, so pausing
is simply running zero ticks.

Read-only queries such as `TradePlanner` (cargo suggestions, also the rivals' choice of load) and
`HouseValue` (net worth) also live in `sim/`, so they are tested headless, but they never change
state. Notifications (ship arrived, workshop stopped, a rival's new ship or workshop, events
starting and ending, goods lost) are found by
the UI's `GameSession`, which compares state before and after each step.

## Determinism

One seeded `RandomNumberGenerator` lives in the world state and is serialized with it. Systems
iterate over ordered arrays. Given the same seed, data and command sequence, two runs produce
identical state. A test will enforce this from M1.

## Saving

`SaveGame.to_dict()` / `from_dict()` turn a `WorldState` into a plain JSON-compatible dictionary
with `save_version` and back. Definitions are *not* saved. Saves reference goods and cities by id
and are validated against the loaded `GameData` on load, then checked with `EconomyInvariants`.
Older versions are migrated in `from_dict()` (version 1 saves get an empty price history,
version 1 and 2 saves get no trade routes, version 1 to 3 saves get the rival houses as they
start, version 1 to 4 saves get neutral city satisfaction, and version 1 to 5 saves get no world
events or spoilage carries). City populations change in play, so saves check them against the
bounds in `data/population.json` rather than `data/cities.json`. Every trader in a save must be
the player or a house from `data/rivals.json`. Saves are named slots in `user://saves`, plus an autosave every few in-game days.

## Testing

- **Unit tests** (`tests/unit/`) cover single classes and systems with fixtures.
- **Integration tests** (`tests/integration/`) run multi-day scenarios through the command API.
- **Soak** (`tools/soak.gd`, from M1) runs a year headless and asserts the economy invariants.
- `scripts/check.sh` runs formatting, lint, a typed parse check of every script, and the tests.
  CI runs the same script.
