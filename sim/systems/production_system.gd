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
			# Workshops idle rather than overfill the market, so no goods are destroyed, and an
			# idle day makes no progress (no burst of stored output when the market reopens).
			var room := CityEconomy.stock_cap(data.economy, city, good) - city.stock[good.id]
			if room <= 0:
				continue
			var output := CityEconomy.to_parts(rate) + city.production_carry[good.id]
			var produced := room
			if output >= room * CityEconomy.PARTS_PER_UNIT:
				# Saturated: fill to the cap and drop any fraction, even when output fits exactly.
				city.production_carry[good.id] = 0
			else:
				produced = CityEconomy.whole_units(output)
				city.production_carry[good.id] = output % CityEconomy.PARTS_PER_UNIT
			city.stock[good.id] += produced
			world.goods_ledger[good.id] += produced
