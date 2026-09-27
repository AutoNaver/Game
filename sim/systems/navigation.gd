class_name Navigation
extends RefCounted
## Travel between cities along the sea lanes (SeaChart): voyages follow the shortest lane route.


## Length in km of the sea route between two cities.
static func distance(data: GameData, from_city: String, to_city: String) -> float:
	return SeaChart.length_of(data.sea_chart.route(from_city, to_city))


## Whole hours a ship of `ship_type` needs from one city to another. At least 1.
static func travel_hours(
	data: GameData, ship_type: ShipDef, from_city: String, to_city: String
) -> int:
	return maxi(1, ceili(distance(data, from_city, to_city) / ship_type.speed))


## Where the ship is on the map right now: moving at a steady pace along its route.
static func position(data: GameData, ship: ShipState) -> Vector2:
	if ship.is_docked():
		return data.get_city(ship.docked_at).map_position
	var route := data.sea_chart.route(ship.origin, ship.destination)
	return SeaChart.point_along(route, _distance_sailed(route, ship))


## The part of the voyage still ahead, from the ship's position to its destination, for display.
static func remaining_route(data: GameData, ship: ShipState) -> PackedVector2Array:
	if ship.is_docked():
		return PackedVector2Array()
	var route := data.sea_chart.route(ship.origin, ship.destination)
	return SeaChart.remainder_from(route, _distance_sailed(route, ship))


static func _distance_sailed(route: PackedVector2Array, ship: ShipState) -> float:
	return SeaChart.length_of(route) * float(ship.hours_sailed) / float(ship.voyage_hours)
