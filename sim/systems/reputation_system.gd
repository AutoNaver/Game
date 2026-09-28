class_name ReputationSystem
extends RefCounted
## A house's reputation per city (ADR 0015). It grows by selling goods the city is short of, by
## holding a kontor there and by every workshop that works a day, and falls for every workshop
## that stands idle a day. Points are whole numbers from 0 to ReputationDef.max.


static func of(trader: TraderState, city_id: String) -> int:
	return trader.reputation.get(city_id, 0)


## Books a sale before the city's stock changes: every unit that brings the stock up towards the
## target counts as supplying a shortage.
static func on_sale(
	data: GameData, trader: TraderState, city: CityState, good: GoodDef, quantity: int
) -> void:
	var target := CityEconomy.target_stock(data.economy, city, good)
	var short := clampi(target - city.stock[good.id], 0, quantity)
	add(data, trader, city.id, short * data.reputation.per_shortage_unit)


## Daily, after the workshops ran: kontors and working workshops add, idle workshops take away.
static func run_day(data: GameData, world: WorldState) -> void:
	var rules := data.reputation
	for trader in world.traders:
		if trader.bankrupt:
			continue
		for kontor in trader.kontors_in_order(data.cities):
			var change := rules.per_kontor_day
			for workshop in kontor.workshops:
				match workshop.status:
					WorkshopState.Status.WORKED:
						change += rules.per_workshop_day
					WorkshopState.Status.NEW:
						pass
					_:
						change -= rules.per_idle_workshop_day
			add(data, trader, kontor.city_id, change)


## Adds `points` (negative to take away), keeping the result within 0 and the maximum.
static func add(data: GameData, trader: TraderState, city_id: String, points: int) -> void:
	if points == 0:
		return
	var value := clampi(of(trader, city_id) + points, 0, data.reputation.max)
	if value == 0:
		trader.reputation.erase(city_id)
	else:
		trader.reputation[city_id] = value


## Cities where the house has at least the standing reputation.
static func standing_cities(data: GameData, trader: TraderState) -> int:
	var count := 0
	for city in data.cities:
		if of(trader, city.id) >= data.reputation.standing:
			count += 1
	return count
