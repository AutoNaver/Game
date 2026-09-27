class_name MovementSystem
extends RefCounted
## Hourly progress of every ship at sea; ships dock when their voyage is complete.


static func run_hour(world: WorldState) -> void:
	for trader in world.traders:
		for ship in trader.ships:
			if ship.is_docked():
				continue
			ship.hours_sailed += 1
			if ship.hours_sailed >= ship.voyage_hours:
				ship.docked_at = ship.destination
				ship.origin = ""
				ship.destination = ""
				ship.voyage_hours = 0
				ship.hours_sailed = 0
