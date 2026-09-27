class_name CityEconomy
extends RefCounted
## Derived per-city economy numbers. Nothing here is stored; it is recomputed from state + data.


## Units of `good` the city's population wants per day.
static func daily_demand(city: CityState, good: GoodDef) -> float:
	return city.population / 1000.0 * good.consumption_per_1000


## The stock at which the good trades at its base price (ADR 0003). At least 1.
static func target_stock(economy: EconomyDef, city: CityState, good: GoodDef) -> int:
	return maxi(1, ceili(daily_demand(city, good) * economy.days_of_cover))


## City workshops stop producing a good once stock reaches this.
static func stock_cap(economy: EconomyDef, city: CityState, good: GoodDef) -> int:
	return ceili(target_stock(economy, city, good) * economy.stock_cap_factor)


## Coins a trader pays to buy `quantity` units of `good` here (walks the price, ADR 0003).
static func buy_cost(economy: EconomyDef, city: CityState, good: GoodDef, quantity: int) -> int:
	var target := target_stock(economy, city, good)
	return Pricing.buy_cost(economy, good.base_price, target, city.stock[good.id], quantity)


## Coins a trader receives for selling `quantity` units of `good` here.
static func sell_revenue(economy: EconomyDef, city: CityState, good: GoodDef, quantity: int) -> int:
	var target := target_stock(economy, city, good)
	return Pricing.sell_revenue(economy, good.base_price, target, city.stock[good.id], quantity)
