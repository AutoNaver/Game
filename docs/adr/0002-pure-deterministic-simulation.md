# ADR 0002: Pure, deterministic simulation behind a command layer

- Status: accepted
- Date: 2026-09-27

## Context

An economy game lives or dies on balance, which needs fast, repeatable, headless runs. AI traders
(later) must play by the same rules as the player, and saves must restore the exact same world.

## Decision

- All game rules live in `sim/` as `RefCounted` classes with no scene-tree dependency.
- The only way to change state from outside is through commands (validate, then apply), used by
  both the UI and the AI.
- A single seeded RNG is stored in the world state, and iteration order is always stable.
- Fixed tick: 1 hour. Daily systems run every 24 ticks in a fixed order.

## Consequences

- Balance can be tested with soak runs in CI, and bugs reproduce from a seed plus a command log.
- The UI needs a thin adapter to observe state changes. That's a small cost next to testability.
- Reviewers get clear rules to check (see AGENTS.md "Review guidelines").
