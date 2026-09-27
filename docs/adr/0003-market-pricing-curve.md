# ADR 0003: Market pricing curve, spread and per-unit price walk

- Status: accepted
- Date: 2026-09-27
- Code: `sim/systems/pricing.gd`, tuning in `data/economy.json`

## Context

Prices are the main thing the player reads and acts on. They have to:
- react to stock (scarcity is expensive, a glut is cheap),
- react to the player's own trades (dumping 200 barrels must hurt),
- stay bounded and finite whatever the stock,
- never let a trader make money by buying and selling in the same market.

## Decision

**Target stock.** Each city and good has `target = ceil(daily consumption × days_of_cover)`,
at least 1. This is the "normal" amount a city wants to hold.

**Mid price by unit position.** The unit that raises stock from `p` to `p + 1` sits at position `p`.
Its mid price is

```
mid(p) = base_price × max(min_mult, max_mult ^ (1 − p / target))
```

| Stock vs. target | Multiplier |
|---|---|
| empty (p = 0) | `max_mult` (2.5) |
| at target | 1.0 |
| 2 × target | 1 / max_mult (0.4) |
| beyond ~2.15 × target | `min_mult` (0.35), the floor |

The curve is exponential, so it's smooth, monotone, bounded above without a clamp, and tops out at
a finite value when the market is empty.

**Spread.** Buying costs `mid × (1 + spread/2)`; selling earns `mid × (1 − spread/2)`.

**Per-unit walk.** Buying `n` units sums the prices at positions `stock−1 … stock−n`. Selling sums
positions `stock … stock+n−1`. Buying and immediately selling back the same units covers the same
positions, so the round trip loses exactly the spread.

**Rounding.** Totals are computed in floats. Buy costs round up and sell revenues round down, so
rounding never creates money for a trader.

Starting values (`data/economy.json`): `days_of_cover` 20, `price_max_multiplier` 2.5,
`price_min_multiplier` 0.35, `spread` 0.1. `stock_cap_factor` (3.0) is used by city production and
is explained in the economy systems.

## Consequences

- One formula covers display prices (quantity 1) and trade totals (quantity n).
- Trades cost O(n) in the quantity. That's fine for cargo sizes in the hundreds; switch to a closed
  form if profiling ever says otherwise.
- There's no market memory. Prices depend only on current stock, so a city recovers only through
  its own production and consumption. Revisit if play-tests show arbitrage is too easy.
