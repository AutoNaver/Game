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
- [ ] City state: population, market stock per good, derived target stock
- [ ] Data: city production specialties and per-capita consumption
- [ ] Daily systems: production, consumption, price update
- [ ] `Simulation` with seeded RNG and a `tick()` / `advance_days()` API
- [ ] `tools/soak.gd` plus a CI step: 365 days, invariants hold, prices stay within bounds

## M2: Ships and trading

- [ ] Data: ship types (capacity, speed, price)
- [ ] Player trader state: coins, ships, cargo
- [ ] Commands: buy, sell (with per-unit price walk), sail to city
- [ ] Navigation: distance-based travel time, ships in transit update hourly
- [ ] Integration test: a scripted profitable voyage makes money, and dumping cargo crashes the price

## M3: First playable UI

- [ ] Map scene: cities, ships moving along their routes
- [ ] City panel: market table with buy/sell prices, stock, and trade controls
- [ ] Fleet list and ship details (cargo, destination, ETA)
- [ ] HUD: coins, date; time controls (pause, 1×, 2×, 4×)
- [ ] **Owner play-test**, with feedback turned into roadmap items

## M4: Player production

- [ ] Kontor: rent a warehouse per city, and move goods between ship and kontor
- [ ] Data: workshop types (inputs, outputs, workers, cost, upkeep)
- [ ] Build command, daily workshop production from kontor inputs to outputs
- [ ] Workers drawn from the city population, with effects on city production
- [ ] UI for kontor and workshops

## M5: Save/load and MVP polish

- [ ] Save/load with `save_version`, plus a round-trip test
- [ ] First-time hints (tutorial-lite)
- [ ] Windows export preset, with the build as a CI artifact on `main`
- [ ] Balance pass driven by soak runs and play-tests

## Later (parked, see GAME_DESIGN "Out of scope")

AI traders, trade routes, reputation, more cities, events, city growth, convoys, loans, politics.
