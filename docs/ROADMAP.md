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

- [x] Rival trading houses (data-driven names, start cities, capital) that choose routes with the balance bot's logic and act through commands (`data/rivals.json`, `RivalSystem`, ADR 0008)
- [x] Rivals buy ships and kontors as they grow; all their choices draw on the world RNG (and close losing workshops with the new `CloseWorkshopCommand`, also in the kontor panel)
- [x] Rivals list: coins, ships, kontors, so the player can measure progress (HUD "Houses", ranked by net worth, `HouseValue`; rival news in the log; rival ships on the map)
- [x] Rebalance with rivals active (soak, `tools/balance.gd`, off-map rates), recorded in an ADR (ADR 0008: `export_rate` 1.0 → 0.6; save version 4)

## M9: City needs and growth

- [x] City satisfaction from recent shortages, shown in the city panel (supply score weighted by spending, `PopulationSystem`, ADR 0010; scarce goods and tooltips in the side panel)
- [x] Population grows or shrinks with satisfaction, changing demand and workforce (saves validate a range instead of matching data; `data/population.json`, save version 5)
- [x] Soak and balance checks that cities neither explode nor starve without the player (`tools/soak.gd` fails outside 0.8×–1.25× of home; `tools/balance.gd` reports cities; `test_city_growth.gd`)

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

## Progression (ADR 0009)

From skipper to trading house: growth unlocks capabilities instead of only adding coins. Owner
decisions (2026-09-27): these come after M11, bankruptcy is included, and ranks are hard gates.

## M12: Market knowledge

- [ ] Market book per trader: last seen prices and stocks per city with the day seen, saved
- [ ] Live prices only with presence (the player in person, a docked ship, a kontor); last known prices and their age elsewhere
- [ ] Ships update the book when they dock, plus harbour gossip from other houses' ships in port
- [ ] Market panel, trade planner, route editor and tooltips show age and use the book, not the true market
- [ ] Rivals plan from their own books; rebalance and record in an ADR

## M13: Captains

- [ ] The player as a person: aboard a ship or ashore in a city; moving between ships in port
- [ ] Ships need a captain to sail; tavern pools per city (weekly, world RNG), hiring and daily wages
- [ ] Captain skills (seamanship: voyage time, trading: spread) that improve with voyages
- [ ] Only captained ships follow routes; rivals hire from the same taverns
- [ ] Saves migrate old games (a captain for every ship); rebalance
- [ ] Bankruptcy: unpaid wages put a house in debt, a grace period, then bankruptcy; a warning in the UI; game over for the player (load or new game), a bankrupt rival leaves the game and its assets are sold off (to buyers from M15)

## M14: Reputation, ranks and factors

- [ ] Reputation per city from supplying shortages, employing workers and holding a kontor
- [ ] Ranks from net worth and reputation (`data/ranks.json`) as hard gates: commands refuse locked actions with the rank needed, and the UI shows them locked; shown in the houses panel
- [ ] Kontor factor: standing buy/sell orders at a kontor, run through the trade commands
- [ ] Rivals rise through the same ranks

## M15: Acquisitions

- [ ] Buy a rival's ship or kontor (with workshops and stock) at value times a premium; the rival accepts or refuses with a reason
- [ ] Buy out a whole house when far ahead; its assets pass to the buyer and it leaves the game
- [ ] Rivals buy from each other, and can make offers to the player
- [ ] Acquisitions move only coins and ownership; invariants and saves cover removed houses
- [ ] A bankrupt rival's ships and kontors go up for sale at a discount before being sold off

## Backlog (deferred review findings and small follow-ups)

Deferred P2 review findings go here, with the PR they came from.

From a code review of `main` at c40d4c8 (2026-09-27):

- [ ] Rivals churn workshops (#18): `_close_losing_workshops` judges today's margin, which the
  workshop's own output and input buying have moved, and closes at once on `-INF` (inputs above
  `input_price_limit`). Seed 1 over a year: 27 opened, 26 closed one expansion cycle later (24 with
  inputs still stocked), 114,500 coins of build cost lost, and open/close news every 20 days. Add
  hysteresis (several losing checks in a row), leave out the house's own market impact, or wait
  while the kontor still holds inputs
- [ ] Rivals' kontor buying keeps back only the current workshop's wages, not the house's total
  (`RivalSystem._run_kontors`, #18)
- [ ] Time can run while the save menu or route editor is open: the HUD speed buttons stay live,
  and opening one dialog over the other restores the wrong speed on close (#13, #17)
- [ ] Saves are written in place, so a crash mid-autosave corrupts the only autosave; write to a
  temp file and rename (`SaveGame.save_file`, #13)
- [ ] A named save called "autosave" (or "Autosave", the same file on Windows) is overwritten by
  the next autosave; reserve the name case-insensitively (`SaveGame.check_slot_name`, #13)
- [ ] `FleetPanel.batched_revenue` re-implements the sell price walk in the UI; move it into
  `CityEconomy` with a sim test (#20)
- [ ] #20 says the cargo manifest doesn't reveal distant markets, but `CargoDestinationPlanner`
  (#21) and `TradePlanner` value cargo at every port; settle the rule before M12
- [ ] Stale conservation wording: `WorldState.goods_ledger` and `EconomyInvariants`
  (`_check_conservation` doc and message) still say only production and consumption, missing
  off-map trade and workshops (and M10's sinks)
- [ ] ARCHITECTURE.md: the layer diagram names a `Market` state class and "daily: … prices", and
  Determinism still says "A test will enforce this from M1"
- [ ] `tests/support/test_saves.gd` matches GUT's `test_` prefix, so every run logs 9 "Ignoring…"
  warnings; rename it (for example `save_dir_guard.gd`)

## Later (parked, see GAME_DESIGN "After the MVP")

Loans and banking, convoys with pirates and combat, politics.
