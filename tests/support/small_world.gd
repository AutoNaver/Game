extends RefCounted
## A tiny hand-built data set for system tests, so tests don't break when data/*.json is rebalanced.
##
## One city "port" (population 1000) and two goods:
## - grain: consumed 2.0/day, produced 1.5/day, target stock 20, cap 40
## - wine: consumed 0.5/day, not produced, target stock 5, cap 10

const DAYS_OF_COVER: int = 10
const STOCK_CAP_FACTOR: float = 2.0


static func data() -> GameData:
	var game_data := GameData.new()
	game_data.economy = EconomyDef.new(DAYS_OF_COVER, STOCK_CAP_FACTOR, 2.5, 0.35, 0.1)
	game_data.add_good(GoodDef.new("grain", "Grain", "raw", 40, 2.0))
	game_data.add_good(GoodDef.new("wine", "Wine", "luxury", 220, 0.5))
	var production: Dictionary[String, float] = {"grain": 1.5}
	game_data.add_city(CityDef.new("port", "Port", Vector2.ZERO, 1000, production))
	return game_data


static func simulation(seed_value: int = 1) -> Simulation:
	return Simulation.new_game(data(), seed_value)
