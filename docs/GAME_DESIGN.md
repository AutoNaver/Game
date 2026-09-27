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
- **Wine** isn't made in the Baltic. Lübeck's trade with the west is modeled as a small, steady
  Lübeck "production" (`data/cities.json`), which makes Lübeck the cheap wine source. Off-map trade
  (ADR 0005) tops up the other cities' wine only slowly, so they stay expensive.
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
- When stock runs out, the unmet demand is recorded as a **shortage**.
- Formulas: [ADR 0003](adr/0003-market-pricing-curve.md). Tuning: `data/economy.json`,
  `data/goods.json` (`consumption_per_1000`), `data/cities.json` (`production`).

**Losses (planned, M10).** Perishable goods such as fish and beer slowly spoil while stored in
ships and kontors, and events such as fires can destroy stored goods. Both are booked in the goods
ledger like consumption ([ADR 0006](adr/0006-event-losses-and-spoilage.md)).

**Off-map trade.** Overland traders and foreign ships that the game doesn't model individually
bring goods to cities that are short and take away surpluses, in proportion to how far the stock is
from its target. A city that makes nothing settles near a third of its target stock (about 1.4× base
price), and producers settle below their cap. The gap between them is the player's opportunity.
Details and balance targets: [ADR 0005](adr/0005-off-map-trade-and-balance.md).

## City needs and growth (M9)

Every day each city measures how well its market covers the townsfolk's needs: each good's stock
against its normal (target) stock, capped at full, weighted by what people spend on it, so an
empty grain market hurts more than a lack of wine. **Satisfaction** follows that score over about
ten days. A city at 90% satisfaction keeps its home population (`data/cities.json`); above it the
city can sustain more people, below it fewer, between half and twice its home size. The
population drifts slowly towards that size, and more people mean more demand (higher target
stock, so firmer prices) and a larger workforce for workshops. People with jobs in traders'
workshops never leave.

Without the player the cities settle near their home size, Stockholm a little smaller and Visby a
little larger. A player who keeps a city supplied makes it grow by up to about 30%, and the city
panel shows population, satisfaction and the scarcest goods, with tooltips explaining why.
Details: [ADR 0010](adr/0010-city-satisfaction-and-growth.md), tuning in `data/population.json`.

## Rival trading houses (M8)

Three rival houses (Veckinchusen from Danzig, Castorp from Stockholm and Wulflam from Visby,
`data/rivals.json`) start like the player: one cog and 5000 coins. Their ships trade greedily
with a little randomness, selling everything on arrival and carrying one of the best few loads.
Every few weeks a house buys a ship or sets up a workshop in a kontor, and closes workshops that
stop paying. They use the same commands, prices and workers as the player, so they compete for
the same cheap goods and the same scarce markets. The HUD's **Houses** button ranks every house
by net worth, and the log reports the rivals' new ships and workshops. Details and balance:
[ADR 0008](adr/0008-rival-trading-houses.md).

## Player progression (today)

- Start: one small ship, some coins, docked in Lübeck.
- Buy more and larger ships.
- Buy a **kontor** (warehouse) in a city to store goods between voyages and trade from it.
- Build **workshops** next to a kontor that turn its inputs into outputs using city workers, for
  daily wages. Unpaid workers stay home. Details: [ADR 0004](adr/0004-player-production.md).
- Set up **trade routes** (M7): a loop of stops with buy, sell, load and unload orders and price
  limits, which ships then sail on their own. Details: [ADR 0007](adr/0007-trade-routes.md).
- **Close** a workshop that doesn't pay (M8): its workers leave and its wages stop.
- Measure yourself against the rival houses' net worth (M8).

## Progression plan: from skipper to trading house (M12 to M15)

Today everything is unlocked from the first day. The plan in
[ADR 0009](adr/0009-progression.md) makes growth a sequence of new capabilities:

1. **What you know (M12).** You see live prices only where you have presence: you in person, a
   docked ship or a kontor. Elsewhere you see your last known prices and their age. Ships bring
   news and harbour gossip; the planner works from what you know. Rivals follow the same rules.
2. **Who sails for you (M13).** You start as the captain of your own ship. More ships need hired
   captains (tavern pools, wages, seamanship and trading skills that improve with voyages), and
   only captained ships follow trade routes.
3. **Where you are established (M14).** Kontors also give presence and a factor with standing
   orders. Reputation per city and ranks (Skipper, Merchant, Trading house, Councillor, Alderman)
   gate kontors abroad, larger ships and later actions.
4. **Who you have beaten (M15).** Buy a struggling rival's ships or kontors, and eventually buy
   out a whole house. Rivals can do the same to each other.

Houses can go **bankrupt** when they can't pay wages for about a week: the player loses (load a
save or start over), and a bankrupt rival leaves the game with its assets sold off.

## After the MVP

The core loop is proven (owner play-tests of M3 and M5), so the parked systems now come in one at a
time, each with its own roadmap milestone: readable markets and quality of life (M6), trade routes
(M7), AI competitor traders (M8), city needs and growth (M9), events and spoilage (M10) and more
cities and goods (M11). The progression plan (M12 to M15) brings in market knowledge, captains,
reputation and ranks, and acquisitions. Still parked: loans and banking, convoys and combat,
politics.

## Open questions

- Do sell prices also react to the *player's* recent sales (market memory), or only to stock?
- How visible should city needs be? Decided in M9: satisfaction and the scarcest goods under the
  city title, with tooltips ([ADR 0010](adr/0010-city-satisfaction-and-growth.md)).
- Map presentation: stylized painted map or clean schematic?
- Market knowledge: decided in [ADR 0009](adr/0009-progression.md) (live prices only with
  presence, remembered prices elsewhere), built in M12.
