# ADR 0012: Market knowledge per trading house

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
- Save version 7 stores every house's book and each ship's departure news. Loading versions 1 to
  6 gives each house a one-time report of all current markets, preserving information that those
  versions exposed globally. Newly started games only know cities with initial presence.
  Save validation checks report shape, ids, days and bounds.
- The old world price history remains in saves for compatibility. Charts read the trader's
  observation history, so the global series does not leak unseen prices.

## Balance

With the prior off-map import rate of 1.5, a 365-day no-player soak at seed 1 left Stockholm at
0.74 times its home population, below the required 0.80 floor; the same seed on M10 ended at
0.93. The changed rival trading pattern exposed a need for more background supply. Raising
`data/economy.json`'s `import_rate` to 2.0 kept all cities within the 0.80 to 1.25 band in
one-year soaks for seeds 1 to 5; Stockholm ended between 0.84 and 0.95.

With that tuning, the 365-day `tools/balance.gd` probe (seeds 1 to 5) ended day 360 with 58,170
to 110,303 player coins, averaging 83,997, versus about 89,600 before M12 (ADR 0011). The bot
now explores an unknown city when it has no known profitable trade. Rival houses continued to
sail and expand; their final net worths ranged from 98,942 to 230,808. The stronger background
imports offset some lost player trading opportunities while keeping the information constraint.

## Consequences

Exploration and harbour visits now have information value. Planners may miss a profitable voyage
because no report exists or a report is old. Quotes are advice, not guaranteed execution prices:
the market can change before a ship arrives.
