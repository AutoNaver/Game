class_name RouteSystem
extends RefCounted
## Hourly: moves ships along their trade routes (ADR 0007). A route ship docked at its current stop
## carries out that stop's orders, then sails for the next stop; one docked anywhere else sails for
## its current stop. Everything goes through the same commands the player uses, so the usual checks
## and invariants apply. Orders that can't be carried out are noted on the ship and skipped; the
## ship keeps to its route.


static func run_hour(sim: Simulation) -> void:
	for trader in sim.world.traders:
		if trader.bankrupt:
			continue
		for ship in trader.ships:
			if ship.route_id.is_empty() or not ship.is_docked() or ship.captain_id.is_empty():
				continue
			var route := trader.get_route(ship.route_id)
			var stop := route.stops[ship.route_stop]
			if ship.docked_at == stop.city_id:
				ship.route_note = "; ".join(_carry_out(sim, trader, ship, stop))
				ship.route_stop = route.next_stop(ship.route_stop)
				stop = route.stops[ship.route_stop]
			var error := sim.execute(SailCommand.new(trader.id, ship.id, stop.city_id))
			if not error.is_empty():
				ship.route_note = error


## Carries out the stop's orders in order. Returns a note per order that couldn't be carried out.
static func _carry_out(
	sim: Simulation, trader: TraderState, ship: ShipState, stop: RouteStop
) -> PackedStringArray:
	var notes: PackedStringArray = []
	for order in stop.orders:
		var note := _carry_out_order(sim, trader, ship, order)
		if not note.is_empty():
			notes.append("%s: %s" % [Command.city_name(sim, stop.city_id), note])
	return notes


static func _carry_out_order(
	sim: Simulation, trader: TraderState, ship: ShipState, order: RouteOrder
) -> String:
	var good := sim.data.get_good(order.good_id)
	var city := sim.world.get_city(ship.docked_at)
	var command: Command = null
	var quantity := 0
	match order.action:
		RouteOrder.Action.BUY:
			var room := sim.data.get_ship(ship.type_id).capacity - ship.cargo_total()
			if room <= 0:
				return "no room for %s" % good.name
			if city.stock[good.id] <= 0:
				return "no %s for sale" % good.name
			quantity = CityEconomy.affordable_quantity(
				sim.data.economy,
				city,
				good,
				mini(order.quantity, room),
				order.price_limit,
				trader.coins
			)
			if quantity <= 0:
				var limit := order.price_limit
				if limit > 0 and _first_unit_price(sim, city, good) > limit:
					return "%s dearer than %d" % [good.name, limit]
				return "not enough coins for %s" % good.name
			command = BuyCommand.new(trader.id, ship.id, good.id, quantity)
		RouteOrder.Action.SELL:
			var held := mini(order.quantity, ship.cargo_of(good.id))
			if held <= 0:
				return ""
			quantity = _sell_quantity(sim, city, good, held, order)
			if quantity <= 0:
				return "%s cheaper than %d" % [good.name, order.price_limit]
			command = SellCommand.new(trader.id, ship.id, good.id, quantity)
		RouteOrder.Action.LOAD, RouteOrder.Action.UNLOAD:
			var kontor := trader.get_kontor(ship.docked_at)
			if kontor == null:
				return "no kontor to %s" % ("load from" if _is_load(order) else "unload into")
			var ship_room := sim.data.get_ship(ship.type_id).capacity - ship.cargo_total()
			var kontor_room := sim.data.kontor.capacity - kontor.cargo_total()
			if _is_load(order):
				if ship_room <= 0 and kontor.cargo_of(good.id) > 0:
					return "no room to load %s" % good.name
				quantity = mini(order.quantity, mini(kontor.cargo_of(good.id), ship_room))
			else:
				var aboard := ship.cargo_of(good.id)
				quantity = mini(order.quantity, mini(aboard, kontor_room))
				if quantity <= 0 and aboard > 0:
					return "kontor full, %s stays aboard" % good.name
			if quantity <= 0:
				return ""
			command = TransferCommand.new(
				trader.id, ship.id, good.id, quantity, not _is_load(order)
			)
	return sim.execute(command)


static func _is_load(order: RouteOrder) -> bool:
	return order.action == RouteOrder.Action.LOAD


## Units to sell: up to `most`, while each unit fetches at least the price limit.
static func _sell_quantity(
	sim: Simulation, city: CityState, good: GoodDef, most: int, order: RouteOrder
) -> int:
	if order.price_limit <= 0:
		return most
	var factor := 1.0 - sim.data.economy.spread / 2.0
	var quantity := 0
	while quantity < most:
		if _mid(sim, city, good, city.stock[good.id] + quantity) * factor < order.price_limit:
			break
		quantity += 1
	return quantity


## What the next unit bought here costs, before rounding.
static func _first_unit_price(sim: Simulation, city: CityState, good: GoodDef) -> float:
	var mid := _mid(sim, city, good, city.stock[good.id] - 1)
	return mid * (1.0 + sim.data.economy.spread / 2.0)


static func _mid(sim: Simulation, city: CityState, good: GoodDef, position: int) -> float:
	var target := CityEconomy.target_stock(sim.data.economy, city, good)
	return Pricing.mid_price(sim.data.economy, good.base_price, target, position)
