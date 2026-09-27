# ADR 0004: Player production (shipyard, kontors, workshops)

- Status: accepted
- Date: 2026-09-27
- Code: `sim/commands/*`, `sim/systems/workshop_system.gd`, `sim/state/{hold,kontor_state,workshop_state}.gd`;
  data in `data/buildings.json` and `data/economy.json`

## Context

After M3 the only way to grow was a bigger pile of coins. M4 adds the second half of the Patrician
loop: more ships, storage in cities, and your own production.

## Decision

**Shipyard.** Every city sells every ship type at its `price` (`data/ships.json`). A new ship is
named "<Type> <n>" and starts docked there, empty. Ships sell back for `ship_resale_factor` of their
price (0.6) when docked and empty. That's a money sink, and there's no ship trading for profit.

**Kontor.** One per city per trader, bought once (`kontor.price`, no rent) and holding
`kontor.capacity` units of all goods together. Markets trade with a kontor directly
(`BuyCommand.for_kontor`, `SellCommand.for_kontor`), and `TransferCommand` moves goods between a
docked ship and the kontor. Ships and kontors share `Hold`, the goods container.

**Workshops.** They're built next to your own kontor (`build_cost`) and employ `workers` from the
city's workforce: `workforce_share` of the population, 10%, shared by all traders. Each day,
in `WorkshopSystem`, after city production and before consumption:

1. **Wages first.** If the owner can't pay `wages_per_day`, the workshop idles (`UNPAID`), so
   coins never go negative. Otherwise the wages are paid, even if the workshop then can't work,
   because the workers turned up.
2. If the kontor lacks any input (`NO_INPUTS`), or the output wouldn't fit after the inputs are
   used (`KONTOR_FULL`), the workshop idles.
3. Otherwise it consumes the inputs and adds the output, both in whole units. Both flows are
   booked in the goods ledger, so conservation checks still hold.

Workshops work in whole units per day with no fractions. City production is not reduced by the
workers workshops employ yet; that's a later balance question.

## Consequences

- Workshops turn cheap inputs into goods that sell elsewhere. The brewery (16 grain → 20 beer for
  150 a day) pays only if grain is bought cheaply, such as in Danzig, and the beer is sold where
  it's scarce.
- The daily order is city production, then workshops, then consumption. That's deterministic,
  because traders, kontors (in city order) and workshops (in build order) are iterated in fixed
  order.
- Saves (M5) will need kontors and workshops in the save format.
