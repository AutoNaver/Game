extends GutTest
## The larger world of M11 (ADR 0012): river lanes to inland cities and cities' own off-map links.

const SmallWorld := preload("res://tests/support/small_world.gd")


func test_shipped_novgorod_is_reached_up_its_rivers() -> void:
	var data := GameDataLoader.new().load_dir(GameDataLoader.DEFAULT_DIR)
	var chart := data.sea_chart
	var rivers := chart.lane_segments().size() - chart.sea_segments().size()
	assert_eq(rivers, 7, "Neva, Ladoga's southern shore and the Volkhov")
	assert_false(chart.route("lubeck", "novgorod").is_empty())
	var ship := data.get_ship("cog")
	var to_reval := Navigation.travel_hours(data, ship, "lubeck", "reval")
	assert_gt(Navigation.travel_hours(data, ship, "lubeck", "novgorod"), to_reval)
	assert_eq(data.get_city("bergen").import_factor, 3.0)
	assert_eq(data.get_city("lubeck").import_factor, 1.0, "optional: 1 when missing")
	assert_eq([data.get_city("lubeck").since_save, data.get_city("novgorod").since_save], [1, 7])
	assert_eq([data.get_good("wine").since_save, data.get_good("furs").since_save], [1, 7])
	assert_eq(data.get_rival("brandes").since_save, 7)


func test_bad_import_factors_and_river_lanes_are_reported() -> void:
	var loader := GameDataLoader.new()
	assert_null(loader.load_dir("res://tests/fixtures/bad_city_imports"))
	var errors := Array(loader.errors)
	assert_has(
		errors, "cities.json[0]: 'import_factor' must be a number at least 0.0 and at most 10.0"
	)
	assert_has(errors, "sea_lanes.json rivers[0]: unknown node 'nowhere'")
	assert_has(errors, "rivals.json houses[0]: 'since_save' must be at most the save version 7")


func test_a_city_with_more_links_beyond_the_map_imports_more() -> void:
	var sim := SmallWorld.simulation()
	sim.data.economy.import_rate = 1.0
	SmallWorld.set_stock(sim, "town", "grain", 0)
	OffMapTradeSystem.run_day(sim.data, sim.world)
	var usual: int = sim.world.get_city("town").stock["grain"]
	SmallWorld.set_stock(sim, "town", "grain", 0)
	sim.data.get_city("town").import_factor = 2.0
	OffMapTradeSystem.run_day(sim.data, sim.world)
	assert_eq(usual, 2, "demand 2 a day at an empty market")
	assert_eq(sim.world.get_city("town").stock["grain"], 4)
	var expected := OffMapTradeSystem.expected_flow(
		sim.data.economy, sim.world.get_city("town"), sim.data.get_good("grain"), 2.0
	)
	assert_almost_eq(expected, 3.2, 0.001, "at the new stock of 4 of 20: 2 × 2 × 16 / 20")
	assert_eq(Array(EconomyInvariants.check(sim.data, sim.world)), [])
