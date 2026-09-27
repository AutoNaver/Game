# ADR 0007: Trade routes

- Status: accepted
- Date: 2026-09-27
- Code: `sim/state/route_state.gd`, `route_stop.gd`, `route_order.gd`,
  `sim/systems/route_system.gd`, `sim/commands/*_route_command.gd`, `ui/route_editor.gd`

## Context

With a few ships the player spends most of their time sailing each one by hand, and M8's AI
traders need a way to run ships without a second path around the command layer.

## Decision

- **A route** belongs to a trader: a name and 2 to 8 **stops**, visited in order and looping back to
  the first. Consecutive stops (including last to first) must be different cities.
- **Each stop has up to 6 orders:** buy, sell, load from the trader's kontor, or unload into it,
  each for one good with a maximum quantity per visit. Buy and sell orders may carry a per-unit
  price limit: a buy never pays more than the limit for any unit and a sell never takes less, and 0
  means any price. Units are priced as `Pricing` prices them, before the total is rounded.
- **`RouteSystem` runs every hour, right after ships move.** A route ship docked at its current stop
  carries out that stop's orders in order, then sails for the next stop in the same hour. A route
  ship docked anywhere else sails for its current stop. Every action is an ordinary command
  (`BuyCommand`, `SellCommand`, `TransferCommand`, `SailCommand`) run through
  `Simulation.execute`, so routes get exactly the player's checks and invariants.
- **Orders never fail the route.** Each order takes what stock, space, coins and its price limit
  allow. An order that can do nothing when something was expected (no room, too dear, no kontor,
  kontor full) leaves a note on the ship, and the ship sails on. Having nothing to sell is normal
  and isn't noted. The UI turns new notes into notifications.
- **Commands:** `SaveRouteCommand` creates a route or replaces one's name and stops (stored as
  copies). `DeleteRouteCommand` takes its ships off the route. `AssignRouteCommand` puts a ship on
  a route from a chosen stop, or takes it off. `RouteState.check` validates routes for both the
  command and save loading.
- **Saves (version 3)** store routes, `next_route_number`, and each ship's route, stop index and
  note. Version 1 and 2 saves load without routes.

## Consequences

- One ship on a Lübeck–Danzig salt-and-grain loop with base-price limits makes about 64,000 coins
  in a year on the shipped data (integration test), less than the greedy balance bot, so routes
  save effort rather than beating attentive trading.
- Loading and unloading take no time yet. If turnaround time matters for balance later, it would
  be a route-independent docking rule.
- M8's AI traders can use the same routes and commands.
