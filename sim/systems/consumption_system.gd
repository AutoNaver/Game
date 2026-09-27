class_name ConsumptionSystem
extends RefCounted
## Daily consumption of each city's population from its market.


static func run_day(data: GameData, world: WorldState) -> void:
	for city in world.cities:
		for good in data.goods:
			var need := CityEconomy.daily_demand_parts(city, good) + city.consumption_carry[good.id]
			var units := CityEconomy.whole_units(need)
			city.consumption_carry[good.id] = need % CityEconomy.PARTS_PER_UNIT
			var taken := mini(units, city.stock[good.id])
			city.stock[good.id] -= taken
			# Unmet demand is recorded, not carried over: a hungry day is lost, not owed.
			city.shortage[good.id] = units - taken
