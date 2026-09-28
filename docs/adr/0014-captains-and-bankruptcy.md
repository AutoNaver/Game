# ADR 0014: Captains and bankruptcy

## Decision

The player has a location: aboard one owned ship or ashore in a city. Changing ships and going
ashore require the ships to be docked in the same port. The player is separate from the crew;
every ship needs a hired captain to sail. Starting ships receive captains so old scenarios remain
playable, while newly purchased ships need a hire from the local tavern.

Each city offers two candidates, replaced every seven days using the world's seeded RNG. Hiring
costs 40 coins and a captain earns 8 coins per day. Captains gain one level in both skills per ten
completed voyages, to a maximum of five. Each seamanship level removes two hours from a voyage,
with a one-hour minimum. Trading skill reduces the ship's buy and sell spread in equal steps to
zero at level five. Kontor trading keeps the ordinary spread, and market reports (ADR 0013)
quote it too, so a skilled captain does a little better than the book says. Balance values live in
`data/captains.json` and are validated by the loader.

Captain and workshop wages the house cannot pay become debt. Available coins repay debt before
it grows further. Fourteen consecutive days with debt bankrupt the house. A bankrupt player sees
game over and can load or start a new game. A bankrupt rival leaves play. Its stored goods return
to the relevant city market; its ship and workshop assets are retired. M15 can replace this simple
liquidation with purchases by other houses.

Save version 9 stores captains, tavern pools, player location and debt. Older saves receive one
captain per ship. Tavern candidates are generated during migration from the saved RNG state, so
the migrated game remains deterministic from that point forward.

## Balance check

Rerun after merging M11 and M12 (the larger map and market knowledge). `tools/balance.gd` over
365 days, seeds 1 to 5: the bot ends with 98,000 to 137,000 coins (about 122,000 on average)
after 119 to 152 voyages. All five rivals stay solvent and grow to three ships and two kontors,
ending with 160,000 to 275,000 coins. Cities stay near 0.9x to 1.0x of their home population.
Captain wages add a modest cost without stopping the trading loop, so no earlier economy rate
changed.
