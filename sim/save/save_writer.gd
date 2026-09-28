class_name SaveWriter
extends RefCounted
## Turns a trading house and what it owns into the plain dictionaries SaveGame writes. SaveGame
## owns the format, its version and reading it back; this only splits the writing side off.


static func trader_to_dict(trader: TraderState, cities: Array[CityState]) -> Dictionary:
	var ships: Array = []
	for ship in trader.ships:
		(
			ships
			. append(
				{
					"id": ship.id,
					"type": ship.type_id,
					"name": ship.name,
					"captain": ship.captain_id,
					"cargo": ship.cargo.duplicate(),
					"docked_at": ship.docked_at,
					"origin": ship.origin,
					"destination": ship.destination,
					"voyage_hours": ship.voyage_hours,
					"hours_sailed": ship.hours_sailed,
					"route": ship.route_id,
					"route_stop": ship.route_stop,
					"route_note": ship.route_note,
					"spoil_carry": ship.spoil_carry.duplicate(),
					"news": market_to_dict(ship.news) if ship.news != null else null,
				}
			)
		)
	var kontors: Array = []
	for city_id: String in trader.kontors.keys():
		var kontor: KontorState = trader.kontors[city_id]
		var workshops: Array = []
		for workshop in kontor.workshops:
			(
				workshops
				. append(
					{
						"id": workshop.id,
						"type": workshop.type_id,
						"status": WorkshopState.Status.keys()[workshop.status],
						"missing_good": workshop.missing_good,
						"progress": workshop.progress,
					}
				)
			)
		(
			kontors
			. append(
				{
					"city": kontor.city_id,
					"cargo": kontor.cargo.duplicate(),
					"spoil_carry": kontor.spoil_carry.duplicate(),
					"workshops": workshops,
					"factor": _factor(kontor),
				}
			)
		)
	kontors.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["city"] < b["city"])
	var routes: Array = []
	var captains: Array = []
	for captain in trader.captains:
		captains.append(captain_to_dict(captain))
	for route in trader.routes:
		var stops: Array = []
		for stop in route.stops:
			var orders: Array = []
			for order in stop.orders:
				(
					orders
					. append(
						{
							"action": RouteOrder.Action.keys()[order.action],
							"good": order.good_id,
							"quantity": order.quantity,
							"price_limit": order.price_limit,
						}
					)
				)
			stops.append({"city": stop.city_id, "orders": orders})
		routes.append({"id": route.id, "name": route.name, "stops": stops})
	var market_book: Array = []
	for city in cities:
		if trader.market_book.has(city.id):
			market_book.append(market_to_dict(trader.market_book[city.id]))
	return {
		"id": trader.id,
		"name": trader.name,
		"coins": trader.coins,
		"debt": trader.debt,
		"debt_days": trader.debt_days,
		"bankrupt": trader.bankrupt,
		"person_ship": trader.person_ship_id,
		"person_city": trader.person_city_id,
		"captains": captains,
		"ships": ships,
		"kontors": kontors,
		"routes": routes,
		"market_book": market_book,
		"rank": trader.rank_id,
		"sale_end_day": trader.sale_end_day,
		"reputation": _reputation(trader, cities),
	}


## Only cities with reputation, in city order.
static func _reputation(trader: TraderState, cities: Array[CityState]) -> Dictionary:
	var table: Dictionary = {}
	for city in cities:
		if trader.reputation.has(city.id):
			table[city.id] = trader.reputation[city.id]
	return table


static func _factor(kontor: KontorState) -> Array:
	var orders: Array = []
	for order in kontor.factor_orders:
		(
			orders
			. append(
				{
					"action": FactorOrder.Action.keys()[order.action],
					"good": order.good_id,
					"amount": order.amount,
					"price_limit": order.price_limit,
				}
			)
		)
	return orders


static func captain_to_dict(captain: CaptainState) -> Dictionary:
	return {
		"id": captain.id,
		"name": captain.name,
		"wage": captain.wage,
		"seamanship": captain.seamanship,
		"trading": captain.trading,
		"voyages": captain.voyages,
		"city": captain.city_id,
		"ship": captain.ship_id,
	}


static func market_to_dict(record: MarketRecord) -> Dictionary:
	var history: Dictionary = {}
	for good_id: String in record.history:
		history[good_id] = Array(record.history[good_id])
	return {
		"city": record.city_id,
		"day": record.day,
		"population": record.population,
		"satisfaction": record.satisfaction,
		"stock": record.stock.duplicate(),
		"shortage": record.shortage.duplicate(),
		"history": history,
	}


static func offers_to_dict(world: WorldState) -> Array:
	var offers: Array = []
	for offer in world.offers:
		(
			offers
			. append(
				{
					"id": offer.id,
					"buyer": offer.buyer_id,
					"kind": OfferState.Kind.keys()[offer.kind],
					"asset": offer.asset_id,
					"price": offer.price,
					"last_day": offer.last_day,
				}
			)
		)
	return offers
