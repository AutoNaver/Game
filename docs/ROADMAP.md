# Roadmap

Each milestone ends with something a human can run. Tick items in the PR that completes them.
Work top to bottom unless the owner reprioritizes.

## M0: Foundation

- [x] Godot 4.7 project, repo layout, `.gitignore`/`.gitattributes`/`.editorconfig`
- [x] AGENTS.md (with Codex review guidelines) and CLAUDE.md
- [x] Docs skeleton: GAME_DESIGN, ROADMAP, ARCHITECTURE, first ADRs
- [x] GUT 9.7.1 vendored and `.gutconfig.json`
- [x] `scripts/check.sh`: gdformat, gdlint, headless import, typed parse check, GUT
- [x] CI workflow (`ci` job) and PR template
- [x] Data loader for goods and cities with validation and tests
- [x] Placeholder main scene showing the loaded data
- [x] Branch protection on `main` (required `ci`, up to date, resolved conversations, admins enforced)
- [ ] First PR reviewed by Codex. Blocked: the Codex GitHub app hasn't responded yet, so check it's connected for this repo

## M1: Economy core (headless)

- [x] ADR 0003: pricing curve, spread, and per-unit price walk (`sim/systems/pricing.gd`, `data/economy.json`)
- [x] City state: population, market stock per good, derived target stock (`CityState`, `CityEconomy`)
- [x] Data: city production specialties and per-capita consumption
- [x] Daily systems: production (idles at the stock cap), then consumption (records shortages). Prices are derived from stock on demand
- [x] `Simulation` with seeded RNG and a `tick()` / `advance_days()` API
- [x] `tools/soak.gd` plus a CI step: 365 days, invariants hold, prices stay within bounds (`EconomyInvariants`), and a determinism test

## M2: Ships and trading

- [x] Data: ship types (capacity, speed, price) and the starting scenario (`ships.json`, `scenario.json`)
- [x] Player trader state: coins, ships, cargo
- [x] Command layer (`Command`, `Simulation.execute`) and `SailCommand`
- [x] Commands: buy and sell (with per-unit price walk), sharing checks via `TradeCommand`
- [x] Navigation: distance-based travel time, ships in transit update hourly
- [x] Integration test: a scripted profitable voyage makes money, and dumping cargo crashes the price

## M3: First playable UI

- [x] Map scene: cities, ships moving along their routes, click to select a city (`MapView`)
- [x] City panel: market table with buy/sell prices, stock, and trade controls (`MarketPanel`; green = good deal)
- [x] Fleet list and ship details (cargo, destination, ETA), plus "Sail to" with travel times (`FleetPanel`)
- [x] HUD: coins, date; time controls (pause, 1×, 2×, 4×); last command error (`Hud`, `GameSession`)
- [x] Real Baltic map: Natural Earth coastline rendered by `tools/map/render_map.py`; cities at real coordinates; map units are km; zoom and pan
- [x] Sea lanes: ships follow the shortest waypoint route around the coasts (`data/sea_lanes.json`, `SeaChart`); a test checks every lane against the rendered coastline
- [x] UI theme pass: dark slate and gold theme built in `UiStyle.make_theme()`, label variations instead of ad-hoc overrides, scrolling side panel
- [x] **Owner play-test**, with feedback turned into roadmap items (2026-09-27: "works fine")

## M4: Player production (ADR 0004)

- [x] Shipyard: buy ships in any city, sell empty docked ships for 60% of the price
- [x] Kontor: buy a warehouse per city (one-off price, no rent), trade with it directly, and move goods between ship and kontor
- [x] Data: workshop types (inputs, output, workers, build cost, daily wages) in `data/buildings.json`
- [x] Build command, and daily workshop production from kontor inputs to outputs; unpaid wages idle the workshop
- [x] Workers drawn from the city's workforce (10% of the population, shared by all traders); effects on city production are deferred to the balance pass
- [x] UI for kontor, workshops and shipyard

## M5: Save/load and MVP polish

- [x] Save/load with `save_version`, plus a round-trip test: HUD Save/Load (quick-save slot), validated loading (`SaveGame`)
- [x] First-time hints (tutorial-lite): a banner that follows buy, sail, sell, kontor and workshop (`HintPanel`)
- [x] Windows export preset, with the build as a CI artifact (`export-windows` job, artifact `hanse-windows`)
- [x] Balance pass: off-map trade, prices 0.55×–1.8×, workforce effect on city production, `tools/balance.gd` (ADR 0005)

## Backlog (deferred review findings and small follow-ups)

Deferred P2 review findings go here, with the PR they came from.

## Later (parked, see GAME_DESIGN "Out of scope")

AI traders, trade routes, reputation, more cities, events, city growth, convoys, loans, politics.
