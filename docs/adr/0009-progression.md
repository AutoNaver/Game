# ADR 0009: Progression, from skipper to trading house

- Status: proposed (needs the owner's go-ahead before M12)
- Date: 2026-09-27
- Code: none yet; planned for M12 to M15 in the roadmap

## Context

Today the player starts with every tool in the game unlocked: live prices in every city, ships
that sail anywhere without anyone aboard, kontors and workshops anywhere. Growth is only "more
coins, more of the same". GAME_DESIGN left one open question ("should prices stay visible
everywhere?") to settle before the AI leaned on it, and M8 now adds rival houses the player
wants to catch up with and eventually beat.

The owner asked for a progression where you start as your own captain with a limited view of
other markets, hire captains for more ships, build kontors and production in other cities that
also tell you about those markets, and eventually buy out competitors.

## Proposal

Progression runs along four lines that feed each other: **what you know**, **who sails for
you**, **where you are established**, and **who you have beaten**.

### 1. What you know: market knowledge (M12)

- Each trader keeps a **market book**: for every city, the prices and stocks they last saw and the
  day they saw them.
- You see a city's market **live** only where you have **presence**: you are there in person,
  one of your ships is docked there, or you own a kontor there (your factor writes every day).
- Everywhere else the market panel shows your **last known** prices with their age ("Visby, 6 days
  ago"), dimmed. A city you have never visited shows no prices.
- **Ships carry news.** A ship that docks updates your book for that city. It also picks up
  harbour gossip: the prices other houses' ships in port saw where they came from, as of the day
  they left. A busy port is a good place to learn about the whole sea, and a trade route doubles
  as an information network.
- The trade planner and route editor work from the market book, not the true market, so stale
  news can mislead you. That's the point: kontors and busy routes are worth having for what they
  tell you.
- **Rivals play by the same rules.** They plan from their own market books, which makes their
  mistakes believable and makes their kontors worth something to them too.
- Price history (M6) is recorded only while you have presence, so gaps show where you weren't.

### 2. Who sails for you: yourself and your captains (M13)

- **You are a person on the map.** At the start you are aboard your first ship as its captain.
  You can move between your ships docked in the same city, or stay ashore in a city (giving
  presence there).
- **A ship needs a captain to sail.** A ship without one stays docked unless you are aboard. You
  hire captains in a city's tavern, from a small pool that refreshes every week (drawn from the
  world RNG). Each has a daily wage and two skills:
  - *Seamanship*: shortens voyages by a few percent.
  - *Trading*: narrows the spread they pay on buying and selling by a little.
- Captains gain experience with every voyage and slowly improve, so a veteran is worth keeping.
- **Only captained ships follow trade routes.** Routes are how you scale beyond what you can sail
  yourself, and wages make every extra ship a real decision.
- Rivals hire captains from the same taverns, so a good captain in Visby may be gone next week.

### 3. Where you are established: kontors, factors and reputation (M14)

- A kontor keeps its current roles (storage, workshops, trading from it) and gains two:
  **presence** (live prices, see 1) and a **factor**, a standing order book for the kontor ("keep
  40 grain in stock, sell beer above 60"), which is the kontor's version of a trade route.
- **Reputation per city** grows when you sell goods the city is short of, employ its workers and
  keep a kontor there, and falls when your workshops stand idle for long. It gives:
  - the right to buy a kontor (a first kontor abroad needs some reputation there);
  - a small discount on building and hiring in that city.
- **Ranks** make the long game legible. Each rank needs a net worth (HouseValue, ADR 0008) and
  standing in a number of cities, and unlocks something concrete:

  | Rank | Needs (first draft) | Unlocks |
  |---|---|---|
  | Skipper | start | one ship you sail yourself, a kontor in your home city |
  | Merchant | 25,000 worth | hiring captains, trade routes, a second kontor |
  | Trading house | 100,000 worth, reputation in 2 cities | hulks, factors, up to 4 kontors |
  | Councillor | 250,000 worth, reputation in 3 cities | buying rivals' assets, loans (later) |
  | Alderman | 500,000 worth, the richest house | buying out whole rival houses |

  The numbers are data (`data/ranks.json`), tuned with `tools/balance.gd`. Rivals rise through
  the same ranks under the same rules.

### 4. Who you have beaten: acquisitions (M15)

- **Buying assets.** From Councillor on, you can offer to buy a single ship (with its captain) or
  a kontor (with its workshops and stock) from a rival. The asking price is the asset's value
  (HouseValue) times a premium from data. A rival accepts when it is short of coins (below its
  cash reserve) or the asset is losing it money, and otherwise refuses with a reason.
- **Buying out a house.** From Alderman on, if your net worth is at least twice a rival's, you
  can buy the whole house for its net worth times a larger premium. You take over its ships,
  captains, kontors, workshops and market book, and the house leaves the game. Buying out every
  rival is one way to win; the game continues afterwards.
- **Rivals can do the same.** A rival that outgrows another can buy its assets, and later make
  offers to the player, which the player may refuse.
- Every acquisition is a command (`BuyAssetCommand`, `BuyOutHouseCommand`) and an AI decision
  through the same command, and moves only coins and ownership, so no goods are created or
  destroyed. Save version 4 already allows a house to be missing from a save.

## Consequences

- The start gets simpler (one ship, one captain: you, one city you see) and the end gets bigger,
  which suits "playable first": every rank adds one new thing to learn.
- Information becomes a resource worth paying for, which gives kontors and routes a second
  purpose besides storage and automation.
- The UI needs to show age and uncertainty everywhere it shows prices (market panel, planner,
  route editor, tooltips). This is the largest cost of the proposal.
- Saves grow: market books, captains, the player's position, reputation and rank all need
  `save_version` bumps with migrations (an old save gets a market book filled from the current
  markets, and a captain for every ship).
- Balance changes a lot: less knowledge means worse trades for both the player and the rivals,
  and wages add a steady cost. Each milestone reruns `tools/balance.gd` and records the result.

## Open questions for the owner

1. Order: market knowledge changes how the rivals plan, so it could come right after M8, before
   M9 to M11. Or keep the roadmap order and do progression last?
2. Should the player be able to lose (bankruptcy) once wages and rivals can drain coins, or is
   the game always recoverable?
3. Ranks as hard gates (hulks locked until "Trading house") or as soft bonuses (discounts only)?
