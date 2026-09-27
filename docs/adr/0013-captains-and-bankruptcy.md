# ADR 0013: Captains and bankruptcy

## Decision

The player has a location: aboard one owned ship or ashore in a city. Changing ships and going
ashore require the ships to be docked in the same port. The player is separate from the crew;
every ship needs a hired captain to sail. Starting ships receive captains so old scenarios remain
playable, while newly purchased ships need a hire from the local tavern.

Each city offers two candidates, replaced every seven days using the world's seeded RNG. Hiring
costs 40 coins and a captain earns 8 coins per day. Captains gain one level in both skills per ten
completed voyages, to a maximum of five. Each seamanship level removes two hours from a voyage,
with a one-hour minimum. Trading skill reduces the ship's buy and sell spread in equal steps to
zero at level five. Kontor trading keeps the ordinary spread. These balance values live in
`data/captains.json` and are validated by the loader.

Captain and workshop wages the house cannot pay become debt. Available coins repay debt before
it grows further. Fourteen consecutive days with debt bankrupt the house. A bankrupt player sees
game over and can load or start a new game. A bankrupt rival leaves play. Its stored goods return
to the relevant city market; its ship and workshop assets are retired. M15 can replace this simple
liquidation with purchases by other houses.

Save version 7 stores captains, tavern pools, player location and debt. Older saves receive one
captain per ship. Tavern candidates are generated during migration from the saved RNG state, so
the migrated game remains deterministic from that point forward.

## Balance check

With seed 1 over 365 days, `tools/balance.gd` finished at 112,467 player coins after 124 voyages.
All three rivals remained solvent and expanded to three ships and two kontors. The captain wage
adds a modest cost without stopping the trading loop; no change to earlier economy rates was
needed.
