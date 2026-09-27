# ADR 0006: Event losses and spoilage as goods sinks

- Status: accepted (owner decision, 2026-09-27)
- Date: 2026-09-27
- Code: none yet; implemented in M10 (events and spoilage)

## Context

AGENTS.md rule 7 lets goods leave the world only through consumption and off-map exports
(ADR 0005). The M10 plan includes fires that destroy goods stored in a kontor, which that rule
forbids. Goods that keep forever also make stockpiling risk-free: a player can hoard fish or beer
in a kontor until prices peak.

## Decision

Two more sinks are allowed, both booked in the goods ledger so conservation stays checkable:

- **Event losses:** an event may destroy goods (a fire burns kontor stock, and later, for example,
  a storm washes cargo overboard). Every loss has a named event behind it and is announced to
  the player.
- **Spoilage:** perishable goods slowly spoil while stored. Each good gets a daily spoilage rate
  in `data/goods.json` (0 for goods that keep, such as salt, iron and tools). Spoilage uses exact
  integer parts with a carry, like production and consumption, so results don't depend on how
  ticks are batched.

AGENTS.md rule 7 and the review guidelines list both sinks. Player and AI trading still never
create or destroy goods.

## Open for the M10 implementation

- Where goods spoil: ships and kontors for certain. City markets too, or does consumption stand
  in for turnover there? Spoiling market stock would also pull gluts back toward the target.
- Rates per good, tuned with the soak and `tools/balance.gd`, and how spoilage shows in the UI
  (cargo and kontor tooltips, notifications for large losses).

## Consequences

- Hoarding perishables costs something, which makes timing and route length matter more.
- Kontors become a trade-off between storage and spoilage.
- `EconomyInvariants` keeps checking conservation: the ledger just gains more booked outflows.
