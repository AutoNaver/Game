# ADR 0016: Acquisitions and bankruptcy sales

- Status: accepted
- Date: 2026-09-28
- Code: `sim/systems/acquisition_system.gd`, `sim/commands/buy_asset_command.gd`,
  `sim/commands/buy_out_house_command.gd`, `sim/commands/answer_offer_command.gd`,
  `ui/deals_panel.gd`; data in `data/acquisitions.json`

## Context

ADR 0009's fourth progression line, "who you have beaten": buying a rival's ships and kontors,
buying out a whole house, rivals doing the same, and bankrupt houses selling their assets instead
of vanishing (M13 just retired them). This ADR records what M15 built and where it differs.

## Decision

### Buying ships and kontors

- `BuyAssetCommand` buys another house's ship (with its captain and cargo; it leaves any route)
  or kontor (with its workshops and goods) at the **asking price**: its value times
  `asset_premium` (1.5). Values come from `HouseValue`: a ship at resale value plus cargo at base
  price, a kontor and its workshops at cost plus goods at base price, so net worth and prices
  agree.
- It needs the rank that unlocks **buying assets** (Councillor), and the buyer's rank limits and
  the kontor rules apply as for new ships and kontors: the fleet limit, the kontor limit, one
  kontor per city and reputation for a kontor abroad. A ship must be docked.
- **A rival accepts or refuses with a reason.** It sells when it is short of coins (below its
  `cash_reserve`), or a kontor whose workshops all lose money at today's prices (or that has
  none). Otherwise it refuses ("Castorp refuses: it has coins to spare and its kontor there
  pays"). It never sells its last ship.
- **The player sells only through offers.** Rivals can't buy the player's assets directly.

### Offers to the player

- On a rival's expansion day, a rival that may buy assets makes the player an offer with chance
  `offer_chance` (0.25): for a kontor it could take (one with workshops first), else for a docked
  ship if its fleet has room, at the asking price and within its budget. At most one standing
  offer per rival; it lapses after `offer_days` (7).
- The player answers with `AnswerOfferCommand`: accepting sells at the offered price if the deal
  can still happen (the asset is still free to go, the rival can still take it and pay). Either
  answer ends the offer.

### Buying out a house

- `BuyOutHouseCommand` needs the rank that unlocks **buy-outs** (Alderman), a net worth at least
  `buy_out_worth_factor` (2) times the target's, and its net worth times `buy_out_premium` (1.5)
  in coins.
- The buyer takes over the house's coins, ships with their captains, kontors and market
  knowledge. A kontor in a city where the buyer already has one is merged: its workshops move
  over, its goods fill the buyer's kontor and what doesn't fit is sold into that market for the
  buyer, like any sale. The house's routes and factor orders end, and its debt is written off.
  The house leaves the game.
- The player's house is never for sale. A bankrupt house isn't bought out; its assets sell one by
  one.

### Rivals

On its expansion days, before expanding, a rival buys out another rival it far outgrew, buys a
bankrupt house's ships and kontors while its AI limits allow, buys a ship from another rival
(which that rival may refuse), and may make the player an offer. All of it goes through the same
commands, and the offer draw uses the world RNG, so the game stays deterministic.

### Bankruptcy sales

- A rival that goes bankrupt no longer vanishes that day. For `bankruptcy_sale_days` (14) its
  ships and kontors are for sale at their value times `bankruptcy_discount` (0.6), to every house
  and without the rank that buying assets otherwise needs; rank limits and kontor rules still
  apply. Meanwhile it doesn't trade, pay wages or run workshops.
- When the sale ends, what is left is sold off as before: goods into the local markets, ships and
  workshops retired. ADR 0009 had ships sold to the shipyard; nobody receives coins, so retiring
  them is the same.

### Invariants and saves

- Deals move only coins and ownership. Goods never appear or vanish; a buy-out's overflow is a
  sale into the market, and the goods ledger is unchanged.
- Offers must come from solvent rivals still in the game; a bankrupt rival must have a sale end
  day. A removed house takes its offers with it.
- Save version 11 stores the offers, `next_offer_number` and a bankrupt rival's `sale_end_day`.
  Older saves have no offers and can't hold a bankrupt rival (M13 removed them at once). The
  deal news (`WorldState.deals`) isn't saved.

### UI

The houses panel shows "Bankrupt" as a house's rank during its sale and has a Deal button per
rival. The deals panel lists that house's ships and kontors with their price and the buy-out, and
the rivals' offers with Accept and Refuse. Every button asks its command, so a deal that can't be
done is disabled with the reason. The log reports deals, offers and bankruptcy sales.

## Consequences

- Councillor and Alderman now unlock something concrete, and bankrupt houses leave a short window
  of cheap ships and kontors.
- A rival can now outgrow and absorb another, so the number of houses can shrink over a long game.
- Balance: see below.

## Balance

`tools/balance.gd` over 365 days, seeds 1 to 5, is within noise of ADR 0015: the one-ship bot
ends with 107,000 to 151,000 coins, every rival reaches Trading house and one or two per seed
Councillor, and no house goes bankrupt. A three-year run of seed 1 keeps every invariant: one
rival reaches Alderman and the others Councillor, all between 700,000 and 875,000 worth.

The rivals grow in step, each held to its AI's three ships and two kontors, so none ever comes
near twice another's worth, and none goes short of coins, so rival-to-rival deals stay rare. That
is acceptable for now: acquisitions are mainly the player's tool, and a rival's offers reach the
player once it is a Councillor. If long games need more movement, the AI's fleet and kontor
limits are the lever (backlog).
