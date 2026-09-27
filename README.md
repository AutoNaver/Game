# Hanse (working title)

A Hanseatic trading and economy game inspired by *Patrician*, built with Godot 4.

Status: **M7**: the MVP (trade, ships, kontors, workshops, save/load) plus readable markets, cargo
ideas, notifications, save slots and trade routes. See [docs/ROADMAP.md](docs/ROADMAP.md).

The fleet panel summarizes ship locations and capacity. Select a ship to see its cargo and, while
docked, what selling that cargo in the current port would pay at today's prices.

## Requirements

- [Godot 4.7.2](https://godotengine.org/download) (standard build). On Windows: `winget install GodotEngine.GodotEngine`
- Python 3 with gdtoolkit: `pip install "gdtoolkit==4.5.0"`

## Run

Open the folder in Godot and press F5, or run `godot` from the repo root.

## Download a build

Every CI run on a PR or on `main` exports a Windows build. Open the run under the repository's
Actions tab and download the `hanse-windows` artifact; it holds a single `Hanse.exe`.

Saves go to `%APPDATA%\Godot\app_userdata\Hanse (working title)\saves\`.

## Check

```bash
scripts/check.sh
```

This runs formatting, lint, a headless import, a typed parse check of every script, and the GUT
tests, exactly as CI does. Set `GODOT=/path/to/godot` if Godot is not on your PATH.

## How this repo is developed

Claude Code implements features and Codex reviews every pull request. The rules both follow are in
[AGENTS.md](AGENTS.md). Start there, then read [docs/GAME_DESIGN.md](docs/GAME_DESIGN.md) and
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).
