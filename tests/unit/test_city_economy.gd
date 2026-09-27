extends GutTest

const SmallWorld := preload("res://tests/support/small_world.gd")


func test_new_game_starts_every_city_at_target_stock() -> void:
	var sim := SmallWorld.simulation(42)
	var port := sim.world.get_city("port")
	assert_eq(sim.world.hour, 0)
	assert_eq(sim.world.rng.seed, 42)
	assert_eq(port.stock, {"grain": 20, "wine": 5})
	assert_eq(port.shortage, {"grain": 0, "wine": 0})


func test_target_and_cap_scale_with_population() -> void:
	var data := SmallWorld.data()
	var grain := data.get_good("grain")
	var city := CityState.new("port", 3000)
	assert_almost_eq(CityEconomy.daily_demand(city, grain), 6.0, 0.0001)
	assert_eq(CityEconomy.target_stock(data.economy, city, grain), 60)
	assert_eq(CityEconomy.stock_cap(data.economy, city, grain), 120)


func test_target_stock_is_at_least_one() -> void:
	var data := SmallWorld.data()
	var unused := GoodDef.new("amber", "Amber", "luxury", 300, 0.0)
	assert_eq(CityEconomy.target_stock(data.economy, CityState.new("port", 1000), unused), 1)


func test_production_accumulates_fractions_across_days() -> void:
	var sim := SmallWorld.simulation()
	var port := sim.world.get_city("port")
	ProductionSystem.run_day(sim.data, sim.world)
	assert_eq(port.stock["grain"], 21, "1.5/day yields 1 unit on day one")
	ProductionSystem.run_day(sim.data, sim.world)
	assert_eq(port.stock["grain"], 23, "and 2 units on day two")
	assert_eq(port.stock["wine"], 5, "goods the city does not make are untouched")


func test_production_stops_at_stock_cap() -> void:
	var sim := SmallWorld.simulation()
	var port := sim.world.get_city("port")
	port.stock["grain"] = 39
	ProductionSystem.run_day(sim.data, sim.world)
	ProductionSystem.run_day(sim.data, sim.world)
	assert_eq(port.stock["grain"], 40)


func test_consumption_accumulates_fractions_across_days() -> void:
	var sim := SmallWorld.simulation()
	var port := sim.world.get_city("port")
	ConsumptionSystem.run_day(sim.data, sim.world)
	assert_eq(port.stock["grain"], 18)
	assert_eq(port.stock["wine"], 5, "0.5/day consumes nothing on day one")
	ConsumptionSystem.run_day(sim.data, sim.world)
	assert_eq(port.stock["wine"], 4, "and one unit on day two")


func test_consumption_never_goes_negative_and_records_shortage() -> void:
	var sim := SmallWorld.simulation()
	var port := sim.world.get_city("port")
	port.stock["grain"] = 1
	ConsumptionSystem.run_day(sim.data, sim.world)
	assert_eq(port.stock["grain"], 0)
	assert_eq(port.shortage["grain"], 1)
	ConsumptionSystem.run_day(sim.data, sim.world)
	assert_eq(port.stock["grain"], 0)
	assert_eq(port.shortage["grain"], 2, "shortage is per day, not cumulative")
	port.stock["grain"] = 10
	ConsumptionSystem.run_day(sim.data, sim.world)
	assert_eq(port.shortage["grain"], 0)


func test_daily_systems_run_only_when_a_day_completes() -> void:
	var sim := SmallWorld.simulation()
	var port := sim.world.get_city("port")
	for i in Simulation.HOURS_PER_DAY - 1:
		sim.tick()
	assert_eq(sim.day(), 0)
	assert_eq(port.stock["grain"], 20)
	sim.tick()
	assert_eq(sim.day(), 1)
	assert_eq(port.stock["grain"], 19, "+1 produced, -2 consumed")


func test_advance_days_nets_production_against_consumption() -> void:
	var sim := SmallWorld.simulation()
	sim.advance_days(10)
	assert_eq(sim.world.hour, 10 * Simulation.HOURS_PER_DAY)
	# Grain: +1.5 -2.0 per day; wine: -0.5 per day.
	assert_eq(sim.world.get_city("port").stock, {"grain": 15, "wine": 0})
