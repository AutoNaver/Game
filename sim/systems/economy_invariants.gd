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
			var carries: Array[int] = [
				city.production_carry[good.id],
				city.consumption_carry[good.id],
				city.trade_carry[good.id],
			]
			for carry in carries:
				if carry < 0 or carry >= CityEconomy.PARTS_PER_UNIT:
					var limit := CityEconomy.PARTS_PER_UNIT
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
		for kontor in trader.kontors_in_order(data.cities):
			violations.append_array(_check_kontor(data, world.hour, trader, kontor))
	for city in world.cities:
		var employed := CityEconomy.workers_employed(data, world, city.id)
		var workforce := CityEconomy.workforce(data.economy, city)
		if employed > workforce:
			var message := "hour %d, %s: %d workers employed of a workforce of %d"
			violations.append(message % [world.hour, city.id, employed, workforce])
	violations.append_array(_check_conservation(data, world))
	return violations


static func _check_kontor(
	data: GameData, hour: int, trader: TraderState, kontor: KontorState
) -> PackedStringArray:
	var violations: PackedStringArray = []
	var where := "hour %d, %s kontor in %s" % [hour, trader.id, kontor.city_id]
	if trader.kontors.get(kontor.city_id) != kontor or not data.has_city(kontor.city_id):
		violations.append("%s: filed under the wrong city" % where)
	for good_id: String in kontor.cargo.keys():
		if not data.has_good(good_id) or kontor.cargo[good_id] <= 0:
			violations.append("%s: bad entry %s=%d" % [where, good_id, kontor.cargo[good_id]])
	if kontor.cargo_total() > data.kontor.capacity:
		var sizes := [where, kontor.cargo_total(), data.kontor.capacity]
		violations.append("%s: holds %d, over capacity %d" % sizes)
	for workshop in kontor.workshops:
		if not data.has_workshop(workshop.type_id):
			violations.append("%s: unknown workshop type '%s'" % [where, workshop.type_id])
	return violations


static func _check_ship(data: GameData, hour: int, ship: ShipState) -> PackedStringArray:
	var violations: PackedStringArray = []
	var where := "hour %d, %s" % [hour, ship.id]
	for good_id: String in ship.cargo.keys():
		if not data.has_good(good_id) or ship.cargo[good_id] <= 0:
			violations.append("%s: bad cargo entry %s=%d" % [where, good_id, ship.cargo[good_id]])
	if not data.has_ship(ship.type_id):
		violations.append("%s: unknown ship type '%s'" % [where, ship.type_id])
	elif ship.cargo_total() > data.get_ship(ship.type_id).capacity:
		var capacity := data.get_ship(ship.type_id).capacity
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


## Goods may only appear through production and disappear through consumption: the units that
## actually exist must equal the ledger kept by those systems.
static func _check_conservation(data: GameData, world: WorldState) -> PackedStringArray:
	var violations: PackedStringArray = []
	for good in data.goods:
		var total := 0
		for city in world.cities:
			total += city.stock[good.id]
		for trader in world.traders:
			for ship in trader.ships:
				total += ship.cargo_of(good.id)
			for kontor in trader.kontors_in_order(data.cities):
				total += kontor.cargo_of(good.id)
		var expected: int = world.goods_ledger[good.id]
		if total != expected:
			var message := "hour %d, %s: %d units exist but production and consumption account for %d"
			violations.append(message % [world.hour, good.id, total, expected])
	return violations
