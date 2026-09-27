class_name Simulation
extends RefCounted
## Owns the world and advances it. One tick is one in-game hour; the daily systems run whenever a
## tick completes a day, in a fixed order: production, then consumption.
##
## Prices are not stored: they are derived from stock on demand (see Pricing, CityEconomy).

const HOURS_PER_DAY: int = 24

var data: GameData
var world: WorldState


func _init(p_data: GameData, p_world: WorldState) -> void:
	data = p_data
	world = p_world


## Starts a new game: every city holds its target stock of every good, so prices start at base.
static func new_game(p_data: GameData, seed_value: int) -> Simulation:
	var world := WorldState.new()
	world.rng.seed = seed_value
	for city_def in p_data.cities:
		var city := CityState.new(city_def.id, city_def.population)
		for good in p_data.goods:
			city.stock[good.id] = CityEconomy.target_stock(p_data.economy, city, good)
			city.production_carry[good.id] = 0.0
			city.consumption_carry[good.id] = 0.0
			city.shortage[good.id] = 0
		world.add_city(city)
	return Simulation.new(p_data, world)


## Whole days elapsed since the start.
func day() -> int:
	@warning_ignore("integer_division")
	return world.hour / HOURS_PER_DAY


func tick() -> void:
	world.hour += 1
	if world.hour % HOURS_PER_DAY == 0:
		ProductionSystem.run_day(data, world)
		ConsumptionSystem.run_day(data, world)


func advance_days(days: int) -> void:
	for i in days * HOURS_PER_DAY:
		tick()
