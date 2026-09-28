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
	var versions := [
		SaveGame.SAVE_VERSION + 1, SaveGame.OLDEST_SUPPORTED_VERSION, SaveGame.SAVE_VERSION
	]
	assert_eq(
		Array(loader.errors), ["save version %d is not supported (expected %d to %d)" % versions]
	)


func test_saves_that_do_not_fit_the_game_data_are_rejected() -> void:
	var sim := _played_simulation()
	var save := _through_json(SaveGame.to_dict(sim.world))
	save["traders"][0]["ships"][0]["type"] = "galleon"
	save["traders"][0]["kontors"][0]["cargo"]["amber"] = 3
	save["cities"][0]["population"] = -500
	save["cities"][1]["id"] = "riga"
	var loader := SaveGame.new()
	assert_null(loader.from_dict(sim.data, save))
	assert_eq(
		Array(loader.errors),
		[
			"cities[0]: population -500 outside 500 to 2000",
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
	copy["captains"] = []
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
	save["traders"][0]["kontors"].append(
		{"city": "riga", "cargo": {}, "spoil_carry": {}, "workshops": []}
	)
	var loader := SaveGame.new()
	assert_null(loader.from_dict(sim.data, save))
	assert_eq(Array(loader.errors), ["traders[0] kontors[1]: unknown city 'riga'"])


func test_version_1_saves_load_with_an_empty_price_history() -> void:
	var sim := _played_simulation()
	var save := _through_json(SaveGame.to_dict(sim.world))
	save["save_version"] = 1
	for city: Dictionary in save["cities"]:
		city.erase("price_history")
	var world := _load(sim, save)
	for city in world.cities:
		for good in sim.data.goods:
			assert_eq(city.price_history[good.id].size(), 0)
	var loaded := Simulation.new(sim.data, world)
	loaded.advance_days(1)
	assert_eq(loaded.world.get_city("town").price_history["grain"].size(), 1)


func test_price_history_round_trips() -> void:
	var sim := _played_simulation()
	var world := _load(sim, _through_json(SaveGame.to_dict(sim.world)))
	var history: PackedInt64Array = world.get_city("town").price_history["wine"]
	assert_eq(history.size(), 2)
	assert_eq(Array(history), Array(sim.world.get_city("town").price_history["wine"]))


func test_bad_price_histories_are_rejected() -> void:
	var sim := _played_simulation()
	var save := _through_json(SaveGame.to_dict(sim.world))
	var history: Dictionary = save["cities"][0]["price_history"]
	var too_long: Array = []
	too_long.resize(PriceHistorySystem.HISTORY_DAYS + 1)
	too_long.fill(4000)
	history["grain"] = too_long
	history["wine"] = [22000, -5, 1.5]
	history["amber"] = []
	var loader := SaveGame.new()
	assert_null(loader.from_dict(sim.data, save))
	assert_eq(
		Array(loader.errors),
		[
			"cities[0] price_history: unknown good 'amber'",
			"cities[0] price_history grain: 31 days, at most 30",
			"cities[0] price_history wine[1]: price -5 is negative",
			"cities[0] price_history wine[2]: 'price' must be a whole number",
		]
	)


func test_price_history_from_an_older_balance_is_clamped() -> void:
	var sim := _played_simulation()
	var save := _through_json(SaveGame.to_dict(sim.world))
	var wine := sim.data.get_good("wine")
	var lowest := PriceHistorySystem.min_scaled_price(sim.data.economy, wine)
	var highest := PriceHistorySystem.max_scaled_price(sim.data.economy, wine)
	save["cities"][0]["price_history"]["wine"] = [0, 22000, 99999999]
	var world := _load(sim, save)
	assert_eq(Array(world.get_city("port").price_history["wine"]), [lowest, 22000, highest])


func test_population_satisfaction_and_workshop_progress_round_trip() -> void:
	var sim := _played_simulation()
	var town := sim.world.get_city("town")
	town.population = 1234
	town.satisfaction = 654_321
	sim.world.player().get_kontor("port").workshops[0].progress = 250_000
	var world := _load(sim, _through_json(SaveGame.to_dict(sim.world)))
	assert_eq(world.get_city("town").population, 1234, "any population within the bounds")
	assert_eq(world.get_city("town").satisfaction, 654_321)
	assert_eq(world.player().get_kontor("port").workshops[0].progress, 250_000)


func test_version_4_saves_load_at_neutral_satisfaction() -> void:
	var sim := _played_simulation()
	var save := _through_json(SaveGame.to_dict(sim.world))
	save["save_version"] = 4
	for city: Dictionary in save["cities"]:
		city.erase("satisfaction")
	for workshop: Dictionary in save["traders"][0]["kontors"][0]["workshops"]:
		workshop.erase("progress")
	var world := _load(sim, save)
	for city in world.cities:
		assert_eq(city.satisfaction, 500_000)
		assert_eq(city.population, 1000)
	assert_eq(world.player().get_kontor("port").workshops[0].progress, 0)


func test_populations_and_satisfaction_out_of_range_are_rejected() -> void:
	var sim := _played_simulation()
	var save := _through_json(SaveGame.to_dict(sim.world))
	save["cities"][0]["population"] = 2001
	save["cities"][1]["satisfaction"] = -1
	save["traders"][0]["kontors"][0]["workshops"][0]["progress"] = 1_000_001
	var loader := SaveGame.new()
	assert_null(loader.from_dict(sim.data, save))
	assert_eq(
		Array(loader.errors),
		[
			"cities[0]: population 2001 outside 500 to 2000",
			"cities[1]: satisfaction -1 outside 0 to 1000000",
			"traders[0] kontors[0] workshops[0]: progress 1000001 outside 0 to 1000000",
		]
	)
