extends RefCounted
## A tiny hand-built data set for system tests, so tests don't break when data/*.json is rebalanced.
##
## Cities (population 1000 each):
## - "port" at (0, 0): produces grain 1.5/day
## - "town" at (100, 0): produces nothing
## Goods:
## - grain: consumed 2.0/day, target stock 20, cap 40
## - wine: consumed 0.5/day, target stock 5, cap 10
## Ship type "boat": capacity 10, speed 10 (port <-> town takes 10 hours).
## The player starts in port with 1000 coins and one boat, ship_1 "Test".

const DAYS_OF_COVER: int = 10
const STOCK_CAP_FACTOR: float = 2.0
const START_COINS: int = 1000
const SHIP_ID: String = "ship_1"


static func data() -> GameData:
	var game_data := GameData.new()
	game_data.economy = EconomyDef.new(DAYS_OF_COVER, STOCK_CAP_FACTOR, 2.5, 0.35, 0.1)
	game_data.add_good(GoodDef.new("grain", "Grain", "raw", 40, 2.0))
	game_data.add_good(GoodDef.new("wine", "Wine", "luxury", 220, 0.5))
	var production: Dictionary[String, float] = {"grain": 1.5}
	game_data.add_city(CityDef.new("port", "Port", Vector2.ZERO, 1000, production))
	var no_production: Dictionary[String, float] = {}
	game_data.add_city(CityDef.new("town", "Town", Vector2(100, 0), 1000, no_production))
	game_data.add_ship(ShipDef.new("boat", "Boat", 10, 10.0, 500))
	var ships: Array[ScenarioDef.StartingShip] = [ScenarioDef.StartingShip.new("boat", "Test")]
	game_data.scenario = ScenarioDef.new("port", START_COINS, ships)
	return game_data


static func simulation(seed_value: int = 1) -> Simulation:
	return Simulation.new_game(data(), seed_value)
