# AGENTS.md

The single source of truth for every agent working in this repo: Claude Code implements, Codex reviews,
and humans play-test. `CLAUDE.md` imports this file. If the rules here and in another doc disagree,
this file wins; fix the other doc.

## 1. Project

**Hanse (working title)** is a Hanseatic trading and economy game in the spirit of *Patrician*.
You start with one ship and a little money in the Baltic around 1400, buy low, sell high, build
production, and grow into a trading house. Prices come out of a living simulation of city supply and
demand, not out of scripts.

- Design: [docs/GAME_DESIGN.md](docs/GAME_DESIGN.md)
- Roadmap and current milestone: [docs/ROADMAP.md](docs/ROADMAP.md)
- Architecture: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
- Decisions: [docs/adr/](docs/adr/)

Guiding principle: **playable first, systems second.** Don't add a system until the loop it serves
is fun, and every milestone ends in something a human can play.

## 2. Repo map

| Path | What lives there |
|---|---|
| `sim/` | The pure simulation: `RefCounted` classes, no Nodes. `defs/` static definitions and loader, `state/` mutable world state, `systems/` daily/hourly rules, `commands/` player and AI actions. |
| `ui/` | Godot scenes and scripts. Read sim state and issue commands, nothing else. |
| `data/` | JSON definitions (goods, cities, and later buildings and ships). Balance lives here. |
| `tests/` | GUT tests. `unit/` for single classes, `integration/` for multi-day runs. `fixtures/` for test data. |
| `tools/` | Headless dev tools (`soak.gd`). Same rules as `sim/`: typed, deterministic. |
| `scripts/check.sh` | Every check CI runs, in one command. |
| `addons/gut/` | Vendored test framework (GUT 9.7.1). Never edit it. |
| `docs/` | Design, roadmap, architecture, ADRs. |

## 3. Commands

Toolchain: **Godot 4.7.2** (standard build, not .NET), **gdtoolkit 4.5.0** (`pip install "gdtoolkit==4.5.0"`).

```bash
scripts/check.sh                                     # everything CI runs; must pass before pushing
godot --headless -s addons/gut/gut_cmdln.gd          # tests only (config: .gutconfig.json)
godot --headless -s res://tools/soak.gd -- --days 365 --seed 1   # economy soak + market summary
gdformat sim ui tests                                # format (tabs, 100 cols)
gdlint sim ui tests                                  # lint
godot                                                # run the game (main scene: ui/main.tscn)
```

If `godot` isn't on PATH, set `GODOT` to the binary. On Windows use the `*_console.exe`, which has
stdout. The first run after a fresh clone needs `godot --headless --import`; `check.sh` does that.

## 4. Architecture rules

1. **`sim/` is pure.** No `Node`, `get_tree()`, signals to the UI, `Input`, `Time`, or file access
   outside the data loader and save code. It must run headless and under test.
2. **The UI reads state and sends commands.** Every player action goes through a command that the
   simulation validates and applies. AI traders issue the same commands, so there is no second path.
3. **Deterministic.** All randomness comes from the single seeded `RandomNumberGenerator` in the world
   state. Never call the global `randf()`, `randi()` or `randomize()` in `sim/`. Iterate in stable order,
   using the ordered arrays in `GameData`, never over dictionary keys whose order depends on insertion
   history. Same seed plus same commands gives the same world.
4. **Tick model.** 1 tick = 1 in-game hour. Ships move every tick. Consumption, production and prices
   update once per day (every 24 ticks). Game speed changes ticks per real second, never the rules.
5. **Data-driven.** Numbers that are balance go into `data/*.json`, validated by the loader with
   precise error messages. Numbers that are engine rules go into named constants. No magic numbers.
6. **Save format.** State serializes through `to_dict()`/`from_dict()` to JSON with `save_version`.
   Any change to the saved shape bumps the version and ships a migration or an explicit decision
   to break old saves.
7. **Economy invariants.** Stock and money never go negative. Prices are always finite and clamped.
   Goods are only created by production and only destroyed by consumption, never by trading.

## 5. Coding conventions

- **Typed GDScript everywhere.** The project treats `untyped_declaration` as an error, so typed
  variables, parameters, returns and loop variables are required. Use `:=` only where the type is
  obvious from the right-hand side.
- `class_name` for every `sim/` class, one class per file, file name = snake_case of the class name.
- snake_case for functions and variables, PascalCase for classes, UPPER_SNAKE for constants.
  Prefix private members with `_`.
- Doc comments (`##`) on every public class and on non-obvious public functions. Comments explain
  *why*, not *what*.
- Prefer returning an error list or null over asserting on bad input from data or saves. Use
  `assert` only for programmer errors.
- `gdformat` owns formatting. Don't hand-format against it.

## 6. Workflow for the implementing agent

1. Pick the next unchecked item in [docs/ROADMAP.md](docs/ROADMAP.md). One item, or a tight group, per PR.
2. Branch from an up-to-date `main`: `feat/<area>-<topic>`, `fix/<area>-<topic>`, `docs/<topic>`, or
   `chore/<topic>`.
3. Keep PRs reviewable: about 400 changed lines or fewer, not counting data, fixtures and vendored code.
   Split bigger work.
4. Write or update tests with the change. Any `sim/` behavior change needs a test that would fail
   without it.
5. Run `scripts/check.sh`. It must pass before you push.
6. Tick the roadmap checkbox in the same PR, and update docs or ADRs if a design decision changed.
7. Open the PR with the template. Commit messages are imperative, for example "Add pricing curve for
   city markets".
8. Go through the Codex review loop and merge (see CLAUDE.md for the exact commands).

## 7. Merge policy

`main` is protected and every change lands through a PR:

- The required status check `ci` must pass, and the branch must be up to date with `main`.
- All review conversations must be resolved. Zero approvals are required.
- The rules apply to admins too. No force pushes, no branch deletion, no direct pushes.

**An agent may merge its own PR (squash)** once all of these hold:

- `ci` is green.
- The branch is up to date.
- Codex has reviewed the current head commit.
- Every review thread is resolved: fixed, or answered with a concrete reason.

A P0/P1 finding that the agent disagrees with is **not** self-resolved. It's escalated to the human
owner. Never bypass protection (`--admin`, force push, disabling rules).

## 8. Definition of done

- `scripts/check.sh` is green locally and `ci` is green on the PR.
- Codex review threads are resolved per the merge policy.
- The roadmap is updated and docs match the code.
- The game still launches to its main scene without errors.

## Review guidelines

These instructions are for Codex (and any other reviewer) reviewing PRs in this repo.

Focus on correctness and the rules in this file. Flag these as **P0/P1**:

- `sim/` code that depends on `Node`, the scene tree, UI scripts, `Input`, `Time`/OS clocks, or does
  file I/O outside the data loader and save code.
- Nondeterminism: the global RNG (`randf`, `randi`, `randomize`), iteration over dictionaries where
  order affects results, float accumulation that makes outcomes depend on tick batching.
- Broken economy invariants: stock or money can go negative, prices can become NaN, infinite or
  unclamped, and goods or money are created or destroyed outside production, consumption and explicit
  income or costs.
- Validation holes: data or save input that can crash the game or silently produce wrong state
  instead of a clear error.
- A save-format change without a `save_version` bump and a migration or explicit decision.
- A `sim/` behavior change without a test that exercises it, or tests that pass without really
  asserting the behavior (asserting on mocks, missing asserts, over-broad tolerances).
- Player actions that bypass the command layer, or UI code that mutates sim state directly.
- Untyped GDScript declarations in new code (CI should catch these, so flag any that slip through).

Also worth a comment (P2): unclear naming, missing doc comments on public `sim/` APIs, magic numbers
that should be data or constants, and duplication with an existing helper.

Don't comment on formatting (gdformat enforces it), on files under `addons/`, or on work that is out
of scope for the PR's roadmap item. Suggest follow-ups instead of asking for scope growth.
