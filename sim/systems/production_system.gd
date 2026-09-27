class_name ProductionSystem
extends RefCounted
## Daily output of each city's own workshops into its market.


static func run_day(data: GameData, world: WorldState) -> void:
	for city in world.cities:
		var city_def := data.get_city(city.id)
		for good in data.goods:
			var rate := city_def.production_of(good.id)
			if rate <= 0.0:
				continue
			var output := rate + city.production_carry[good.id]
			var units := floori(output)
			city.production_carry[good.id] = output - units
			# Workshops idle rather than overfill the market, so no goods are destroyed.
			var room := maxi(
				0, CityEconomy.stock_cap(data.economy, city, good) - city.stock[good.id]
			)
			city.stock[good.id] += mini(units, room)
