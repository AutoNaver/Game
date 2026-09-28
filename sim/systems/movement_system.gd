class_name MovementSystem
extends RefCounted
## Hourly progress of every ship at sea; ships dock when their voyage is complete. A storm at
## either end of the voyage (EventSystem.slowdown) lets a ship advance only every few hours.


static func run_hour(data: GameData, world: WorldState) -> Array[ShipState]:
	var arrivals: Array[ShipState] = []
	for trader in world.traders:
		for ship in trader.ships:
			if ship.is_docked():
				continue
			if world.hour % EventSystem.slowdown(data, world, ship) != 0:
				continue
			ship.hours_sailed += 1
			if ship.hours_sailed >= ship.voyage_hours:
				CaptainSystem.complete_voyage(data, trader, ship)
				ship.docked_at = ship.destination
				arrivals.append(ship)
				ship.origin = ""
				ship.destination = ""
				ship.voyage_hours = 0
				ship.hours_sailed = 0
	return arrivals
