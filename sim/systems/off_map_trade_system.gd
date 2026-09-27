class_name OffMapTradeSystem
extends RefCounted
## Daily trade with the world outside the simulation: overland traders and foreign ships.
##
## A city short of a good imports some each day, more the emptier its market; a city with more
## than its target exports the surplus the same way:
##     imports per day = demand × import_rate × (target − stock) / target
##     exports per day = demand × export_rate × (stock − target) / target
## With no production and import_rate k, stock settles at (1 − 1/k) of target instead of running
## empty, so prices settle between the extremes and the player's deliveries still move them.
## Flows use exact integer parts with a carry (CityEconomy), and both are booked in the ledger.


static func run_day(data: GameData, world: WorldState) -> void:
	var economy := data.economy
	var import_steps := CityEconomy.rate_steps(economy.import_rate)
	var export_steps := CityEconomy.rate_steps(economy.export_rate)
	for city in world.cities:
		for good in data.goods:
			var demand := CityEconomy.daily_demand_parts(city, good)
			var target := CityEconomy.target_stock(economy, city, good)
			var stock: int = city.stock[good.id]
			if demand == 0 or stock == target:
				city.trade_carry[good.id] = 0
				continue
			var gap := absi(target - stock)
			var steps := import_steps if stock < target else export_steps
			@warning_ignore("integer_division")
			var parts := demand * steps / CityEconomy.RATE_STEPS * gap / target
			var flow := parts + city.trade_carry[good.id]
			var units := mini(CityEconomy.whole_units(flow), gap)
			city.trade_carry[good.id] = flow % CityEconomy.PARTS_PER_UNIT
			if stock < target:
				city.stock[good.id] += units
				world.goods_ledger[good.id] += units
			else:
				city.stock[good.id] -= units
				world.goods_ledger[good.id] -= units


## Expected units per day of off-map trade for `good` in `city` at today's stock: positive for
## imports, negative for exports. For display; run_day() moves whole units with a carry.
static func expected_flow(economy: EconomyDef, city: CityState, good: GoodDef) -> float:
	var target := CityEconomy.target_stock(economy, city, good)
	var stock: int = city.stock[good.id]
	var rate := economy.import_rate if stock < target else economy.export_rate
	return CityEconomy.daily_demand(city, good) * rate * (target - stock) / target
