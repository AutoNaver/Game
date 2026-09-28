class_name Simulation
extends RefCounted
## Owns the world and advances it. One tick is one in-game hour: ships move every tick, then ships
## on trade routes act at their stops (RouteSystem), then the rival houses' docked ships trade and
## sail (RivalSystem); both act through commands. The daily systems run whenever a tick completes
## a day, in a fixed order: world events (EventSystem), spoilage of stored goods, city
## production, traders' workshops and the reputation they earn, wages, consumption, city
## satisfaction and population, off-map trade, price history, the rivals' kontors and expansion,
## the kontor factors' standing orders, then the houses' ranks. Actions enter only through
## execute().
##
## Current prices are not stored: they are derived from stock on demand (see Pricing,
## CityEconomy). Only the daily closing prices are kept, for the UI (PriceHistorySystem).

const HOURS_PER_DAY: int = 24

var data: GameData
var world: WorldState


func _init(p_data: GameData, p_world: WorldState) -> void:
	data = p_data
	world = p_world


## Starts a new game: every city has its home population at neutral satisfaction and holds its
## target stock of every good, so prices start at base, and the player starts as described in
## data/scenario.json.
static func new_game(p_data: GameData, seed_value: int) -> Simulation:
	var world := WorldState.new()
	world.rng.seed = seed_value
	for good in p_data.goods:
		world.goods_ledger[good.id] = 0
	for city_def in p_data.cities:
		add_city(p_data, world, city_def)
	var scenario := p_data.scenario
	var player := TraderState.new(WorldState.PLAYER_ID, "Player", scenario.coins)
	world.traders.append(player)
	for ship in scenario.ships:
		world.add_ship(player, ship.type_id, ship.name, scenario.start_city)
	for rival in p_data.rivals:
		add_rival(world, rival)
	player.person_ship_id = player.ships[0].id if not player.ships.is_empty() else ""
	player.person_city_id = scenario.start_city if player.ships.is_empty() else ""
	CaptainSystem.crew_starting_ships(p_data, world)
	MarketKnowledgeSystem.initialize(p_data, world)
	RankSystem.run_day(p_data, world)
	return Simulation.new(p_data, world)


## Adds a city to the world as it starts a new game: home population, neutral satisfaction and the
## target stock of every good, booked in the goods ledger.
static func add_city(p_data: GameData, world: WorldState, city_def: CityDef) -> CityState:
	var city := CityState.new(city_def.id, city_def.population)
	city.satisfaction = CityEconomy.to_parts(p_data.population.neutral_satisfaction)
	for good in p_data.goods:
		stock_new_good(p_data, world, city, good)
	world.add_city(city)
	return city


## Gives `city` its starting market for `good` as a new game does: the target stock (booked in the
## goods ledger), no carries, no shortage and no price history.
static func stock_new_good(
	p_data: GameData, world: WorldState, city: CityState, good: GoodDef
) -> void:
	city.stock[good.id] = CityEconomy.target_stock(p_data.economy, city, good)
	world.goods_ledger[good.id] = world.goods_ledger.get(good.id, 0) + city.stock[good.id]
	city.production_carry[good.id] = 0
	city.consumption_carry[good.id] = 0
	city.trade_carry[good.id] = 0
	city.shortage[good.id] = 0
	city.price_history[good.id] = PackedInt64Array()


## Adds a rival house to the world as it starts: its coins and ships, docked in its start city.
static func add_rival(world: WorldState, rival: RivalDef) -> TraderState:
	var trader := TraderState.new(rival.id, rival.name, rival.coins)
	world.traders.append(trader)
	for ship in rival.ships:
		world.add_ship(trader, ship.type_id, ship.name, rival.start_city)
	return trader


## Whole days elapsed since the start.
func day() -> int:
	@warning_ignore("integer_division")
	return world.hour / HOURS_PER_DAY


## Validates and applies a command. Returns "" on success, otherwise why nothing happened.
func execute(command: Command) -> String:
	var error := command.validate(self)
	if error.is_empty():
		command.apply(self)
		MarketKnowledgeSystem.observe_presence(data, world)
	return error


func tick() -> void:
	world.hour += 1
	var arrivals := MovementSystem.run_hour(data, world)
	MarketKnowledgeSystem.on_arrivals(data, world, arrivals)
	RouteSystem.run_hour(self)
	RivalSystem.run_hour(self)
	if world.hour % HOURS_PER_DAY == 0:
		world.losses.clear()
		EventSystem.run_day(data, world, day())
		SpoilageSystem.run_day(data, world)
		ProductionSystem.run_day(data, world)
		WorkshopSystem.run_day(data, world)
		ReputationSystem.run_day(data, world)
		CaptainSystem.run_day(data, world, day())
		ConsumptionSystem.run_day(data, world)
		PopulationSystem.run_day(data, world)
		OffMapTradeSystem.run_day(data, world)
		PriceHistorySystem.run_day(data, world)
		RivalSystem.run_day(self)
		FactorSystem.run_day(self)
		RankSystem.run_day(data, world)
		MarketKnowledgeSystem.record_day(data, world)


func advance_days(days: int) -> void:
	for i in days * HOURS_PER_DAY:
		tick()
