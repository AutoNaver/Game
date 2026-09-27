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
				if carry < 0 or carry >= CityEconomy.MILLIS_PER_UNIT:
					var limit := CityEconomy.MILLIS_PER_UNIT
					violations.append("%s: carry %d outside [0, %d)" % [where, carry, limit])
			var target := CityEconomy.target_stock(economy, city, good)
			var low := good.base_price * economy.price_min_multiplier
			var high := good.base_price * economy.price_max_multiplier
			var price := Pricing.mid_price(economy, good.base_price, target, maxi(stock, 0))
			if not is_finite(price) or price < low - 0.001 or price > high + 0.001:
				violations.append("%s: price %f outside [%f, %f]" % [where, price, low, high])
	for trader in world.traders:
		if trader.coins < 0:
			violations.append(
				"hour %d, %s: negative coins %d" % [world.hour, trader.id, trader.coins]
			)
		for ship in trader.ships:
			violations.append_array(_check_ship(data, world.hour, ship))
	return violations


static func _check_ship(data: GameData, hour: int, ship: ShipState) -> PackedStringArray:
	var violations: PackedStringArray = []
	var where := "hour %d, %s" % [hour, ship.id]
	for good_id: String in ship.cargo.keys():
		if not data.has_good(good_id) or ship.cargo[good_id] <= 0:
			violations.append("%s: bad cargo entry %s=%d" % [where, good_id, ship.cargo[good_id]])
	var capacity := data.get_ship(ship.type_id).capacity
	if ship.cargo_total() > capacity:
		violations.append("%s: cargo %d over capacity %d" % [where, ship.cargo_total(), capacity])
	if ship.is_docked():
		if not data.has_city(ship.docked_at):
			violations.append("%s: docked at unknown city '%s'" % [where, ship.docked_at])
	elif (
		not data.has_city(ship.origin)
		or not data.has_city(ship.destination)
		or ship.hours_sailed < 0
		or ship.hours_sailed >= ship.voyage_hours
	):
		violations.append("%s: invalid voyage %s -> %s" % [where, ship.origin, ship.destination])
	return violations
