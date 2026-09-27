class_name CityEconomy
extends RefCounted
## Derived per-city economy numbers. Nothing here is stored; it is recomputed from state + data.
##
## Daily flows are counted in integer thousandths of a unit ("millis") so fractional rates add up
## exactly over many days; floats would drift (7.2/day summing to 35.9999 after 5 days).

const MILLIS_PER_UNIT: int = 1000


## Units of `good` the city's population wants per day.
static func daily_demand(city: CityState, good: GoodDef) -> float:
	return city.population / 1000.0 * good.consumption_per_1000


## Thousandths of a unit of `good` the population wants per day, rounded to the nearest
## thousandth. The rounding is deterministic and at most 0.0005 units a day.
static func daily_demand_millis(city: CityState, good: GoodDef) -> int:
	return roundi(city.population * good.consumption_per_1000)


## Converts a per-day rate in units to thousandths of a unit.
static func to_millis(units_per_day: float) -> int:
	return roundi(units_per_day * MILLIS_PER_UNIT)


## Whole units contained in an amount of thousandths (rounding down).
static func whole_units(millis: int) -> int:
	@warning_ignore("integer_division")
	return millis / MILLIS_PER_UNIT


## The stock at which the good trades at its base price (ADR 0003). At least 1.
static func target_stock(economy: EconomyDef, city: CityState, good: GoodDef) -> int:
	return maxi(1, ceili(daily_demand(city, good) * economy.days_of_cover))


## City workshops stop producing a good once stock reaches this.
static func stock_cap(economy: EconomyDef, city: CityState, good: GoodDef) -> int:
	return ceili(target_stock(economy, city, good) * economy.stock_cap_factor)
