class_name PriceHistorySystem
extends RefCounted
## Records each city's mid price per good once a day, so the UI can show how markets move.
##
## Prices are stored as whole hundredths of a coin: exact in JSON saves and independent of float
## formatting. Only the last HISTORY_DAYS entries are kept.

## Days of history kept per city and good.
const HISTORY_DAYS: int = 30
## Stored prices are in 1 / PRICE_SCALE coins.
const PRICE_SCALE: int = 100


## Appends today's closing prices. Runs after all other daily systems.
static func run_day(data: GameData, world: WorldState) -> void:
	for city in world.cities:
		for good in data.goods:
			var history: PackedInt64Array = city.price_history[good.id]
			history.append(scaled_price(CityEconomy.mid_price(data.economy, city, good)))
			if history.size() > HISTORY_DAYS:
				history.remove_at(0)
			city.price_history[good.id] = history


static func scaled_price(price: float) -> int:
	return roundi(price * PRICE_SCALE)


## Lowest stored price `good` can have: the clamped minimum mid price, rounded.
static func min_scaled_price(economy: EconomyDef, good: GoodDef) -> int:
	return scaled_price(good.base_price * economy.price_min_multiplier)


## Highest stored price `good` can have: the clamped maximum mid price, rounded.
static func max_scaled_price(economy: EconomyDef, good: GoodDef) -> int:
	return scaled_price(good.base_price * economy.price_max_multiplier)
