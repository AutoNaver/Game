extends GutTest
## Saves from before the larger world (version 6 and older, ADR 0012) load into a game with more
## cities, goods and rival houses: what they lack is added as a new game starts it.

const SmallWorld := preload("res://tests/support/small_world.gd")
const PLAYER := WorldState.PLAYER_ID


## SmallWorld plus a third city ("cove"), a third good ("honey") and a rival house.
func _grown_data() -> GameData:
	var data := SmallWorld.with_rival(SmallWorld.data())
	data.add_good(GoodDef.new("honey", "Honey", "raw", 80, 1.0))
	var none: Dictionary[String, float] = {}
	data.add_city(CityDef.new("cove", "Cove", Vector2(0, 100), 2000, none))
	data.sea_chart.add_node("cove", Vector2(0, 100))
	data.sea_chart.add_lane("port", "cove")
	return data


## A version 6 save of the small world: two cities, two goods, no rivals, some play behind it.
func _old_save() -> Dictionary:
	var sim := SmallWorld.simulation(3)
	sim.world.player().coins = 5000
	assert_eq(sim.execute(BuyKontorCommand.new(PLAYER, "port")), "")
	assert_eq(sim.execute(BuyCommand.for_kontor(PLAYER, "port", "grain", 8)), "")
	sim.advance_days(3)
	var save := JSON.parse_string(JSON.stringify(SaveGame.to_dict(sim.world))) as Dictionary
	save["save_version"] = 6
	return save


func test_old_saves_get_the_new_goods_cities_and_houses() -> void:
	var data := _grown_data()
	var save := _old_save()
	var loader := SaveGame.new()
	var world := loader.from_dict(data, save)
	assert_eq(Array(loader.errors), [])
	assert_eq(world.cities.size(), 3)
	var cove := world.get_city("cove")
	assert_eq(cove.population, 2000)
	assert_eq(
		cove.stock["grain"], CityEconomy.target_stock(data.economy, cove, data.get_good("grain"))
	)
	var port := world.get_city("port")
	assert_eq(port.stock["honey"], 10, "1.0 per 1000 of 1000 people for 10 days of cover")
	assert_eq(port.price_history["honey"].size(), 0)
	assert_eq(port.stock["grain"], int(save["cities"][0]["stock"]["grain"]), "kept as saved")
	assert_eq(world.goods_ledger["honey"], 10 + 10 + 20)
	assert_not_null(world.get_trader(SmallWorld.RIVAL_ID), "the new house joins")
	assert_eq(world.player().get_kontor("port").cargo_of("grain"), 8)
	assert_eq(Array(EconomyInvariants.check(data, world)), [])
	var sim := Simulation.new(data, world)
	sim.advance_days(5)
	assert_eq(Array(EconomyInvariants.check(data, sim.world)), [])


func test_current_saves_must_cover_the_whole_world() -> void:
	var data := _grown_data()
	var save := _old_save()
	save["save_version"] = SaveGame.SAVE_VERSION
	var loader := SaveGame.new()
	assert_null(loader.from_dict(data, save))
	assert_eq(loader.errors[0], "goods_ledger: missing honey")
	assert_true(loader.errors.has("save has 2 cities, the game has 3"))


func test_old_saves_with_more_cities_than_the_game_are_rejected() -> void:
	var save := _old_save()
	save["cities"].append(save["cities"][1].duplicate(true))
	var loader := SaveGame.new()
	assert_null(loader.from_dict(SmallWorld.data(), save))
	assert_eq(Array(loader.errors), ["save has 3 cities, the game has 2"])
