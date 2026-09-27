extends GutTest

const SmallWorld := preload("res://tests/support/small_world.gd")


# The full-year run is tools/soak.gd (part of scripts/check.sh); this is the fast version.
func test_shipped_data_holds_invariants_for_120_days() -> void:
	var loader := GameDataLoader.new()
	var data := loader.load_dir(GameDataLoader.DEFAULT_DIR)
	assert_not_null(data)
	var sim := Simulation.new_game(data, 1)
	for day in 120:
		sim.advance_days(1)
		var violations := EconomyInvariants.check(data, sim.world)
		if not violations.is_empty():
			fail_test("day %d: %s" % [sim.day(), "\n".join(violations)])
			return
	pass_test("120 days without violations")


func test_same_seed_gives_identical_worlds() -> void:
	var first := SmallWorld.simulation(7)
	var second := SmallWorld.simulation(7)
	first.advance_days(50)
	second.advance_days(50)
	assert_eq(_fingerprint(first), _fingerprint(second))


func test_invariant_check_reports_violations() -> void:
	var sim := SmallWorld.simulation()
	var port := sim.world.get_city("port")
	port.stock["grain"] = -3
	port.consumption_carry["wine"] = 1500
	var violations := EconomyInvariants.check(sim.data, sim.world)
	assert_eq(violations.size(), 2)
	assert_string_contains(violations[0], "port/grain: negative stock -3")
	assert_string_contains(violations[1], "port/wine: carry 1500 outside [0, 1000)")


func _fingerprint(sim: Simulation) -> Array:
	var cities: Array = [sim.world.hour, sim.world.rng.state]
	for city in sim.world.cities:
		cities.append(
			[city.id, city.stock, city.production_carry, city.consumption_carry, city.shortage]
		)
	return cities
