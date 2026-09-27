# ADR 0010: City satisfaction and growth

- Status: accepted
- Date: 2026-09-27
- Code: `sim/systems/population_system.gd`, `sim/defs/population_def.gd`, `ui/side_panel.gd`,
  `tools/soak.gd` (`check_populations`); data in `data/population.json`

## Context

Until M9 every city kept the population from `data/cities.json` forever. Shortages were recorded
(ADR 0003) but had no consequence, and a player who kept a city well supplied changed nothing but
its prices. M9 makes the cities respond: well supplied cities grow, neglected ones shrink, and
population in turn drives demand (target stock, so prices) and the workforce for workshops.

Two facts about the economy shaped the design. First, literal shortages (a market running empty)
are rare: off-map imports (ADR 0005) refill a city before its stock reaches zero, so a
satisfaction built only from unmet demand would sit at 100% almost always. Second, a city that
produces nothing settles near a third of its target stock however large it is, so supply alone
gives no brake on growth for such a city.

## Decision

- **Supply score.** Once a day, after consumption, each good's supply is its stock against its
  target, capped at 1 (in millionths). A good that ran out today scores 0, so shortages count
  fully, and a thin market counts partly. The day's score averages the goods weighted by what the
  townsfolk spend on them (`consumption_per_1000 × base_price`), so running out of grain or beer
  hurts more than running out of wine. Overstock earns nothing extra.
- **Satisfaction** (`CityState.satisfaction`, millionths) moves `satisfaction_weight` (0.1) of
  the way towards the day's score, so it remembers roughly the last ten days.
- **Sustainable population.** `home × (1 + sensitivity × (satisfaction − neutral))`, clamped to
  `[min_factor, max_factor] × home`, where home is the population in `data/cities.json`. The clamp
  and the fixed home anchor are the brake that supply alone lacks: a city can't run away however
  well it is fed, and a fully supplied city settles at a definite size.
- **Growth.** The population moves `growth_rate` of the gap to the sustainable population each
  day, rounded towards zero.
- **Understaffed workshops.** A city can shrink below the workers its traders' workshops employ.
  Nobody is kept in town for that: every workshop in the city gets the same share of its workers
  (`CityEconomy.staffing` = workforce / jobs) and works that much slower. Each day it pays that
  share of its wages (rounded up) and adds the share to its `progress`; it makes one full batch
  whenever progress reaches a whole batch and keeps the remainder, so a workshop at 60% makes
  three batches in five days with whole units and an exact goods ledger. A workshop that can't
  make a due batch (no inputs, kontor full) keeps at most that one batch, so it doesn't bank
  days. City workshops get no workers while traders' jobs are unfilled.
  `free_workers` is never negative, so no new workshop can be built there. The player is told
  when their workshops in a city run short of workers and when they are fully staffed again,
  and the kontor panel shows the staffing. The former invariant "employed ≤ workforce" is
  replaced by a range check on progress. An earlier draft kept a population floor for employed
  workers instead; the owner preferred that shrinking cities slow their workshops down.
- **All integer arithmetic** (millionths and 1/1000 steps, like `CityEconomy`), so runs are exact
  and deterministic. No randomness.
- **Order.** `PopulationSystem` runs after consumption and before off-map trade, so today's
  shortages count before overland traders refill the market.
- **Saves.** Version 5 saves each city's satisfaction and each workshop's progress. Population is no longer required to match
  `data/cities.json`, only to lie within the bounds; older saves load at neutral satisfaction.
  The loader checks the stock-cap overflow at `max_factor × home`, the largest a city can be.
- **UI.** The city panel shows population with its direction, satisfaction, and the scarcest goods
  (below half their normal stock). Tooltips explain the numbers: today's supply, the population
  the city sustains, people moving in or out per day, the workforce, and every good's supply.

## Balance

Shipped values: `satisfaction_weight` 0.1, `neutral_satisfaction` 0.9, `sensitivity` 3.0,
`growth_rate` 0.005, bounds 0.5× to 2×. With the rivals trading and no player, satisfaction
settles around 85 to 95% and five-year soaks (seeds 1 to 3) end every city within 7% below to
17% above home: Stockholm, which makes only fish, timber and iron, a little smaller; Visby and
Danzig larger. A fully supplied city sustains 1.3× its home population and gets halfway there in
about 140 days.

Early in a game the markets drift from their starting stock (target) towards the off-map
equilibrium before the traders' supply chains form, so satisfaction dips to about 70% in the first
month and cities shrink by up to about 13% (Stockholm) before recovering. That's the Hanseatic
story the game tells: towns wait for merchants. A `growth_rate` of 0.01 doubled the dip, so it
was halved.

`tools/balance.gd` (averages over seeds 1 to 5) is barely changed from ADR 0008: the bot ends the
year with about 89,800 coins (was 91,500) and the rivals with about 178,000 net worth (was
187,700). It now reports each city's population and satisfaction every 30 days, and
`tools/soak.gd` fails if a city ends outside 0.8× to 1.25× its home population or at a hard bound.

## Consequences

- Delivering scarce goods has a lasting effect: the city grows, its demand and workforce rise,
  and its prices for the delivered goods stay firmer. Starving a market (buying it out) shrinks it.
- Demand is no longer constant, so target stock and prices move slowly even in a quiet market.
- Events (M10) can hit satisfaction through the same supply score without new rules: a harvest
  failure that empties the grain market lowers it.
- Open: whether satisfaction should also react to prices or to luxury goods beyond their weight,
  and whether it should affect anything but population (unrest, taxes). Not needed yet.
