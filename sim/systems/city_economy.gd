class_name CityEconomy
extends RefCounted
## Derived per-city economy numbers. Nothing here is stored; it is recomputed from state + data.
##
## Daily flows are counted in integer millionths of a unit ("parts") so fractional rates add up
## exactly over many days; floats would drift (7.2/day summing to 35.9999 after 5 days).
## Data rates are multiples of 0.001 (enforced by the loader), so every flow is an exact number
## of parts: production is rate × 1e6, and demand is population × (per-1000 rate × 1000).

const PARTS_PER_UNIT: int = 1_000_000
## Data rates are given in multiples of 1 / RATE_STEPS.
const RATE_STEPS: int = 1000


## Units of `good` the city's population wants per day.
static func daily_demand(city: CityState, good: GoodDef) -> float:
	return city.population / 1000.0 * good.consumption_per_1000


## Millionths of a unit of `good` the population wants per day. Exact: population / 1000 ×
## consumption_per_1000 units is population × (consumption_per_1000 × 1000) millionths.
static func daily_demand_parts(city: CityState, good: GoodDef) -> int:
	return city.population * rate_steps(good.consumption_per_1000)


## Converts a per-day production rate in units to millionths of a unit (exact for valid data).
static func to_parts(units_per_day: float) -> int:
	return rate_steps(units_per_day) * (PARTS_PER_UNIT / RATE_STEPS)


## A data rate as a whole number of 1/RATE_STEPS steps.
static func rate_steps(rate: float) -> int:
	return roundi(rate * RATE_STEPS)


## True if `rate` is an exact multiple of 1/RATE_STEPS (within float noise).
static func is_valid_rate(rate: float) -> bool:
	return absf(rate * RATE_STEPS - roundf(rate * RATE_STEPS)) <= 1e-6


## Whole units contained in an amount of parts (rounding down).
static func whole_units(parts: int) -> int:
	@warning_ignore("integer_division")
	return parts / PARTS_PER_UNIT


## The stock at which the good trades at its base price (ADR 0003). At least 1.
static func target_stock(economy: EconomyDef, city: CityState, good: GoodDef) -> int:
	# Integer ceiling division on exact parts: floats would turn 3.0 into 3.0000000000000004 -> 4.
	var parts := daily_demand_parts(city, good) * economy.days_of_cover
	@warning_ignore("integer_division")
	var units := (parts + PARTS_PER_UNIT - 1) / PARTS_PER_UNIT
	return maxi(1, units)


## City workshops stop producing a good once stock reaches this.
static func stock_cap(economy: EconomyDef, city: CityState, good: GoodDef) -> int:
	# Integer ceiling division: floats would turn 50 x 1.1 = 55 into 55.00000000000001 -> 56.
	var scaled := target_stock(economy, city, good) * rate_steps(economy.stock_cap_factor)
	@warning_ignore("integer_division")
	return (scaled + RATE_STEPS - 1) / RATE_STEPS


## Mid price of `good` here at the current stock, before the spread (ADR 0003).
static func mid_price(economy: EconomyDef, city: CityState, good: GoodDef) -> float:
	var target := target_stock(economy, city, good)
	return Pricing.mid_price(economy, good.base_price, target, city.stock[good.id])


## Coins a trader pays to buy `quantity` units of `good` here (walks the price, ADR 0003).
static func buy_cost(economy: EconomyDef, city: CityState, good: GoodDef, quantity: int) -> int:
	var target := target_stock(economy, city, good)
	return Pricing.buy_cost(economy, good.base_price, target, city.stock[good.id], quantity)


## Coins a trader receives for selling `quantity` units of `good` here.
static func sell_revenue(economy: EconomyDef, city: CityState, good: GoodDef, quantity: int) -> int:
	var target := target_stock(economy, city, good)
	return Pricing.sell_revenue(economy, good.base_price, target, city.stock[good.id], quantity)


## Units of `good` a trader can buy here: up to `most`, while each unit's price after the spread
## stays within `unit_limit` (0 means any price) and the total, rounded up as BuyCommand charges it,
## stays within `coins`. Units are priced as Pricing prices them, top of the stock first.
static func affordable_quantity(
	economy: EconomyDef, city: CityState, good: GoodDef, most: int, unit_limit: float, coins: int
) -> int:
	var target := target_stock(economy, city, good)
	var factor := 1.0 + economy.spread / 2.0
	var stock: int = city.stock[good.id]
	var total := 0.0
	var quantity := 0
	while quantity < mini(most, stock):
		var mid := Pricing.mid_price(economy, good.base_price, target, stock - 1 - quantity)
		if unit_limit > 0.0 and mid * factor > unit_limit:
			break
		if ceili((total + mid) * factor) > coins:
			break
		total += mid
		quantity += 1
	return quantity


## People in the city available to work in traders' workshops.
static func workforce(economy: EconomyDef, city: CityState) -> int:
	@warning_ignore("integer_division")
	return city.population * rate_steps(economy.workforce_share) / RATE_STEPS


## Workers all traders' workshops in the city employ.
static func workers_employed(data: GameData, world: WorldState, city_id: String) -> int:
	var employed := 0
	for trader in world.traders:
		var kontor := trader.get_kontor(city_id)
		if kontor == null:
			continue
		for workshop in kontor.workshops:
			employed += data.get_workshop(workshop.type_id).workers
	return employed


## Workforce not yet employed; a new workshop needs at least its worker count.
static func free_workers(data: GameData, world: WorldState, city: CityState) -> int:
	return workforce(data.economy, city) - workers_employed(data, world, city.id)
