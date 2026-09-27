extends GutTest
## Saving and loading: exact round trips through JSON, determinism after loading, and rejection of
## damaged or mismatched saves.

const SmallWorld := preload("res://tests/support/small_world.gd")
const PLAYER := WorldState.PLAYER_ID


## A world with voyages, cargo, a kontor, a workshop and a sold ship behind it.
func _played_simulation() -> Simulation:
	var sim := SmallWorld.simulation(99)
	sim.world.player().coins = 5000
	for command: Command in [
		BuyCommand.new(PLAYER, SmallWorld.SHIP_ID, "grain", 5),
		BuyKontorCommand.new(PLAYER, "port"),
		BuyCommand.for_kontor(PLAYER, "port", "grain", 8),
		BuildWorkshopCommand.new(PLAYER, "port", "vintner"),
		BuyShipCommand.new(PLAYER, "port", "boat"),
		BuyShipCommand.new(PLAYER, "port", "boat"),
		SellShipCommand.new(PLAYER, "ship_2"),
		SailCommand.new(PLAYER, SmallWorld.SHIP_ID, "town"),
	]:
		assert_eq(sim.execute(command), "")
	sim.advance_days(2)
	sim.tick()
	return sim


## JSON round trip, as a save file does it.
func _through_json(save: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(save)) as Dictionary


func _load(sim: Simulation, save: Dictionary) -> WorldState:
	var loader := SaveGame.new()
	var world := loader.from_dict(sim.data, save)
	assert_eq(Array(loader.errors), [])
	return world


func test_round_trip_restores_the_same_world() -> void:
	var sim := _played_simulation()
	var saved := SaveGame.to_dict(sim.world)
	var world := _load(sim, _through_json(saved))
	assert_not_null(world)
	if world == null:
		return
	assert_eq(_through_json(SaveGame.to_dict(world)), _through_json(saved))
	assert_eq(world.player().get_kontor("port").workshops[0].status, WorkshopState.Status.WORKED)


func test_a_loaded_game_continues_exactly_like_the_original() -> void:
	var sim := _played_simulation()
	var copy := Simulation.new(sim.data, _load(sim, _through_json(SaveGame.to_dict(sim.world))))
	var rng_before := sim.world.rng.randi()
	assert_eq(copy.world.rng.randi(), rng_before, "the RNG continues from the saved state")
	sim.advance_days(20)
	copy.advance_days(20)
	assert_eq(SaveGame.to_dict(copy.world), SaveGame.to_dict(sim.world))


func test_save_files_round_trip_on_disk() -> void:
	var sim := _played_simulation()
	var path := "user://test_saves/round_trip.json"
	assert_eq(SaveGame.save_file(sim.world, path), "")
	var loader := SaveGame.new()
	var world := loader.load_file(sim.data, path)
	assert_eq(Array(loader.errors), [])
	assert_eq(SaveGame.to_dict(world), SaveGame.to_dict(sim.world))
	DirAccess.remove_absolute(path)


func test_missing_and_broken_files_are_reported() -> void:
	var loader := SaveGame.new()
	var data := SmallWorld.data()
	assert_null(loader.load_file(data, "user://test_saves/none.json"))
	assert_string_starts_with(loader.errors[0], "no save at")
	var path := "user://test_saves/broken.json"
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{ not json")
	file.close()
	assert_null(loader.load_file(data, path))
	assert_string_starts_with(loader.errors[0], "save is not valid JSON")
	DirAccess.remove_absolute(path)


func test_other_versions_are_rejected() -> void:
	var sim := _played_simulation()
	var save := SaveGame.to_dict(sim.world)
	save["save_version"] = SaveGame.SAVE_VERSION + 1
	var loader := SaveGame.new()
	assert_null(loader.from_dict(sim.data, save))
	assert_eq(Array(loader.errors), ["save version 2 is not supported (expected 1)"])


func test_saves_that_do_not_fit_the_game_data_are_rejected() -> void:
	var sim := _played_simulation()
	var save := _through_json(SaveGame.to_dict(sim.world))
	save["traders"][0]["ships"][0]["type"] = "galleon"
	save["traders"][0]["kontors"][0]["cargo"]["amber"] = 3
	save["cities"][0]["population"] = -500
	save["cities"][1]["id"] = "riga"
	var population: int = sim.data.cities[0].population
	var loader := SaveGame.new()
	assert_null(loader.from_dict(sim.data, save))
	assert_eq(
		Array(loader.errors),
		[
			"cities[0]: population -500, the game has %d" % population,
			"cities[1]: expected city 'town', got 'riga'",
			"traders[0] ships[0]: unknown ship type 'galleon'",
			"traders[0] kontors[0] cargo: unknown good 'amber'",
		]
	)


func test_saves_that_break_invariants_are_rejected() -> void:
	var sim := _played_simulation()
	var save := _through_json(SaveGame.to_dict(sim.world))
	save["traders"][0]["coins"] = -50
	save["cities"][0]["stock"]["wine"] = 999
	var loader := SaveGame.new()
	assert_null(loader.from_dict(sim.data, save))
	assert_eq(loader.errors.size(), 2)
	assert_string_contains(loader.errors[0], "player: negative coins -50")
	assert_string_contains(loader.errors[1], "wine: ")


func test_duplicate_ids_are_rejected() -> void:
	var sim := _played_simulation()
	var save := _through_json(SaveGame.to_dict(sim.world))
	save["next_ship_number"] = 2
	var loader := SaveGame.new()
	assert_null(loader.from_dict(sim.data, save))
	assert_eq(Array(loader.errors), ["id 'ship_3' is not below the next free number 2"])


func test_duplicate_traders_are_rejected() -> void:
	var sim := _played_simulation()
	var save := _through_json(SaveGame.to_dict(sim.world))
	var copy: Dictionary = (save["traders"][0] as Dictionary).duplicate(true)
	copy["ships"] = []
	copy["kontors"] = []
	save["traders"].append(copy)
	var loader := SaveGame.new()
	assert_null(loader.from_dict(sim.data, save))
	assert_eq(Array(loader.errors), ["duplicate trader id 'player'"])


func test_workshop_status_and_missing_good_must_agree() -> void:
	var sim := _played_simulation()
	var save := _through_json(SaveGame.to_dict(sim.world))
	var workshop: Dictionary = save["traders"][0]["kontors"][0]["workshops"][0]
	workshop["status"] = "NO_INPUTS"
	workshop["missing_good"] = "grain"
	var world := _load(sim, save)
	assert_eq(world.player().get_kontor("port").workshops[0].missing_good, "grain")

	var errors: Array = []
	for pair: Array in [["NO_INPUTS", ""], ["NO_INPUTS", "amber"], ["WORKED", "grain"]]:
		workshop["status"] = pair[0]
		workshop["missing_good"] = pair[1]
		var loader := SaveGame.new()
		assert_null(loader.from_dict(sim.data, save))
		errors.append_array(Array(loader.errors))
	var ctx := "traders[0] kontors[0] workshops[0]"
	assert_eq(
		errors,
		[
			"%s: unknown missing good ''" % ctx,
			"%s: unknown missing good 'amber'" % ctx,
			"%s: missing_good is only allowed for NO_INPUTS" % ctx,
		]
	)


func test_kontors_in_unknown_cities_are_rejected() -> void:
	var sim := _played_simulation()
	var save := _through_json(SaveGame.to_dict(sim.world))
	save["traders"][0]["kontors"].append({"city": "riga", "cargo": {}, "workshops": []})
	var loader := SaveGame.new()
	assert_null(loader.from_dict(sim.data, save))
	assert_eq(Array(loader.errors), ["traders[0] kontors[1]: unknown city 'riga'"])
