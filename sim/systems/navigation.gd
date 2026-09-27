class_name Navigation
extends RefCounted
## Travel between cities. For now ships sail in straight lines between city map positions.


static func distance(data: GameData, from_city: String, to_city: String) -> float:
	return data.get_city(from_city).map_position.distance_to(data.get_city(to_city).map_position)


## Whole hours a ship of `ship_type` needs from one city to another. At least 1.
static func travel_hours(
	data: GameData, ship_type: ShipDef, from_city: String, to_city: String
) -> int:
	return maxi(1, ceili(distance(data, from_city, to_city) / ship_type.speed))


## Where the ship is on the map right now, for display.
static func position(data: GameData, ship: ShipState) -> Vector2:
	if ship.is_docked():
		return data.get_city(ship.docked_at).map_position
	var start := data.get_city(ship.origin).map_position
	var end := data.get_city(ship.destination).map_position
	return start.lerp(end, float(ship.hours_sailed) / float(ship.voyage_hours))
