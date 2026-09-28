class_name TradePlanner
extends RefCounted
## Suggests cargo for a ship: for each other city, the good that makes the most profit when bought
## here and sold there at the house's last known prices. A read-only query; it changes nothing.
##
## Buying walks this market's price up and selling walks the destination's down (ADR 0003), so each
## extra unit earns less. The load is the quantity with the best profit as the trade commands
## round it (cost up, revenue down), within the free space and coins available.
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
	data: GameData,
	trader: TraderState,
	ship_type: ShipDef,
	from_city: String,
	space: int,
	coins: int
) -> Array[Option]:
	var options: Array[Option] = []
	var order: Dictionary[Option, int] = {}
	var source_record: MarketRecord = trader.market_book.get(from_city)
	if source_record == null:
		return options
	var source := source_record.as_city()
	for city_def in data.cities:
		if city_def.id == from_city:
			continue
		var market_record: MarketRecord = trader.market_book.get(city_def.id)
		if market_record == null:
			continue
		var market := market_record.as_city()
		var best: Option = null
		for good in data.goods:
			var option := _best_load(data, source, market, good, space, coins)
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
	source: CityState,
	market: CityState,
	good: GoodDef,
	space: int,
	coins: int,
) -> Option:
	var economy := data.economy
	var source_target := CityEconomy.target_stock(economy, source, good)
	var market_target := CityEconomy.target_stock(economy, market, good)
	var stock: int = source.stock[good.id]
	var market_stock: int = market.stock[good.id]
	var buy_factor := 1.0 + economy.spread / 2.0
	var sell_factor := 1.0 - economy.spread / 2.0
	var quantity := 0
	var buy_total := 0.0
	var sell_total := 0.0
	var best_quantity := 0
	var best_profit := 0
	# Adding units raises the unrounded profit only while the next unit sells for more than it
	# costs, and the rounded profit (what the trade commands pay) is never above the unrounded one.
	# So once the unrounded profit can no longer beat the best rounded profit, stop. The running
	# totals sum in the same order as Pricing.buy_cost() and sell_revenue().
	while quantity < mini(space, stock):
		var buy := Pricing.mid_price(economy, good.base_price, source_target, stock - 1 - quantity)
		var sell := Pricing.mid_price(
			economy, good.base_price, market_target, market_stock + quantity
		)
		var total_cost := ceili((buy_total + buy) * buy_factor)
		if total_cost > coins:
			break
		buy_total += buy
		sell_total += sell
		quantity += 1
		var profit := floori(sell_total * sell_factor) - total_cost
		if profit > best_profit:
			best_profit = profit
			best_quantity = quantity
		var unrounded := sell_total * sell_factor - buy_total * buy_factor
		if sell * sell_factor <= buy * buy_factor and unrounded <= best_profit:
			break
	if best_quantity == 0:
		return null
	var cost := CityEconomy.buy_cost(economy, source, good, best_quantity)
	var revenue := CityEconomy.sell_revenue(economy, market, good, best_quantity)
	return Option.new(market.id, good.id, best_quantity, cost, revenue, 0)
