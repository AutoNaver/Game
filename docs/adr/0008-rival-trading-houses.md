# ADR 0008: Rival trading houses

- Status: accepted
- Date: 2026-09-27
- Code: `sim/systems/rival_system.gd`, `sim/defs/rival_def.gd`, `sim/defs/rival_ai_def.gd`,
  `sim/systems/house_value.gd`, `sim/commands/close_workshop_command.gd`, `ui/houses_panel.gd`;
  data in `data/rivals.json`

## Context

Until M8 the player traded alone against off-map trade (ADR 0005). Prices recovered between
voyages and every good route stayed the player's. M8 adds competitors that trade the same markets,
so the economy feels contested and the player has someone to measure themselves against.

## Decision

- **Rivals are ordinary traders.** Each house in `data/rivals.json` becomes a `TraderState` after
  the player, with its own coins and starting ships in its start city. Everything a rival does is
  a command run through `Simulation.execute` (buy, sell, sail, buy ship, buy kontor, build and
  close workshops), so rivals get the player's checks and the economy invariants apply unchanged.
- **Trading (hourly, after `RouteSystem`).** A rival ship docked in a city sells all its cargo,
  asks `TradePlanner` for the best load to each other city, and picks one of the best
  `top_choices` options at random, weighted by profit per day. Without a profitable load it sails
  empty to a random other city. This is the balance bot's greedy logic plus a little randomness,
  so rivals don't all chase the same trade.
- **Kontors and workshops (daily, after the daily systems).** A rival sells its workshops' output
  into the local market and buys `workshop_input_days` days of inputs, never above
  `input_price_limit` × base price. Every `expansion_days` days it first closes workshops that
  would lose money at today's prices (the new `CloseWorkshopCommand`, also available to the
  player), then either buys the biggest ship it can afford (up to `max_ships`, in its home city)
  or sets up the workshop with the best daily margin (up to `max_kontors`, one workshop per
  kontor), always keeping `cash_reserve` coins. A coin toss decides when both are possible.
- **Workshop margins** are estimated as the rival would really trade: one day's output sold into
  the city, one day's inputs bought from it, both walking the price, minus wages. A rival never
  opens a workshop type in a city where any house (player included) already runs one, and leaves
  at least `keep_free_workers` of the workforce free, so it can't crowd the player out of workers.
- **Randomness** comes only from the world RNG (the load pick, the empty-sailing destination and
  the coin toss), so the same seed and commands still give the same world.
- **Net worth** (`HouseValue`): coins, ships at resale value, kontors and workshops at their cost,
  and stored goods at base price. It deliberately ignores current prices so the ranking doesn't
  jump when a ship docks. The HUD's "Houses" button shows all houses ranked by it, and the log
  reports rivals' new ships and opened or closed workshops.
- **Saves (version 4)** store rivals as ordinary traders. Loading rejects traders that are neither
  the player nor a house in `data/rivals.json`. Version 1 to 3 saves get every rival added as it
  starts a new game. A house missing from a version 4 save is not revived, so a later milestone
  can remove houses (see the progression plan in GAME_DESIGN).

## Rebalance

`tools/balance.gd` now reports the rivals next to its one-ship greedy bot, and takes `--seed`
because the rivals' choices depend on it. Averages over seeds 1 to 5:

| | day 30 | day 90 | day 180 | day 360 |
|---|---|---|---|---|
| Bot alone (before M8, export rate 1.0) | 13,500 | 64,300 | 132,700 | 275,700 |
| Bot with rivals, export rate 1.0 | 10,600 | 32,500 | 44,500 | 67,700 |
| **Bot with rivals, export rate 0.6 (shipped)** | **11,900** | **35,200** | **54,900** | **91,500** |
| Rival net worth, shipped settings | 18,600 | 62,200 | 105,200 | 187,700 |

The first rival version (4 ships, expanding every 10 days, workshops without the margin and
diversity rules) cut the bot to about 39,000 in a year, and the rivals piled into the same
workshops (three breweries in Visby), then paid wages for idle workshops forever. The shipped
settings are 3 ships and 2 kontors per house, expansion every 20 days, and the off-map
`export_rate` lowered from 1.0 to 0.6, so producer cities keep more of their surplus for traders
to carry. The bot's first month (about 12,000 coins, so a kontor after one to two weeks) stays
close to the ADR 0005 target; its later income is about a third of the rival-free game, because
about ten rival ships now share the same trade.

## Consequences

- A player who only sails one ship falls behind the rivals within a season; reinvesting in ships,
  kontors and workshops is how they keep up. That is the intended pressure.
- Rivals see every market, like the player does today. When market knowledge becomes limited
  (see the progression plan in GAME_DESIGN), rivals must plan from their own knowledge under the
  same rules.
- Rivals never use trade routes, lend, or react to the player directly. Those are later ideas.
- AI running time is small: planning runs once per ship arrival (about ten a day), not every hour
  for every ship.
