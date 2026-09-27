# ADR 0013: Market knowledge per trading house

- Status: accepted
- Date: 2026-09-27
- Code: `sim/state/market_record.gd`, `sim/systems/market_knowledge_system.gd`,
  `sim/systems/trade_planner.gd`, `sim/systems/cargo_destination_planner.gd`,
  `sim/systems/rival_system.gd`, `sim/save/save_game.gd`

## Context

Before M12 every market screen and planner read every city's current state. This made a remote
market as certain as the port where a ship was docked. ADR 0009 calls for reports that age as
ships move, and the same information limits for rival houses.

## Decision

- Each trader owns a `market_book` keyed by city. A `MarketRecord` stores its observation day,
  population, satisfaction, per-good stock, shortage, buy and sell quotes, and a 30-day observed
  mid-price history. A missing record means the market is unknown. History has gaps for days
  without presence, rather than silently drawing a current-price line through those days.
- A trader sees the current market where it has a docked ship or kontor. Until M13 gives the
  player a movable person, the player is also ashore in the scenario's starting city. Presence
  refreshes reports after commands and after each day's economy changes.
- On sailing, a ship takes a detached report of its departure market. On arrival it observes the
  destination and exchanges its departure report with other houses' ships docked there. The
  receiving house keeps its newer report; equal-day gossip cannot replace direct observation.
  A ship cannot relay a later kontor update while it is at sea.
- The market and city panels, price tooltips, cargo destination suggestions, trade planner and
  route editor use the player's book. They show the observation day and age, or an unknown marker.
  Active city events are shown only with live presence. Rivals use their own books to value remote
  destinations; local trades still execute against the real current market.
- Save version 8 stores every house's book and each ship's departure news. Loading versions 1 to
  7 gives each house a one-time report of all current markets (after older saves have grown into
  the larger world, ADR 0012), preserving information that those versions exposed globally.
  Newly started games only know cities with initial presence.
  Save validation checks report shape, ids, days and bounds. Quotes are not saved: loading
  derives them from the report's stock and population, so they can't disagree with it.
- The old world price history remains in saves for compatibility. Charts read the trader's
  observation history, so the global series does not leak unseen prices.

## Balance

With the prior off-map import rate of 1.5, a 365-day no-player soak at seed 1 left Stockholm at
0.74 times its home population, below the required 0.80 floor; the same seed on M10 ended at
0.93. The changed rival trading pattern exposed a need for more background supply. Raising
`data/economy.json`'s `import_rate` to 2.0 kept all cities within the 0.80 to 1.25 band in
one-year soaks for seeds 1 to 5 of the four-city world.

**On the larger world of M11 (ADR 0012)** two more changes were needed:

- Lübeck is no rival house's home port, so under market knowledge the houses rarely learned its
  prices and never supplied it: five-year soaks left it at 0.74x on two of four seeds. Lübeck
  gets `import_factor` 1.5 for its overland link to Hamburg and the North Sea, like Bergen and
  Novgorod (ADR 0012).
- A house that stopped visiting a city never learned it paid again, so Stockholm ended at about
  0.69x or about 1.04x depending on the seed. Rival ships now explore: with `explore_chance` (0.15,
  `data/rivals.json` ai, optional) a ship leaving port sails for the city its house knows least
  recently (unknown first, then the oldest report) with the best known load there if one pays,
  drawing on the world RNG like every rival choice.

Five-year soaks (seeds 1, 2, 3 and 7) then end every city between 0.88x and 1.13x its home
population. `tools/balance.gd` (seeds 1 to 5): the bot has about 9,400 coins after a month,
29,300 after 90 days and 99,400 after a year (M11 with full knowledge: 12,800 and 108,500). The
five houses average 197,500 net worth (M11: 234,000). Knowing less costs everyone something,
most of all in the first month, before the bot's book fills.

## Consequences

Exploration and harbour visits now have information value. Planners may miss a profitable voyage
because no report exists or a report is old. Quotes are advice, not guaranteed execution prices:
the market can change before a ship arrives.
