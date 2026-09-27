class_name ProductionSystem
extends RefCounted
## Daily output of each city's own workshops into its market.
##
## City workshops draw on the same workforce as traders' workshops (CityEconomy.workforce), so
## output shrinks in proportion to the workers traders employ: hiring 30 of 1200 costs 2.5%.


static func run_day(data: GameData, world: WorldState) -> void:
	for city in world.cities:
		var city_def := data.get_city(city.id)
		var workforce := CityEconomy.workforce(data.economy, city)
		var available := workforce - CityEconomy.workers_employed(data, world, city.id)
		for good in data.goods:
			var rate := city_def.production_of(good.id)
			if rate <= 0.0:
				continue
			# Workshops idle rather than overfill the market, so no goods are destroyed, and an
			# idle day makes no progress (no burst of stored output when the market reopens).
			var room := CityEconomy.stock_cap(data.economy, city, good) - city.stock[good.id]
			if room <= 0:
				continue
			var daily := CityEconomy.to_parts(rate)
			# A harvest failure (EventSystem) leaves only part of the output.
			var event_steps := EventSystem.production_steps(data, world, city.id, good.id)
			@warning_ignore("integer_division")
			daily = daily * event_steps / CityEconomy.RATE_STEPS
			if workforce > 0:
				@warning_ignore("integer_division")
				daily = daily * maxi(available, 0) / workforce
			var output := daily + city.production_carry[good.id]
			var produced := room
			if output >= room * CityEconomy.PARTS_PER_UNIT:
				# Saturated: fill to the cap and drop any fraction, even when output fits exactly.
				city.production_carry[good.id] = 0
			else:
				produced = CityEconomy.whole_units(output)
				city.production_carry[good.id] = output % CityEconomy.PARTS_PER_UNIT
			city.stock[good.id] += produced
			world.goods_ledger[good.id] += produced
