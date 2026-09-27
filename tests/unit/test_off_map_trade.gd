extends GutTest
## Off-map trade (OffMapTradeSystem): imports into short markets, exports from overstocked ones.

const SmallWorld := preload("res://tests/support/small_world.gd")


func _trading_simulation() -> Simulation:
	var sim := SmallWorld.simulation()
	sim.data.economy.import_rate = 1.5
	sim.data.economy.export_rate = 1.0
	return sim


func test_empty_markets_import_from_off_map() -> void:
	var sim := _trading_simulation()
	SmallWorld.set_stock(sim, "town", "grain", 0)
	OffMapTradeSystem.run_day(sim.data, sim.world)
	# Demand 2/day x import rate 1.5 x (20 - 0) / 20 = 3 units.
	assert_eq(sim.world.get_city("town").stock["grain"], 3)
	assert_eq(EconomyInvariants.check(sim.data, sim.world), PackedStringArray())


func test_surplus_is_exported_off_map() -> void:
	var sim := _trading_simulation()
	SmallWorld.set_stock(sim, "port", "grain", 40)
	OffMapTradeSystem.run_day(sim.data, sim.world)
	# Demand 2/day x export rate 1.0 x (40 - 20) / 20 = 2 units.
	assert_eq(sim.world.get_city("port").stock["grain"], 38)
	assert_eq(EconomyInvariants.check(sim.data, sim.world), PackedStringArray())


func test_markets_at_target_do_not_trade() -> void:
	var sim := _trading_simulation()
	OffMapTradeSystem.run_day(sim.data, sim.world)
	assert_eq(sim.world.get_city("town").stock, {"grain": 20, "wine": 5})


func test_a_city_without_production_settles_at_a_third_of_target() -> void:
	# Consumption 2/day against imports 3 x (1 - stock/target): balance at stock = target / 3.
	var sim := _trading_simulation()
	sim.advance_days(120)
	var grain: int = sim.world.get_city("town").stock["grain"]
	# Measured after the day's imports, which add back roughly the 2 units consumed that day.
	assert_between(grain, 7, 10, "about 20 / 3 + 2, instead of running empty")
	assert_eq(EconomyInvariants.check(sim.data, sim.world), PackedStringArray())


func test_without_off_map_trade_the_town_runs_empty() -> void:
	var sim := SmallWorld.simulation()
	sim.advance_days(30)
	assert_eq(sim.world.get_city("town").stock["grain"], 0)


func test_expected_flow_matches_the_formula() -> void:
	var sim := _trading_simulation()
	var town := sim.world.get_city("town")
	var grain := sim.data.get_good("grain")
	# grain: demand 2/day, target 20. Imports 2 x 1.5 x 15/20, exports 2 x 1.0 x 10/20.
	for case: Array in [[5, 2.25], [20, 0.0], [30, -1.0]]:
		SmallWorld.set_stock(sim, "town", "grain", case[0])
		var flow := OffMapTradeSystem.expected_flow(sim.data.economy, town, grain)
		assert_almost_eq(flow, case[1] as float, 1e-9, "stock %d" % case[0])
