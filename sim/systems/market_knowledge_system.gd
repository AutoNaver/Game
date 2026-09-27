class_name MarketKnowledgeSystem
extends RefCounted
## Updates each house's market book from its ships and kontors. A newly arrived ship trades only
## its departure report with other houses' ships in port; nobody gets the live remote market.


## At M12 the player is ashore in the starting city until M13 adds movement for the person.
static func has_presence(data: GameData, trader: TraderState, city_id: String) -> bool:
	if trader.id == WorldState.PLAYER_ID and city_id == data.scenario.start_city:
		return true
	if trader.get_kontor(city_id) != null:
		return true
	for ship in trader.ships:
		if ship.docked_at == city_id:
			return true
	return false


## A report of the market as it is now; called only for places the trader can actually observe.
static func current_report(data: GameData, city: CityState, day: int) -> MarketRecord:
	var report := MarketRecord.new(city.id, day)
	report.population = city.population
	report.satisfaction = city.satisfaction
	for good in data.goods:
		report.stock[good.id] = city.stock[good.id]
		report.shortage[good.id] = city.shortage[good.id]
	fill_prices(data, report)
	return report


## Derive a report's quotes from its remembered stock and population. Quotes are never saved, so
## a loaded report can't disagree with the market it describes.
static func fill_prices(data: GameData, report: MarketRecord) -> void:
	var city := report.as_city()
	for good in data.goods:
		report.buy_price[good.id] = (
			CityEconomy.buy_cost(data.economy, city, good, 1) if city.stock[good.id] > 0 else 0
		)
		report.sell_price[good.id] = CityEconomy.sell_revenue(data.economy, city, good, 1)
		report.mid_price[good.id] = PriceHistorySystem.scaled_price(
			CityEconomy.mid_price(data.economy, city, good)
		)


## Give all houses a first report wherever they start with presence; ships can carry it away.
static func initialize(data: GameData, world: WorldState) -> void:
	observe_presence(data, world)
	for trader in world.traders:
		for ship in trader.ships:
			if ship.is_docked():
				ship.news = trader.market_book[ship.docked_at].copy_report()


## Refresh every currently visible city after commands and after the daily economy changes.
static func observe_presence(data: GameData, world: WorldState) -> void:
	@warning_ignore("integer_division")
	var day := world.hour / Simulation.HOURS_PER_DAY
	for trader in world.traders:
		for city in world.cities:
			if has_presence(data, trader, city.id):
				var report := current_report(data, city, day)
				var existing: MarketRecord = trader.market_book.get(city.id)
				if existing == null:
					trader.market_book[city.id] = report
				else:
					existing.update_from(report)


## Keep a newer report; equal-day gossip never overwrites an observation from presence.
static func learn(trader: TraderState, report: MarketRecord) -> void:
	if report == null:
		return
	var existing: MarketRecord = trader.market_book.get(report.city_id)
	if existing == null:
		trader.market_book[report.city_id] = report.copy_report()
	elif report.day > existing.day:
		existing.update_from(report)


## Exchange each arrival's departure report with other houses' docked ships in stable order.
static func on_arrivals(data: GameData, world: WorldState, arrivals: Array[ShipState]) -> void:
	if arrivals.is_empty():
		return
	for trader in world.traders:
		for ship in trader.ships:
			if not arrivals.has(ship):
				continue
			for other in world.traders:
				if other == trader:
					continue
				for visitor in other.ships:
					if visitor.docked_at == ship.docked_at:
						learn(trader, visitor.news)
						learn(other, ship.news)
	observe_presence(data, world)


## Append one daily price point or gap for every known city, preserving only 30 calendar days.
static func record_day(data: GameData, world: WorldState) -> void:
	observe_presence(data, world)
	@warning_ignore("integer_division")
	var day := world.hour / Simulation.HOURS_PER_DAY
	for trader in world.traders:
		for city in data.cities:
			var record: MarketRecord = trader.market_book.get(city.id)
			if record == null:
				continue
			var present := has_presence(data, trader, city.id)
			for good in data.goods:
				var history: PackedInt64Array = record.history.get(good.id, PackedInt64Array())
				while history.size() < mini(day - 1, PriceHistorySystem.HISTORY_DAYS - 1):
					history.append(-1)
				history.append(record.mid_price[good.id] if present else -1)
				if history.size() > PriceHistorySystem.HISTORY_DAYS:
					history.remove_at(0)
				record.history[good.id] = history
