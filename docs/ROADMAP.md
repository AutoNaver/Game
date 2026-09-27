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
- [x] **Owner play-test** of the Windows build (2026-09-27: successful)

## M6: Readable markets and quality of life

Pillar 3: the player can always see why a price is what it is, and doesn't have to babysit ships.

- [x] Price history: daily mid price per city and good for the last 30 days, saved (`save_version` 2, migrating version 1 saves with an empty history) (`PriceHistorySystem`)
- [x] Market panel: sparkline and trend arrow per good, and a tooltip explaining the price (stock vs target, daily demand, last shortage, off-map flow)
- [x] Trade planner: for a docked ship, the best goods to carry to each other city, with margin and profit per day of sailing ("Cargo ideas", `TradePlanner`, with a Load button)
- [x] Notifications: the UI compares state around each step and logs ship arrivals and workshops going idle and why (including kontor full); pause on arrival, on by default (`LogPanel`)
- [x] Saves: several named slots, an autosave every 3 days, and a start screen with New game / Continue / Load (`SaveMenu`, `StartScreen`)

## M7: Trade routes

Automates the core loop once the player runs more ships than they want to sail by hand.

- [x] Route orders: an ordered list of stops, each with buy/sell/transfer actions, limit prices and quantities (`RouteState`, ADR 0007)
- [x] Execution only through the existing buy, sell, transfer and sail commands (no second path); failures become notifications (`RouteSystem`)
- [x] Assign or unassign a route per ship; routes and progress saved (`AssignRouteCommand`, save version 3)
- [x] Route editor UI, and route status in the fleet panel (`RouteEditor`, `RoutesPanel`)
- [x] Integration test: a looping route stays profitable for a year and never breaks an invariant (`test_trade_route_year.gd`)

## M8: AI competitor traders

- [ ] Rival trading houses (data-driven names, start cities, capital) that choose routes with the balance bot's logic and act through commands
- [ ] Rivals buy ships and kontors as they grow; all their choices draw on the world RNG
- [ ] Rivals list: coins, ships, kontors, so the player can measure progress
- [ ] Rebalance with rivals active (soak, `tools/balance.gd`, off-map rates), recorded in an ADR

## M9: City needs and growth

- [ ] City satisfaction from recent shortages, shown in the city panel
- [ ] Population grows or shrinks with satisfaction, changing demand and workforce (saves validate a range instead of matching data)
- [ ] Soak and balance checks that cities neither explode nor starve without the player

## M10: Events and spoilage

- [x] Owner decision on goods losses (2026-09-27): event losses and spoilage are allowed sinks, booked in the goods ledger (ADR 0006, AGENTS.md rule 7)
- [ ] Data-driven, seeded events with a clear duration: storms (ships delayed), harvest failures (production cut), war (off-map imports cut), fires (kontor stock lost, booked as a loss)
- [ ] Events announced through notifications, with their effect visible in the price tooltip
- [ ] Spoilage: a daily spoilage rate per good in `data/goods.json` (0 for goods that keep), applied with an exact carry to goods in ships and kontors; decide in the milestone whether city markets spoil too (ADR 0006)
- [ ] Spoilage visible where goods are stored (cargo and kontor), with a notification for large losses
- [ ] Events and spoilage saved; soak and `tools/balance.gd` runs with both enabled, rebalanced if needed

## M11: More of the Baltic

- [ ] New cities (Riga, Reval, Stralsund, Bergen, Novgorod) with sea lanes checked against the coastline
- [ ] New goods (furs, wax, honey, pitch) with producers and consumers
- [ ] Rebalance, and the map fits the larger area

## Backlog (deferred review findings and small follow-ups)

Deferred P2 review findings go here, with the PR they came from.

## Later (parked, see GAME_DESIGN "After the MVP")

Reputation and ranks (unlocking loans and banking), convoys with pirates and combat, politics.
