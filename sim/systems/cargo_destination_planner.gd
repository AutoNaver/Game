class_name CargoDestinationPlanner
extends RefCounted
## Compares the sale value of a docked ship's entire cargo across markets. The result is a
## snapshot at today's prices; a destination market may change before the ship arrives.


## One port that pays more for the whole cargo than selling it here.
class Option:
	extends RefCounted
	## City id of the port.
	var destination: String
	## Coins for selling the whole cargo there at today's prices (each good's price walk included).
	var sale_value: int
	## Coins for selling the whole cargo where the ship is docked now.
	var local_value: int
	## Voyage time from here to the port.
	var hours: int

	func _init(p_destination: String, p_sale_value: int, p_local_value: int, p_hours: int) -> void:
		destination = p_destination
		sale_value = p_sale_value
		local_value = p_local_value
		hours = p_hours

	## Coins gained over selling here.
	func extra_value() -> int:
		return sale_value - local_value

	## extra_value() per day of sailing, the ranking key.
	func extra_per_day() -> float:
		return extra_value() * float(Simulation.HOURS_PER_DAY) / hours


## Returns ports that pay more than selling here, ranked by extra coins per day of sailing.
## Ties use city id so the order does not depend on sort_custom's stability.
static func plan(data: GameData, world: WorldState, ship: ShipState) -> Array[Option]:
	var options: Array[Option] = []
	if not ship.is_docked() or ship.cargo_total() == 0:
		return options
	var local_value := sale_value(data, world.get_city(ship.docked_at), ship)
	var ship_type := data.get_ship(ship.type_id)
	for city in data.cities:
		if city.id == ship.docked_at:
			continue
		var value := sale_value(data, world.get_city(city.id), ship)
		if value <= local_value:
			continue
		var hours := Navigation.travel_hours(data, ship_type, ship.docked_at, city.id)
		options.append(Option.new(city.id, value, local_value, hours))
	options.sort_custom(
		func(a: Option, b: Option) -> bool:
			if a.extra_per_day() != b.extra_per_day():
				return a.extra_per_day() > b.extra_per_day()
			return a.destination < b.destination
	)
	return options


## Exact proceeds if every cargo good is sold separately in this city right now.
static func sale_value(data: GameData, city: CityState, ship: ShipState) -> int:
	var total := 0
	for good in data.goods:
		var units := ship.cargo_of(good.id)
		if units > 0:
			total += CityEconomy.sell_revenue(data.economy, city, good, units)
	return total
