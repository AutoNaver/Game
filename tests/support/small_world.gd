extends RefCounted
## A tiny hand-built data set for system tests, so tests don't break when data/*.json is rebalanced.
##
## Cities (population 1000 each):
## - "port" at (0, 0): produces grain 1.5/day
## - "town" at (100, 0): produces nothing
## Goods:
## - grain: consumed 2.0/day, target stock 20, cap 40
## - wine: consumed 0.5/day, target stock 5, cap 10
## A direct sea lane joins them. Ship type "boat": capacity 10, speed 10 (10 hours per trip).
## The player starts in port with 1000 coins and one boat, ship_1 "Test".
## Kontors cost 300 and hold 20 units. Workshop type "vintner": 4 grain -> 2 wine a day, 30 workers
## (a city's workforce is 10% of 1000 = 100), costs 200 to build, 10 a day in wages.
## Populations stay put (growth_rate 0) unless a test sets PopulationDef.growth_rate: satisfaction
## remembers a tenth of each day, neutral at 0.5, sensitivity 1, bounds 0.5x to 2x of home.
## with_rival() adds rival house "hanse" (1000 coins, one boat "Rival") and the rival AI rules.
## Deals: assets at 1.5x their value, buy-outs at 1.5x worth for a buyer worth 2x, bankruptcy sales
## at half value for 5 days, offers stand 3 days and rivals always make one when they can.
## Every house holds the one rank "open", which limits nothing and unlocks everything, and
## reputation (max 100) never gates a kontor. with_ranks() swaps in a real ladder for rank tests.

const DAYS_OF_COVER: int = 10
const STOCK_CAP_FACTOR: float = 2.0
const START_COINS: int = 1000
const SHIP_ID: String = "ship_1"
const KONTOR_PRICE: int = 300
const KONTOR_CAPACITY: int = 20
const RIVAL_ID: String = "hanse"
const RIVAL_COINS: int = 1000
## Rival AI rules for tests: choose among the best 2 loads, keep 100 coins back, at most 2 ships
## and 1 kontor, expand every 5 days, stock 3 days of inputs, pay up to 1.5x base for them, and
## keep no share of the workforce free for others.
const RIVAL_EXPANSION_DAYS: int = 5
const RIVAL_RESERVE: int = 100
const RIVAL_INPUT_DAYS: int = 3


static func data() -> GameData:
	var game_data := GameData.new()
	game_data.economy = EconomyDef.new(DAYS_OF_COVER, STOCK_CAP_FACTOR, 2.5, 0.35, 0.1)
	game_data.captains = CaptainDef.new(2, 2, 10, 2, 10, 5, 14)
	game_data.population = PopulationDef.new(0.1, 0.5, 1.0, 0.0, 0.5, 2.0)
	game_data.add_good(GoodDef.new("grain", "Grain", "raw", 40, 2.0))
	game_data.add_good(GoodDef.new("wine", "Wine", "luxury", 220, 0.5))
	var production: Dictionary[String, float] = {"grain": 1.5}
	game_data.add_city(CityDef.new("port", "Port", Vector2.ZERO, 1000, production))
	var no_production: Dictionary[String, float] = {}
	game_data.add_city(CityDef.new("town", "Town", Vector2(100, 0), 1000, no_production))
	game_data.sea_chart = SeaChart.new()
	for city in game_data.cities:
		game_data.sea_chart.add_node(city.id, city.map_position)
	game_data.sea_chart.add_lane("port", "town")
	game_data.add_ship(ShipDef.new("boat", "Boat", 10, 10.0, 500))
	var ships: Array[ScenarioDef.StartingShip] = [ScenarioDef.StartingShip.new("boat", "Test")]
	game_data.scenario = ScenarioDef.new("port", START_COINS, ships)
	game_data.kontor = KontorDef.new(KONTOR_PRICE, KONTOR_CAPACITY)
	var inputs: Dictionary[String, int] = {"grain": 4}
	game_data.add_workshop(WorkshopDef.new("vintner", "Vintner", "wine", 2, inputs, 30, 200, 10))
	game_data.reputation = ReputationDef.new(100, 20, 0, 1, 1, 1, 2)
	game_data.acquisitions = AcquisitionDef.new(1.5, 1.5, 2.0, 0.5, 5, 3, 1.0)
	game_data.ranks.append(RankDef.new("open", "Open", 0, 0, false, 0, 0, RankDef.UNLOCKS))
	return game_data


## Replaces the ranks with a small ladder: "skipper" (1 ship, 1 kontor), "merchant" (worth 2000:
## routes, 2 kontors, and the "barge" ship type) and "house" (worth 5000 and standing 20 in both
## cities: factors, no limits). A kontor abroad needs reputation 10; a barge is a boat that needs
## the rank merchant.
static func with_ranks(game_data: GameData) -> GameData:
	game_data.reputation = ReputationDef.new(100, 20, 10, 1, 1, 1, 2)
	game_data.ranks.clear()
	game_data.ranks.append(RankDef.new("skipper", "Skipper", 0, 0, false, 1, 1, []))
	var merchant := RankDef.new("merchant", "Merchant", 2000, 0, false, 0, 2, [RankDef.ROUTES])
	game_data.ranks.append(merchant)
	var house := RankDef.new("house", "House", 5000, 2, false, 0, 0, [RankDef.FACTORS])
	game_data.ranks.append(house)
	var barge := ShipDef.new("barge", "Barge", 10, 10.0, 500)
	barge.rank_id = "merchant"
	game_data.add_ship(barge)
	return game_data


static func simulation(seed_value: int = 1) -> Simulation:
	return Simulation.new_game(data(), seed_value)


## Adds a rival house to `game_data`, starting in `start_city`, and the AI rules if missing.
static func with_rival(
	game_data: GameData, start_city: String = "port", id: String = RIVAL_ID
) -> GameData:
	if game_data.rival_ai == null:
		game_data.rival_ai = RivalAiDef.new(
			2, RIVAL_RESERVE, 2, 1, RIVAL_EXPANSION_DAYS, RIVAL_INPUT_DAYS, 1.5, 0.0
		)
	var ships: Array[ScenarioDef.StartingShip] = [ScenarioDef.StartingShip.new("boat", "Rival")]
	game_data.add_rival(
		RivalDef.new(id, id.capitalize(), Color.STEEL_BLUE, start_city, RIVAL_COINS, ships)
	)
	return game_data


static func rival_simulation(seed_value: int = 1, start_city: String = "port") -> Simulation:
	return Simulation.new_game(with_rival(data(), start_city), seed_value)


## Test setup: sets a city's stock and books the difference in the goods ledger, as if it had
## been produced or consumed, so conservation checks still hold afterwards.
static func set_stock(sim: Simulation, city_id: String, good_id: String, units: int) -> void:
	var city := sim.world.get_city(city_id)
	sim.world.goods_ledger[good_id] += units - city.stock[good_id]
	city.stock[good_id] = units


## Test setup: puts goods aboard a ship and books them in the goods ledger.
static func give_cargo(sim: Simulation, ship: ShipState, good_id: String, units: int) -> void:
	ship.change_cargo(good_id, units)
	sim.world.goods_ledger[good_id] += units
