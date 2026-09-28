# ADR 0015: Reputation, ranks and kontor factors

- Status: accepted
- Date: 2026-09-28
- Code: `sim/systems/reputation_system.gd`, `sim/systems/rank_system.gd`,
  `sim/systems/factor_system.gd`, `sim/commands/set_factor_orders_command.gd`; data in
  `data/ranks.json` and the optional `rank` of a ship type in `data/ships.json`

## Context

ADR 0009 planned progression along four lines. M12 and M13 built the first two (market knowledge,
captains). This is the third, "where you are established": reputation per city, ranks as hard
gates, and a factor that trades at a kontor. The rank table in ADR 0009 was a first draft; this
ADR records what was built and where it differs.

## Decision

### Reputation

- Each house has whole reputation points per city, from 0 to `max` (1000).
- **Supplying shortages:** every unit sold while the city holds less than its target stock of that
  good earns `per_shortage_unit` (1). Units beyond the target earn nothing. The rule sits in
  `SellCommand`, so ship, kontor, route and factor sales all count, for the rivals too.
- **Being established:** each day a kontor earns `per_kontor_day` (1) and each workshop that
  worked earns `per_workshop_day` (1). Each workshop that stood idle (unpaid, no inputs, or kontor
  full) costs `per_idle_workshop_day` (2). ADR 0009 said "idle for long"; a daily cost is
  simpler, needs no saved counter, and an idle day still costs less than a kontor and a working
  workshop earn.
- A city counts towards a rank at `standing` (100) points.
- The **discount** on building and hiring that ADR 0009 proposed is not built. It would need a
  second set of prices in the UI for little gain; it's on the backlog.

### Ranks

| Rank | Needs | Allows |
|---|---|---|
| Skipper | start | 1 ship, 1 kontor |
| Merchant | 25,000 worth | any number of ships, 2 kontors, trade routes |
| Trading house | 100,000 worth, standing in 2 cities | 4 kontors, hulks, factors |
| Councillor | 250,000 worth, standing in 3 cities | any number of kontors; buying assets (M15) |
| Alderman | 500,000 worth, standing in 3 cities, the richest house | buying out houses (M15) |

- A house rises daily to the highest rank it meets, and never falls back. New games and loaded
  older saves are ranked at once.
- **Hard gates.** `RankSystem` answers what a rank allows. `BuyShipCommand`, `BuyKontorCommand`,
  `SaveRouteCommand`, `AssignRouteCommand` and `SetFactorOrdersCommand` refuse with the rank
  needed ("A Hulk needs the rank Trading house"). Taking a ship off a route and dismissing a
  factor stay allowed. The UI shows each locked action with the same reason.
- **Kontors abroad.** A kontor outside the house's home city (the scenario's or its own start
  city) needs `kontor_abroad` (50) reputation there, at every rank.
- **Hiring captains isn't gated separately.** ADR 0009 had the Skipper sail their own ship and
  Merchants hire captains. ADR 0014 made every ship need a hired captain, with starting ships
  crewed. So the Skipper's one-ship limit does the same job, and a Skipper who sells a ship and
  buys another can still crew it.
- **Rivals climb the same ranks.** They are ordinary traders to the gates. `RivalSystem` asks
  `RankSystem` before planning a ship or a kontor, so it never plans a purchase it would be
  refused.
- Assets owned above a rank's limits (from older saves) are kept; the limits only refuse new
  purchases.

### Factors

- A kontor has a list of standing orders, at most one per good: **buy up to** an amount, paying
  at most a price limit per unit, or **sell down to** an amount, taking at least a price limit (0
  means any price). The kontor's route version, without a ship.
- `FactorSystem` carries them out once a day, after the rivals, through `BuyCommand` and
  `SellCommand` on the kontor. What can't be done today (no stock, no room, no coins, a price
  beyond its limit) waits for tomorrow. `CityEconomy.sellable_quantity` now serves routes and
  factors alike.
- Factors are rank-gated. The rivals don't use factors yet.

### Saves

Save version 10 stores each house's rank and its reputation (only cities with points), and each
kontor's factor orders. Older saves load with no reputation and no orders, ranked by their worth
at load; without reputation they can reach Merchant at most until they build standing.

## Consequences

- The start is narrower: one ship and one kontor (in the home city, or abroad after a couple of
  voyages supplying that city) until the house is worth 25,000.
- Reputation gives supplying shortages a lasting value besides the price, and kontors and
  workshops a reason to stay open.
- Balance: see below.

## Balance

TBD
