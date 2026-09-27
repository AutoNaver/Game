# ADR 0001: Godot 4 with statically typed GDScript

- Status: accepted
- Date: 2026-09-27

## Context

We're starting fresh after a TypeScript prototype that never got a real game UI. The game needs a
map, many data-heavy panels, and a later Windows build. Code is written by an AI agent (Claude Code)
and reviewed by another (Codex), so the stack must be testable headless and easy to review as text.

## Decision

- Godot 4.7 (standard build) with GDScript. `untyped_declaration` is configured as an error.
- GUT for tests, run headless in CI.
- gdtoolkit (`gdformat`, `gdlint`) for formatting and lint.
- Game data in JSON rather than `.tres` resources, so balance changes are readable diffs.

## Consequences

- A real engine for the map, UI and export, with no web or UI framework to assemble ourselves.
- Static typing gives the reviewer and the compiler more to check. The per-script parse step in
  `check.sh` enforces it.
- Scene files (`.tscn`) are text but awkward to review. Keep scenes small and put logic in scripts.
- No C#/.NET. If profiling ever shows GDScript is too slow for the simulation, revisit that for the
  hot systems only.
