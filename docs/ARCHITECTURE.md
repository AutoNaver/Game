# Architecture

## Layers

```
data/*.json ──► sim/defs (GameDataLoader → GameData)       static, read-only
                        │
                        ▼
               sim/state (WorldState, City, MarketRecord, Ship…) mutable, serializable
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
km/h. `tools/map/render_map.py` renders `assets/map/baltic.png` from Natural Earth coastlines and
lakes with the same projection, so the picture and the simulation always line up. At zoom 1 the
whole map fits the view (`MapView`).

Ships sail along **sea lanes** (`data/sea_lanes.json`): cities and open-sea waypoints joined by
straight lanes. `SeaChart` finds the shortest route (Dijkstra, deterministic tie-break) and
`Navigation` moves ships along it at a steady pace. `tools/map/check_lanes.py` and
`tests/unit/test_sea_lanes.gd` check that no lane crosses land away from a harbour. River lanes
(`rivers` in `data/sea_lanes.json`, up the Neva and the Volkhov to Novgorod) are sailed like any
lane but exempt from that check: the renderer draws them as waterways, and they are checked by
eye on the overlay (ADR 0012).

## Time

`Simulation.tick()` advances one hour and moves every ship at sea (`MovementSystem`; storms slow
ships to and from their city). Then ships
on trade routes act at their stops (`RouteSystem`, ADR 0007), and the rival houses' docked ships
trade and sail (`RivalSystem`, ADR 0008). Both issue ordinary commands through
`Simulation.execute` like any player action. Every 24 ticks it runs the daily systems in a fixed
order: world events (`EventSystem`, ADR 0011), spoilage of goods in ships and kontors
(`SpoilageSystem`), city production, the traders' workshops (`WorkshopSystem`), consumption, city
satisfaction and population (`PopulationSystem`, ADR 0010), off-map trade (`OffMapTradeSystem`),
`PriceHistorySystem`, which records each market's closing price for save compatibility, and finally
the rivals' daily step (kontor supplies, closing and expansion). `MarketKnowledgeSystem` then
refreshes reports where each trader has presence and appends observed prices or gaps to that
trader's chart. Current market prices are derived from stock by `Pricing`; a `MarketRecord` stores
the price and stock a trader last observed. Ships carry a snapshot from their departure port and
exchange it with other houses' docked ships on arrival. The UI's speed setting decides how many
ticks run per real second, so pausing is simply running zero ticks.

Read-only queries such as `TradePlanner` (cargo suggestions, also the rivals' choice of load) and
`HouseValue` (net worth) also live in `sim/`, so they are tested headless, but they never change
state. Notifications (ship arrived, workshop stopped, a rival's new ship or workshop, events
starting and ending, goods lost) are found by
the UI's `GameSession`, which compares state before and after each step.

The market panel, destination planner and route editor use the player's market book. Unknown cities
have no quoted prices; remote reports show their observation day. Rivals use their own books for
voyage choices. The player remains ashore in the starting city until M13 adds personal movement.

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
start, version 1 to 4 saves get neutral city satisfaction, version 1 to 5 saves get no world
events or spoilage carries, version 1 to 6 saves get the cities, goods and rival houses of the
larger world added as a new game starts them, and version 1 to 7 saves get a one-time report of
every current market to preserve previously visible information). Version 8 saves market books
and ship news. City populations change in play, so saves check them against the
bounds in `data/population.json` rather than `data/cities.json`. Every trader in a save must be
the player or a house from `data/rivals.json`, in that order (the player first, then the houses in
data order), since the systems act in that order. Saves are named slots in `user://saves`, plus an
autosave every few in-game days.

## Testing

- **Unit tests** (`tests/unit/`) cover single classes and systems with fixtures.
- **Integration tests** (`tests/integration/`) run multi-day scenarios through the command API.
- **Soak** (`tools/soak.gd`, from M1) runs a year headless and asserts the economy invariants.
- `scripts/check.sh` runs formatting, lint, a typed parse check of every script, and the tests.
  CI runs the same script.
