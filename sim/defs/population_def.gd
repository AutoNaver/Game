class_name PopulationDef
extends RefCounted
## How cities' satisfaction and population change (data/population.json). See ADR 0010.
##
## Satisfaction is how well the market covered the townsfolk's needs over the last days. It sets
## the population the city can sustain, and the population drifts towards it:
##     sustainable = home × (1 + sensitivity × (satisfaction − neutral_satisfaction))
## clamped to [min_factor, max_factor] × home, where home is the population in data/cities.json.

## Each day moves satisfaction this share of the way towards the day's supply score, so it
## remembers roughly the last 1 / this many days.
var satisfaction_weight: float
## Satisfaction at which a city sustains exactly its home population.
var neutral_satisfaction: float
## Change in the sustainable population, as a share of home, per unit of satisfaction above or
## below neutral: 1.0 turns 10 points above neutral into 10% more people.
var sensitivity: float
## Share of the gap to the sustainable population that moves in or out each day.
var growth_rate: float
## A city never sustains fewer than min_factor × home, nor more than max_factor × home, people.
var min_factor: float
var max_factor: float


func _init(
	p_satisfaction_weight: float,
	p_neutral_satisfaction: float,
	p_sensitivity: float,
	p_growth_rate: float,
	p_min_factor: float,
	p_max_factor: float,
) -> void:
	satisfaction_weight = p_satisfaction_weight
	neutral_satisfaction = p_neutral_satisfaction
	sensitivity = p_sensitivity
	growth_rate = p_growth_rate
	min_factor = p_min_factor
	max_factor = p_max_factor


## Fewest people `home_population` can shrink to (rounded up, so the bound is always inside).
func min_population(home_population: int) -> int:
	return _scale_up(home_population, min_factor)


## Most people `home_population` can grow to (rounded down).
func max_population(home_population: int) -> int:
	@warning_ignore("integer_division")
	return home_population * CityEconomy.rate_steps(max_factor) / CityEconomy.RATE_STEPS


static func _scale_up(value: int, factor: float) -> int:
	var scaled := value * CityEconomy.rate_steps(factor)
	@warning_ignore("integer_division")
	return (scaled + CityEconomy.RATE_STEPS - 1) / CityEconomy.RATE_STEPS
