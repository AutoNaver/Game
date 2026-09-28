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

## World

- **Cities (M11):** Lübeck, Danzig, Visby and Stockholm from the MVP, plus Stralsund, Riga,
  Reval, Bergen and Novgorod, from the North Sea coast to the Russian rivers. Bergen is reached
  through the Øresund and around Skagen. Novgorod lies inland, up the Neva, across Lake Ladoga
  and up the Volkhov ([ADR 0012](adr/0012-more-of-the-baltic.md)).
- **Goods:** grain, fish, salt, timber, wool, iron, wax, honey, pitch (raw); beer, cloth, tools
  (processed); wine, furs (luxury). Definitions are in `data/goods.json`. Novgorod is the cheap
  source of furs, wax and honey; Riga shares in them; Stockholm, Riga and Danzig make pitch;
  Bergen is the great fish market.
- **Links beyond the map.** Bergen trades with England and the Low Countries, and Novgorod with
  the Russian hinterland, so their overland and off-map supply is stronger
  (`import_factor` in `data/cities.json`).
- **Wine** isn't made in the Baltic. Lübeck's trade with the west is modeled as a small, steady
  Lübeck "production" (`data/cities.json`), which makes Lübeck the cheap wine source. Off-map trade
  (ADR 0005) tops up the other cities' wine only slowly, so they stay expensive.
- **Time:** 1 tick = 1 in-game hour. Markets, consumption and production resolve daily.

## Living city view (M16)

From the Baltic map, a house can enter a port where the player is ashore, a ship is docked, or a
kontor gives a local presence. Each port has a small isometric town scene with a harbour, streets,
walls, and landmarks. It opens showing the whole town; like the sea map, the wheel zooms in on
building detail and dragging pans. The market, tavern, shipyard, kontor, and town hall carry name
plaques and lead to the controls and city information already available in the side panel.
Workshops owned by the player and rivals appear in the town, and a few citizens walk the streets.
The visible people are atmosphere, not individual economic agents; the existing population,
workforce, and production systems remain authoritative.

Workshop plots in M16 are stable visual positions derived from workshop ids and the city layout.
They do not limit construction or enter saves. M17 will add free placement and construction on the
isometric grid, migrating older workshops to saved plots. Housing and public works (M18), an elected
mayor and wall expansion (M19), and town requests and celebrations (M20) give later city growth a
direct link to trading and reputation.

### City art direction

The owner accepted M16's first visual draft on 2026-09-28 and supplied a Patrician city screenshot
as the target for a later art pass. Aim for a busy, lived-in Hanseatic port, with original artwork
and the following qualities:

- A closer isometric camera that shows building detail, with pan and zoom for navigating the town.
  Streets, waterfront, and city walls should form connected neighbourhoods.
- Tall brick merchant houses, stepped gables, half-timbered workshops, red tiled roofs, and
  distinctive civic landmarks. Vary footprints, heights, rooflines, and facades to make each
  street recognisable; keep ownership and clickable landmarks easy to identify.
- Textured cobbled streets and squares, grass at their edges, trees, gardens, and consistent
  shadows that ground buildings. Use depth sorting so people and ships pass behind scenery
  correctly, and keep important interactions readable when buildings overlap.
- A harbour integrated into the town's shoreline, with stone quays, wooden piers, moored sailing
  ships, cranes, barrels, crates, and market stalls. Cargo props should make the waterfront feel
  active without claiming to represent individual simulated goods.
- Small animated citizens moving through streets and gathering near markets and docks. Preserve
  M16's visual-only role for these people.
- A warm parchment, wood, and brass interface, with a compact contextual side panel and a Baltic
  minimap. Preserve readable text, clear controls, notifications, and useful city space at 1280x720.

A second Patrician reference from the owner (2026-09-28) shows the longer-term target from further
out, with the whole town and its surroundings in view:

- The town sits on land and wraps around a natural bay or river mouth. An irregular coastline
  replaces a square town in open water, and ships sail in from the open sea past a harbour tower.
- Countryside beyond the walls: fields, farms, forest, and roads leading out through gatehouses.
  Round towers follow the wall's course, and some houses spill outside it.
- Dense, irregular streets with small squares, many building sizes, and red roofs set among trees.
  Zoomed out, the whole town reads at a glance; zoomed in, individual buildings do.
- Important buildings are marked with rings and short callouts, which fits the landmark plaques and
  later the town-hall requests (M20).

Develop the look first in one harbour neighbourhood, review it with the owner, then extend the
shared art set across all nine cities while retaining their distinct layouts. M17's placement
previews and footprints should use the same scale and remain legible among the detailed buildings.

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

**Losses (M10).** Perishable goods slowly spoil while stored in ships and kontors (fish 2% a
day, beer 0.5%, grain 0.2%, wool 0.1%; the rest keep), and fires can destroy stored goods. City
markets don't spoil. Both are booked in the goods ledger like consumption
([ADR 0006](adr/0006-event-losses-and-spoilage.md), [ADR 0011](adr/0011-events-and-spoilage.md)).

**Events (M10).** Seeded world events hit one city at a time for a while: storms slow ships
sailing to or from it, harvest failures cut its grain output, wars cut its overland imports, and
fires burn part of the goods in its kontors. The log announces them, the city panel and price
tooltip show their effect and time left, and `data/events.json` sets how often they happen.

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
stock, so firmer prices) and a larger workforce for workshops. A city that shrinks below the jobs
in traders' workshops leaves them short of workers: they work (and pay wages) at the share of
workers they still have, and the player is told.

Without the player the cities settle near their home size, Stockholm a little smaller and Visby a
little larger. A player who keeps a city supplied makes it grow by up to about 30%, and the city
panel shows population, satisfaction and the scarcest goods, with tooltips explaining why.
Details: [ADR 0010](adr/0010-city-satisfaction-and-growth.md), tuning in `data/population.json`.

## Rival trading houses (M8)

Five rival houses (Veckinchusen from Danzig, Castorp from Stockholm, Wulflam from Visby, and since
M11 Hildebrand from Riga and Brandes from Stralsund, `data/rivals.json`) start like the player: one cog and 5000 coins. Their ships trade greedily
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

## Progression: from skipper to trading house (M12 to M15)

The whole progression of [ADR 0009](adr/0009-progression.md) is in play:

1. **What you know (M12).** You see live prices only where you have presence: you in person, a
   docked ship or a kontor. Elsewhere you see your last known prices and their age. Ships bring
   news and harbour gossip; the planner works from what you know. Rivals follow the same rules.
   Details are in
   [ADR 0013](adr/0013-market-knowledge.md).
2. **Who sails for you (M13).** You travel aboard one of your ships or stay ashore in a port.
   Every ship needs a hired captain (tavern pools, wages, seamanship and trading skills that
   improve with voyages); your starting ships come with one. Only captained ships follow trade
   routes, and wages you can't pay become debt that ends in bankruptcy (ADR 0014).
3. **Where you are established (M14).** Kontors also give presence and a factor with standing
   orders ("buy grain up to 40 at most 30 a unit"). Reputation per city grows by supplying its
   shortages, holding a kontor and running workshops there, and falls while workshops stand idle.
   A kontor abroad needs some reputation there. Ranks (Skipper, Merchant, Trading house,
   Councillor, Alderman) need net worth and standing in several cities, are never lost, and gate
   more ships and kontors, trade routes, hulks and factors. Details are in
   [ADR 0015](adr/0015-reputation-ranks-and-factors.md).
4. **Who you have beaten (M15).** From Councillor you can buy a rival's ships and kontors at
   their value plus a premium, if it agrees (it sells when short of coins or when a kontor loses
   money); from Alderman, buy out a house worth half as much as you or less. Rivals do the same
   to each other and make you offers for your assets, which you accept or refuse. Details are in
   [ADR 0016](adr/0016-acquisitions.md).

Houses can go **bankrupt** when they can't pay wages for two weeks: the player loses (load a
save or start over). A bankrupt rival's ships and kontors are for sale at a discount for two
weeks, to any house; then the rest is sold off and it leaves the game.

## After the MVP

The core loop is proven (owner play-tests of M3 and M5). Readable markets, routes, rivals, city
growth, events, and the larger Baltic (M6 to M11) are in play. The progression plan (M12 to M15)
adds market knowledge, captains, reputation, ranks, and acquisitions. The town sequence (M16 to
M20) begins with a visual city view, then adds construction, housing, public works, mayoral wall
expansion, and civic requests. Loans and banking, convoys and combat, deeper council politics, and
founding new cities remain parked.

## Open questions

- Do sell prices also react to the *player's* recent sales (market memory), or only to stock?
- How visible should city needs be? Decided in M9: satisfaction and the scarcest goods under the
  city title, with tooltips ([ADR 0010](adr/0010-city-satisfaction-and-growth.md)).
- Map presentation: stylized painted map or clean schematic?
- Market knowledge: decided in [ADR 0009](adr/0009-progression.md) and built in
  [ADR 0013](adr/0013-market-knowledge.md).
