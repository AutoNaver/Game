# Game Design

Status: living document. Change it in the same PR as the code that changes the design.

## Pitch

The Baltic around 1400. You inherit one small cog and a purse of coins in Lübeck. Every city makes
some goods cheaply and runs short of others. Watch the markets, haul grain to where people are
hungry and cloth to where it's scarce, and turn profits into more ships, warehouses and workshops,
until your trading house shapes the prices of the whole sea.

## Pillars

1. **A living economy.** Prices come from stock, production and consumption. When the player dumps
   200 barrels of beer, the price visibly crashes. When a city runs out of grain, it hurts.
2. **Trade is the core verb.** Buying, hauling and selling must feel good before anything else is
   added.
3. **Readable.** The player can always see *why* a price is high (low stock, high demand) and plan
   around it.
4. **Growth.** From one ship to a trading house. Each reinvestment (ship, kontor, workshop) visibly
   expands what the player can do.

## Core loop

1. Check the markets. Where is a good cheap, and where is it dear?
2. Buy, watching the price climb as you take stock.
3. Sail. Travel takes in-game days, and the world keeps moving while you're at sea.
4. Sell, watching the price fall as you flood the market.
5. Reinvest in more cargo space, a kontor to store goods, and workshops to produce your own.

## World (MVP)

- **Cities:** Lübeck, Danzig, Visby, Stockholm.
- **Goods:** grain, fish, salt, timber, wool, iron (raw); beer, cloth, tools (processed); wine
  (luxury, imported). Definitions are in `data/goods.json`.
- **Wine** isn't made in the Baltic. It arrives through Lübeck's trade with the west, and for now
  that import is modeled as Lübeck "production" (`data/cities.json`), a small, steady trickle that
  makes Lübeck the only wine source. It becomes a real off-map import when off-map trade exists.
- **Time:** 1 tick = 1 in-game hour. Markets, consumption and production resolve daily.

## Economy model (first version, refined in M1)

- Each city has a population that **consumes** goods daily and **produces** goods according to its
  specialties (for example Danzig grain, Stockholm iron and timber).
- Each city market holds a **stock** per good. A **target stock** is derived from daily consumption ×
  a number of days of cover.
- **Price** follows the stock-to-target ratio along a clamped curve around the good's base price.
  Buy and sell prices differ by a spread.
- Trading moves the price **per unit**, so large trades walk up (or down) the curve.
- City workshops **idle** once stock reaches a cap (target × `stock_cap_factor`), so gluts are
  bounded without destroying goods.
- When stock runs out, the unmet demand is recorded as a **shortage**. It will feed city mood and
  growth later.
- Formulas: [ADR 0003](adr/0003-market-pricing-curve.md). Tuning: `data/economy.json`,
  `data/goods.json` (`consumption_per_1000`), `data/cities.json` (`production`).

**Known and intended (for now):** there are no other traders yet, so cities that don't produce a
good drain to empty (maximum price) within about `days_of_cover` days, and producer cities fill up
to their cap. That gap is the player's opportunity. Background trade arrives with the AI traders
after the MVP.

## Player progression (MVP)

- Start: one small ship, some coins, docked in Lübeck.
- Buy more and larger ships.
- Buy a **kontor** (warehouse) in a city to store goods between voyages and trade from it.
- Build **workshops** next to a kontor that turn its inputs into outputs using city workers, for
  daily wages. Unpaid workers stay home. Details: [ADR 0004](adr/0004-player-production.md).

## Out of scope for the MVP (parked, not forgotten)

AI competitor traders, automated trade routes, reputation and ranks, more cities, events (storms,
pirates, fires), city growth and construction, convoys and combat, loans and banking, politics.
Each one should only come in once the core loop is proven fun, with its own roadmap entry.

## Open questions

- Do sell prices also react to the *player's* recent sales (market memory), or only to stock?
- How visible should city needs be? A satisfaction meter, or just prices?
- Map presentation: stylized painted map or clean schematic?
