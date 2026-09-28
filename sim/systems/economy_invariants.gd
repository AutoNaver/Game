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
		violations.append_array(_check_captains(data, trader))
		violations.append_array(_check_standing(data, trader))
		for ship in trader.ships:
			violations.append_array(_check_ship(data, world.hour, ship))
		for kontor in trader.kontors_in_order(data.cities):
			violations.append_array(_check_kontor(data, world.hour, trader, kontor))
	violations.append_array(_check_taverns(data, world))
	for city in world.cities:
		violations.append_array(_check_population(data, world.hour, city))
	@warning_ignore("integer_division")
	var day := world.hour / Simulation.HOURS_PER_DAY
	for event in world.events:
		if not data.has_event(event.type_id) or not data.has_city(event.city_id):
			violations.append("hour %d, %s: unknown type or city" % [world.hour, event.id])
		# EventSystem starts events on their first day and drops them once over, so every event
		# kept in the world is running today.
		if not event.is_active(day):
			var span := [world.hour, event.id, event.start_day, event.end_day, day]
			violations.append("hour %d, %s: days %d to %d don't include day %d" % span)
	violations.append_array(_check_conservation(data, world))
	return violations


static func _check_captains(data: GameData, trader: TraderState) -> PackedStringArray:
	var violations: PackedStringArray = []
	if trader.debt < 0 or trader.debt_days < 0:
		violations.append("%s: invalid debt or debt days" % trader.id)
	if trader.debt == 0 and trader.debt_days != 0:
		violations.append("%s: debt days without debt" % trader.id)
	for captain in trader.captains:
		violations.append_array(_check_captain(data, trader.id, captain))
		var ship := trader.get_ship(captain.ship_id)
		if ship == null or ship.captain_id != captain.id or not captain.city_id.is_empty():
			violations.append("%s: captain %s has no matching ship" % [trader.id, captain.id])
	for ship in trader.ships:
		if not ship.captain_id.is_empty():
			var captain := trader.get_captain(ship.captain_id)
			if captain == null:
				violations.append("%s: ship %s has unknown captain" % [trader.id, ship.id])
			elif captain.ship_id != ship.id:
				violations.append(
					(
						"%s: ship %s names captain %s of another ship"
						% [trader.id, ship.id, captain.id]
					)
				)
		if not ship.is_docked() and ship.captain_id.is_empty():
			violations.append("%s: ship %s is at sea without a captain" % [trader.id, ship.id])
	if trader.id == WorldState.PLAYER_ID:
		if trader.person_ship_id.is_empty():
			if not data.has_city(trader.person_city_id):
				violations.append("player: unknown shore location '%s'" % trader.person_city_id)
		elif trader.get_ship(trader.person_ship_id) == null or not trader.person_city_id.is_empty():
			violations.append("player: invalid ship location '%s'" % trader.person_ship_id)
	elif not trader.person_city_id.is_empty() or not trader.person_ship_id.is_empty():
		violations.append("%s: rivals cannot have a player location" % trader.id)
	return violations


## A known rank, reputation only for known cities within 1 and the maximum, and factor orders only
## at a rank that unlocks factors (ranks never fall, so a house that set them still may).
static func _check_standing(data: GameData, trader: TraderState) -> PackedStringArray:
	var violations: PackedStringArray = []
	if data.rank_index(trader.rank_id) < 0:
		violations.append("%s: unknown rank '%s'" % [trader.id, trader.rank_id])
	elif not RankSystem.has_unlock(data, trader, RankDef.FACTORS):
		for kontor in trader.kontors_in_order(data.cities):
			if not kontor.factor_orders.is_empty():
				violations.append(
					(
						"%s: factor orders in %s below the rank that unlocks factors"
						% [trader.id, kontor.city_id]
					)
				)
	for city_id: String in trader.reputation:
		var points: int = trader.reputation[city_id]
		if not data.has_city(city_id) or points <= 0 or points > data.reputation.max:
			violations.append("%s: invalid reputation %d in '%s'" % [trader.id, points, city_id])
	return violations


static func _check_taverns(data: GameData, world: WorldState) -> PackedStringArray:
	var violations: PackedStringArray = []
	for city in data.cities:
		if not world.taverns.has(city.id):
			violations.append("%s: missing tavern" % city.id)
			continue
		var pool: Array = world.taverns.get(city.id, [])
		for candidate: CaptainState in pool:
			if candidate.city_id != city.id or not candidate.ship_id.is_empty():
				violations.append(
					"%s tavern: captain %s is assigned elsewhere" % [city.id, candidate.id]
				)
			violations.append_array(_check_captain(data, "%s tavern" % city.id, candidate))
	return violations


## Wage, experience and skills of a hired captain or tavern candidate.
static func _check_captain(
	data: GameData, where: String, captain: CaptainState
) -> PackedStringArray:
	var violations: PackedStringArray = []
	if captain.wage <= 0 or captain.voyages < 0:
		violations.append("%s: invalid captain %s" % [where, captain.id])
	if captain.seamanship < 0 or captain.seamanship > data.captains.max_skill:
		violations.append("%s: invalid seamanship for %s" % [where, captain.id])
	if captain.trading < 0 or captain.trading > data.captains.max_skill:
		violations.append("%s: invalid trading for %s" % [where, captain.id])
	return violations


static func _check_population(data: GameData, hour: int, city: CityState) -> PackedStringArray:
	var violations: PackedStringArray = []
	var where := "hour %d, %s" % [hour, city.id]
	var home := data.get_city(city.id).population
	var lowest := data.population.min_population(home)
	var highest := data.population.max_population(home)
	if city.population < lowest or city.population > highest:
		var bounds := [where, city.population, lowest, highest]
		violations.append("%s: population %d outside %d to %d" % bounds)
	if city.satisfaction < 0 or city.satisfaction > CityEconomy.PARTS_PER_UNIT:
		violations.append("%s: satisfaction %d out of range" % [where, city.satisfaction])
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
	violations.append_array(_check_spoil_carry(data, where, kontor))
	if kontor.cargo_total() > data.kontor.capacity:
		var sizes := [where, kontor.cargo_total(), data.kontor.capacity]
		violations.append("%s: holds %d, over capacity %d" % sizes)
	for workshop in kontor.workshops:
		if not data.has_workshop(workshop.type_id):
			violations.append("%s: unknown workshop type '%s'" % [where, workshop.type_id])
		if workshop.progress < 0 or workshop.progress > CityEconomy.PARTS_PER_UNIT:
			var progress := [where, workshop.id, workshop.progress]
			violations.append("%s: %s progress %d out of range" % progress)
	return violations


static func _check_ship(data: GameData, hour: int, ship: ShipState) -> PackedStringArray:
	var violations: PackedStringArray = []
	var where := "hour %d, %s" % [hour, ship.id]
	for good_id: String in ship.cargo.keys():
		if not data.has_good(good_id) or ship.cargo[good_id] <= 0:
			violations.append("%s: bad cargo entry %s=%d" % [where, good_id, ship.cargo[good_id]])
	violations.append_array(_check_spoil_carry(data, where, ship))
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


static func _check_spoil_carry(data: GameData, where: String, hold: Hold) -> PackedStringArray:
	var violations: PackedStringArray = []
	for good_id: String in hold.spoil_carry.keys():
		var parts: int = hold.spoil_carry[good_id]
		if not data.has_good(good_id) or parts <= 0 or parts >= CityEconomy.PARTS_PER_UNIT:
			violations.append("%s: bad spoilage carry %s=%d" % [where, good_id, parts])
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
