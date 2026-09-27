extends GutTest
## Rival houses in save files (save version 4): exact round trips, migration of older saves, and
## rejection of traders the game doesn't know.

const SmallWorld := preload("res://tests/support/small_world.gd")
const RIVAL := SmallWorld.RIVAL_ID


func _through_json(save: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(save)) as Dictionary


func _played() -> Simulation:
	var sim := SmallWorld.rival_simulation(4)
	sim.world.get_trader(RIVAL).coins = 3000
	sim.advance_days(12)
	return sim


func test_rivals_round_trip_and_play_on_identically() -> void:
	var sim := _played()
	var save := _through_json(SaveGame.to_dict(sim.world))
	var loader := SaveGame.new()
	var world := loader.from_dict(sim.data, save)
	assert_eq(Array(loader.errors), [])
	assert_eq(_through_json(SaveGame.to_dict(world)), save)
	var loaded := Simulation.new(sim.data, world)
	sim.advance_days(10)
	loaded.advance_days(10)
	assert_eq(SaveGame.to_dict(loaded.world), SaveGame.to_dict(sim.world))


func test_version_3_saves_get_the_rivals_as_they_start() -> void:
	var sim := SmallWorld.rival_simulation(4)
	sim.world.traders.remove_at(1)
	sim.advance_days(2)
	var save := _through_json(SaveGame.to_dict(sim.world))
	save["save_version"] = 3
	var loader := SaveGame.new()
	var world := loader.from_dict(sim.data, save)
	assert_eq(Array(loader.errors), [])
	var rival := world.get_trader(RIVAL)
	assert_not_null(rival)
	assert_eq(rival.coins, SmallWorld.RIVAL_COINS)
	assert_eq(rival.ships.size(), 1)
	assert_eq(rival.ships[0].docked_at, "port")
	assert_eq(rival.ships[0].id, "ship_3", "numbered after the ships the save already has")
	assert_eq(world.next_ship_number, 4)


func test_version_4_saves_keep_the_rivals_they_have() -> void:
	var sim := SmallWorld.rival_simulation(4)
	sim.world.traders.remove_at(1)
	var loader := SaveGame.new()
	var world := loader.from_dict(sim.data, _through_json(SaveGame.to_dict(sim.world)))
	assert_eq(Array(loader.errors), [])
	assert_null(world.get_trader(RIVAL), "a house missing from a current save is not revived")


func test_unknown_traders_are_rejected() -> void:
	var sim := _played()
	var save := _through_json(SaveGame.to_dict(sim.world))
	save["traders"][1]["id"] = "hansa_bank"
	var loader := SaveGame.new()
	assert_null(loader.from_dict(sim.data, save))
	assert_eq(
		Array(loader.errors), ["unknown trader 'hansa_bank' (neither the player nor a rival house)"]
	)


func test_net_worth_counts_coins_ships_buildings_and_goods() -> void:
	var sim := SmallWorld.rival_simulation()
	var rival := sim.world.get_trader(RIVAL)
	var boat_resale := SellShipCommand.resale_price(sim.data, sim.data.get_ship("boat"))
	assert_eq(HouseValue.net_worth(sim.data, rival), SmallWorld.RIVAL_COINS + boat_resale)
	rival.coins = 2000
	assert_eq(sim.execute(BuyKontorCommand.new(RIVAL, "port")), "")
	assert_eq(sim.execute(BuildWorkshopCommand.new(RIVAL, "port", "vintner")), "")
	SmallWorld.give_cargo(sim, rival.ships[0], "wine", 2)
	var expected := 2000 + boat_resale + 2 * 220
	assert_eq(HouseValue.net_worth(sim.data, rival), expected, "buildings count at their cost")
