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
  (luxury, import only). Definitions are in `data/goods.json`.
- **Time:** 1 tick = 1 in-game hour. Markets, consumption and production resolve daily.

## Economy model (first version, refined in M1)

- Each city has a population that **consumes** goods daily and **produces** goods according to its
  specialties (for example Danzig grain, Stockholm iron and timber).
- Each city market holds a **stock** per good. A **target stock** is derived from daily consumption ×
  a number of days of cover.
- **Price** follows the stock-to-target ratio along a clamped curve around the good's base price.
  Buy and sell prices differ by a spread.
- Trading moves the price **per unit**, so large trades walk up (or down) the curve.
- The exact formulas get an ADR in M1 and must keep the economy invariants in AGENTS.md.

## Player progression (MVP)

- Start: one small ship, some coins, docked in Lübeck.
- Buy more and larger ships.
- Rent a **kontor** (warehouse) in a city to store goods between voyages.
- Build **workshops** that turn kontor inputs into outputs using city workers, for a daily upkeep.

## Out of scope for the MVP (parked, not forgotten)

AI competitor traders, automated trade routes, reputation and ranks, more cities, events (storms,
pirates, fires), city growth and construction, convoys and combat, loans and banking, politics.
Each one should only come in once the core loop is proven fun, with its own roadmap entry.

## Open questions

- Do sell prices also react to the *player's* recent sales (market memory), or only to stock?
- How visible should city needs be? A satisfaction meter, or just prices?
- Map presentation: stylized painted map or clean schematic?
