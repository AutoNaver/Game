class_name TradePlanner
extends RefCounted
## Suggests cargo for a ship: for each other city, the good that makes the most profit when bought
## here and sold there at today's prices. A read-only query for the UI; it changes nothing.
##
## Buying walks this market's price up and selling walks the destination's down (ADR 0003), so the
## load stops at the first unit that no longer pays, and at the free space and coins available.
## Prices at the destination can move before the ship arrives; the plan is a hint, not a promise.


## The best load for one destination.
class Option:
	extends RefCounted
	var destination: String
	var good_id: String
	var quantity: int
	var cost: int
	var revenue: int
	var hours: int

	func _init(
		p_destination: String,
		p_good_id: String,
		p_quantity: int,
		p_cost: int,
		p_revenue: int,
		p_hours: int,
	) -> void:
		destination = p_destination
		good_id = p_good_id
		quantity = p_quantity
		cost = p_cost
		revenue = p_revenue
		hours = p_hours

	func profit() -> int:
		return revenue - cost

	## Profit per day of sailing, for comparing near and far destinations.
	func profit_per_day() -> float:
		return profit() * float(Simulation.HOURS_PER_DAY) / hours


## One option per destination city with a profitable load, best profit per day first.
## `space` is the ship's free cargo space and `coins` what the trader can spend.
static func plan(
	data: GameData, world: WorldState, ship_type: ShipDef, from_city: String, space: int, coins: int
) -> Array[Option]:
	var options: Array[Option] = []
	var order: Dictionary[Option, int] = {}
	for city_def in data.cities:
		if city_def.id == from_city:
			continue
		var best: Option = null
		for good in data.goods:
			var option := _best_load(data, world, from_city, city_def.id, good, space, coins)
			if option != null and (best == null or option.profit() > best.profit()):
				best = option
		if best != null:
			best.hours = Navigation.travel_hours(data, ship_type, from_city, city_def.id)
			order[best] = options.size()
			options.append(best)
	# sort_custom isn't stable: break ties by city order so the result is deterministic.
	options.sort_custom(
		func(a: Option, b: Option) -> bool:
			if a.profit_per_day() != b.profit_per_day():
				return a.profit_per_day() > b.profit_per_day()
			return order[a] < order[b]
	)
	return options


## The most profitable quantity of `good` from one city to another, or null if none pays.
static func _best_load(
	data: GameData,
	world: WorldState,
	from_city: String,
	to_city: String,
	good: GoodDef,
	space: int,
	coins: int,
) -> Option:
	var economy := data.economy
	var source := world.get_city(from_city)
	var market := world.get_city(to_city)
	var source_target := CityEconomy.target_stock(economy, source, good)
	var market_target := CityEconomy.target_stock(economy, market, good)
	var stock: int = source.stock[good.id]
	var market_stock: int = market.stock[good.id]
	var buy_factor := 1.0 + economy.spread / 2.0
	var sell_factor := 1.0 - economy.spread / 2.0
	var quantity := 0
	var buy_total := 0.0
	# Each further unit costs more here and fetches less there, so stop at the first that loses
	# money or can't be paid for. The running total sums like Pricing.buy_cost().
	while quantity < mini(space, stock):
		var buy := Pricing.mid_price(economy, good.base_price, source_target, stock - 1 - quantity)
		var sell := Pricing.mid_price(
			economy, good.base_price, market_target, market_stock + quantity
		)
		if sell * sell_factor <= buy * buy_factor:
			break
		if ceili((buy_total + buy) * buy_factor) > coins:
			break
		buy_total += buy
		quantity += 1
	if quantity == 0:
		return null
	var cost := CityEconomy.buy_cost(economy, source, good, quantity)
	var revenue := CityEconomy.sell_revenue(economy, market, good, quantity)
	if revenue <= cost:
		return null
	return Option.new(to_city, good.id, quantity, cost, revenue, 0)
