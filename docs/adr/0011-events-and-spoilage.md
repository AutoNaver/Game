# ADR 0011: World events and spoilage

- Status: accepted
- Date: 2026-09-27
- Code: `sim/systems/event_system.gd`, `sim/systems/spoilage_system.gd`, `sim/defs/event_def.gd`,
  `sim/state/event_state.gd`, `sim/state/goods_loss.gd`, `ui/event_text.gd`; data in
  `data/events.json` and `spoilage_per_day` in `data/goods.json`

## Context

ADR 0006 allowed two new goods sinks, event losses and spoilage, and left open where goods spoil
and how both show in the UI. M10 builds them, plus events that disturb the economy without
destroying goods: storms that delay ships, harvest failures that cut production and wars that cut
off-map imports.

## Decision

### Events

- **Data-driven kinds.** `data/events.json` lists event types. Each has a kind (storm,
  harvest_failure, war, fire), a daily chance and a duration range, plus its kind's own fields:
  `slowdown` for storms, `goods` and `factor` for harvest failures, `factor` for wars and
  `loss_share` for fires. The loader rejects unknown kinds, missing or unknown fields, and
  out-of-range values.
- **Seeded and ordered.** `EventSystem` runs first each day. It drops events that are over, then
  every event type in data order draws once from the world RNG whether it starts today (always
  one draw per type, so eligibility can't shift later draws). A starting event picks one eligible
  city and a duration from the same RNG. A city can't have two events of the same type at once. A
  harvest failure needs a city that produces one of its goods, and a fire needs a kontor with
  goods.
- **One city each.** Every event hits one city for a span of days (`EventState`, saved):
  - A **storm** makes ships sailing to or from that city advance their voyage only every
    `slowdown`-th hour (whole hours, so voyages stay exact and batching-independent).
  - A **harvest failure** multiplies the city's own production of its goods by `factor`.
  - A **war** multiplies the city's off-map imports (ADR 0005) by `factor`. Exports continue.
  - A **fire** burns `loss_share` of every good in every trader's kontor there on its first day,
    rounded down per good, booked in the goods ledger as a loss.
- **Shipped rates.** Storms 3% a day for 2 to 4 days at half speed, harvest failures (grain) 0.4%
  for 20 to 40 days at 30%, wars 0.2% for 30 to 60 days at 20% of imports, fires 0.3% burning a
  quarter of the stock. That's about a dozen events a year, mostly storms.
- Planning (`TradePlanner`, travel times, rivals) doesn't foresee events. They react through prices
  like everyone else.

### Spoilage

- **Where.** Goods spoil in ships and kontors only. **City markets don't spoil**: their stock turns
  over daily through consumption and off-map trade, and exports already drain gluts, so spoiling
  them would only double-count turnover and shift every balance number.
- **How.** Each good may have `spoilage_per_day` in `data/goods.json` (optional, 0 when missing).
  Every day a hold loses `units × rate`, counted in millionths with a carry per hold and good
  (`Hold.spoil_carry`, saved), so 10 fish at 2% a day lose exactly one fish every five days. When
  a hold has none of a good left, its carry is dropped, so a fraction doesn't follow new goods.
- **Shipped rates.** Fish 2%, beer 0.5%, grain 0.2%, wool 0.1% a day. Salt, timber, iron, cloth,
  tools and wine keep.

### Losses and the UI

- Both sinks book every unit in the goods ledger, so `EconomyInvariants` still checks
  conservation. Each day's losses are also listed in `WorldState.losses` for the UI. The list is
  cleared at the start of each day and not saved.
- The log announces every event as it starts ("War in Stockholm: overland imports down to 20% for
  42 days") and when it's over, every fire loss in the player's kontors, and spoilage of at least 5
  units in one of the player's ships or kontors in a day.
- The city panel lists running events with their time left. The price tooltip names events that
  move that good's price, and how fast the good spoils. The kontor's goods and the cargo manifest
  show spoilage per day. A ship slowed by a storm says so in the fleet list.
- **Saves.** Version 6 adds `events`, `next_event_number` and ships' and kontors' `spoil_carry`.
  Older saves load with no events and no carries.

## Balance

`tools/balance.gd` (averages over seeds 1 to 5) is within noise of M9: the bot ends the year with
about 89,600 coins (was 89,800) and the rivals with about 179,000 net worth (was 178,000). There
were 7 to 16 events a year. Five-year soaks (seeds 1 to 3) start 60 to 69 events. They lose
about 4,100 units to spoilage and 10 to 68 to fires, and every city still ends 0.91× to 1.15×
home. No rebalance was needed. Spoilage shaves a few percent off fish and beer runs and makes
storing fish in a kontor costly, which is its purpose.

## Consequences

- Timing matters more: perishables want short routes, and a harvest failure or war is a trading
  opportunity for whoever reacts first.
- Storms can make a ship miss a route's timing. Routes still work because they wait at stops by
  design (ADR 0007).
- More event kinds (plague, piracy, a lost cargo at sea) fit the same shape: a kind, its fields in
  the loader, and a query the affected system calls.
