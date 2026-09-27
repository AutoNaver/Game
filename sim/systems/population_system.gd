class_name PopulationSystem
extends RefCounted
## Daily city satisfaction and population change (ADR 0010).
##
## Runs after consumption, so a good that ran out today counts as not supplied at all. Each good's
## supply is its stock against its target (capped at 1), and the day's supply score averages them
## weighted by what the townsfolk spend on each good (daily demand × base price), so running out
## of grain hurts more than running out of wine. Satisfaction moves a share of the way towards
## that score every day, and the population moves a share of the way towards what that
## satisfaction sustains (PopulationDef). Everything is integer arithmetic, in millionths.
##
## A city that shrinks below the workers its traders' workshops employ leaves them understaffed,
## so they work slower (CityEconomy.staffing, WorkshopSystem).


static func run_day(data: GameData, world: WorldState) -> void:
	var population := data.population
	var weight_steps := CityEconomy.rate_steps(population.satisfaction_weight)
	for city in world.cities:
		var score := supply_score(data, city)
		@warning_ignore("integer_division")
		city.satisfaction += (score - city.satisfaction) * weight_steps / CityEconomy.RATE_STEPS
		city.population += daily_change(data, city)


## How well the market covers today's needs, in millionths: 1 000 000 when every good is at or
## above its target, 0 when every good has run out.
static func supply_score(data: GameData, city: CityState) -> int:
	var weighted := 0
	var total_weight := 0
	for good in data.goods:
		# Spending per head: every good's demand scales with the same population, so it cancels.
		var weight := CityEconomy.rate_steps(good.consumption_per_1000) * good.base_price
		if weight == 0:
			continue
		total_weight += weight
		weighted += weight * supply(data.economy, city, good)
	if total_weight == 0:
		return CityEconomy.PARTS_PER_UNIT
	@warning_ignore("integer_division")
	return weighted / total_weight


## People moving in (positive) or out (negative) per day at the current satisfaction:
## growth_rate of the gap to the sustainable population, rounded towards zero.
static func daily_change(data: GameData, city: CityState) -> int:
	var gap := sustainable_population(data, city) - city.population
	@warning_ignore("integer_division")
	return gap * CityEconomy.rate_steps(data.population.growth_rate) / CityEconomy.RATE_STEPS


## Stock of `good` against its target, capped at the target, in millionths.
static func supply(economy: EconomyDef, city: CityState, good: GoodDef) -> int:
	var target := CityEconomy.target_stock(economy, city, good)
	@warning_ignore("integer_division")
	return mini(city.stock[good.id], target) * CityEconomy.PARTS_PER_UNIT / target


## The population the city's current satisfaction sustains, within the bounds around its home
## population.
static func sustainable_population(data: GameData, city: CityState) -> int:
	var population := data.population
	var home := data.get_city(city.id).population
	var neutral := CityEconomy.to_parts(population.neutral_satisfaction)
	var sensitivity := CityEconomy.rate_steps(population.sensitivity)
	@warning_ignore("integer_division")
	var factor := (
		CityEconomy.PARTS_PER_UNIT
		+ (city.satisfaction - neutral) * sensitivity / CityEconomy.RATE_STEPS
	)
	@warning_ignore("integer_division")
	var sustained := home * factor / CityEconomy.PARTS_PER_UNIT
	return clampi(sustained, population.min_population(home), population.max_population(home))
