# ADR 0005: Off-map trade and the first balance targets

- Status: accepted; `export_rate` and the balance figures revised by ADR 0008 (rivals)
- Date: 2026-09-27
- Code: `sim/systems/off_map_trade_system.gd`, `tools/balance.gd`; tuning in `data/economy.json`

## Context

`tools/balance.gd` runs a greedy one-ship bot on the shipped data. It sells everything on
arrival, then buys the load with the best profit per hour of sailing. Before this change it turned
the starting 5000 coins into **46,000 in 30 days** and 855,000 in a year, about 3000 per two-day
voyage. There were two causes:

1. With no other traders, a city that doesn't produce a good ran empty and sat at the maximum
   price forever, while producer cities sat at the floor. Every route was a guaranteed 7× markup.
2. The price range (0.35× to 2.5× base) made that markup extreme.

## Decision

**Off-map trade** (`OffMapTradeSystem`, daily, after consumption) stands for the overland
traders and foreign ships the game doesn't model individually:

```
imports per day = demand × import_rate × (target − stock) / target     when stock < target
exports per day = demand × export_rate × (stock − target) / target     when stock > target
```

With `import_rate` 1.5, a city that makes nothing settles near a third of its target stock
(about 1.44× base) instead of zero. Producer cities export their surplus and settle below the
cap. Flows use exact integer parts with a carry, and are booked in the goods ledger, so
conservation still holds and is checked.

**Prices** now run from 0.55× to 1.8× base.

**Workforce:** city production shrinks in proportion to the workers traders' workshops employ.
This was deferred from ADR 0004.

## Result

The same bot now reaches **about 13,500 coins after 30 days**, 64,000 after 90 and 133,000 after
180. That's roughly 750 coins per voyage, so a kontor (3000) takes one to two weeks and a first
workshop about a month. A human player earns less than the bot. Re-run `tools/balance.gd` after
any economy change and compare.

## Consequences

- Markets drift back toward their targets, so a route you've just saturated recovers, and
  scarcity is less extreme, but trade opportunities never vanish.
- AGENTS.md rule 7 lists off-map imports and exports as the only goods sources and sinks besides
  production and consumption. Player and AI trading still never create or destroy goods.
- Off-map trade is the natural hook for events later, such as war cutting off imports.
- AI traders (post-MVP) can reuse the bot's route choice as a starting point.
