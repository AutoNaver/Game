class_name Simulation
extends RefCounted
## Owns the world and advances it. One tick is one in-game hour: ships move every tick, then ships
## on trade routes act at their stops (RouteSystem, through commands). The daily systems run
## whenever a tick completes a day, in a fixed order: city production, traders' workshops,
## consumption, off-map trade, then price history. Actions enter only through execute().
##
## Current prices are not stored: they are derived from stock on demand (see Pricing,
## CityEconomy). Only the daily closing prices are kept, for the UI (PriceHistorySystem).

const HOURS_PER_DAY: int = 24

var data: GameData
var world: WorldState


func _init(p_data: GameData, p_world: WorldState) -> void:
	data = p_data
	world = p_world


## Starts a new game: every city holds its target stock of every good, so prices start at base,
## and the player starts as described in data/scenario.json.
static func new_game(p_data: GameData, seed_value: int) -> Simulation:
	var world := WorldState.new()
	world.rng.seed = seed_value
	for good in p_data.goods:
		world.goods_ledger[good.id] = 0
	for city_def in p_data.cities:
		var city := CityState.new(city_def.id, city_def.population)
		for good in p_data.goods:
			city.stock[good.id] = CityEconomy.target_stock(p_data.economy, city, good)
			world.goods_ledger[good.id] += city.stock[good.id]
			city.production_carry[good.id] = 0
			city.consumption_carry[good.id] = 0
			city.trade_carry[good.id] = 0
			city.shortage[good.id] = 0
			city.price_history[good.id] = PackedInt64Array()
		world.add_city(city)
	var scenario := p_data.scenario
	var player := TraderState.new(WorldState.PLAYER_ID, "Player", scenario.coins)
	world.traders.append(player)
	for ship in scenario.ships:
		world.add_ship(player, ship.type_id, ship.name, scenario.start_city)
	return Simulation.new(p_data, world)


## Whole days elapsed since the start.
func day() -> int:
	@warning_ignore("integer_division")
	return world.hour / HOURS_PER_DAY


## Validates and applies a command. Returns "" on success, otherwise why nothing happened.
func execute(command: Command) -> String:
	var error := command.validate(self)
	if error.is_empty():
		command.apply(self)
	return error


func tick() -> void:
	world.hour += 1
	MovementSystem.run_hour(world)
	RouteSystem.run_hour(self)
	if world.hour % HOURS_PER_DAY == 0:
		ProductionSystem.run_day(data, world)
		WorkshopSystem.run_day(data, world)
		ConsumptionSystem.run_day(data, world)
		OffMapTradeSystem.run_day(data, world)
		PriceHistorySystem.run_day(data, world)


func advance_days(days: int) -> void:
	for i in days * HOURS_PER_DAY:
		tick()
