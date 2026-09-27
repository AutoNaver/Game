class_name EconomyInvariants
extends RefCounted
## Checks the economy invariants from AGENTS.md against the current world state.
## Used by the soak run and integration tests. Returns one message per violation, empty if healthy.


static func check(data: GameData, world: WorldState) -> PackedStringArray:
	var violations: PackedStringArray = []
	var economy := data.economy
	for city in world.cities:
		for good in data.goods:
			var where := "hour %d, %s/%s" % [world.hour, city.id, good.id]
			var stock: int = city.stock[good.id]
			if stock < 0:
				violations.append("%s: negative stock %d" % [where, stock])
			if city.shortage[good.id] < 0:
				violations.append("%s: negative shortage %d" % [where, city.shortage[good.id]])
			for carry: int in [city.production_carry[good.id], city.consumption_carry[good.id]]:
				if carry < 0 or carry >= CityEconomy.PARTS_PER_UNIT:
					var limit := CityEconomy.PARTS_PER_UNIT
					violations.append("%s: carry %d outside [0, %d)" % [where, carry, limit])
			var target := CityEconomy.target_stock(economy, city, good)
			var low := good.base_price * economy.price_min_multiplier
			var high := good.base_price * economy.price_max_multiplier
			var price := Pricing.mid_price(economy, good.base_price, target, maxi(stock, 0))
			if not is_finite(price) or price < low - 0.001 or price > high + 0.001:
				violations.append("%s: price %f outside [%f, %f]" % [where, price, low, high])
	violations.append_array(_check_conservation(data, world))
	return violations


## Goods may only appear through production and disappear through consumption: the units that
## actually exist must equal the ledger kept by those systems.
static func _check_conservation(data: GameData, world: WorldState) -> PackedStringArray:
	var violations: PackedStringArray = []
	for good in data.goods:
		var total := 0
		for city in world.cities:
			total += city.stock[good.id]
		var expected: int = world.goods_ledger[good.id]
		if total != expected:
			var message := "hour %d, %s: %d units exist but production and consumption account for %d"
			violations.append(message % [world.hour, good.id, total, expected])
	return violations
