extends GutTest
## PriceHistorySystem: one closing mid price per city and good per day, the last 30 days kept.

const SmallWorld := preload("res://tests/support/small_world.gd")


func _closing_price(sim: Simulation, city_id: String, good_id: String) -> int:
	var city := sim.world.get_city(city_id)
	var price := CityEconomy.mid_price(sim.data.economy, city, sim.data.get_good(good_id))
	return PriceHistorySystem.scaled_price(price)


func test_a_new_game_has_no_history() -> void:
	var sim := SmallWorld.simulation(1)
	for city in sim.world.cities:
		for good in sim.data.goods:
			assert_eq(city.price_history[good.id].size(), 0)


func test_each_day_records_the_closing_mid_price() -> void:
	var sim := SmallWorld.simulation(1)
	sim.advance_days(1)
	var first := _closing_price(sim, "town", "grain")
	sim.advance_days(1)
	var history: PackedInt64Array = sim.world.get_city("town").price_history["grain"]
	assert_eq(Array(history), [first, _closing_price(sim, "town", "grain")])
	# The town produces no grain, so its price rises while stock drains toward equilibrium.
	assert_gt(history[1], history[0])


func test_nothing_is_recorded_before_the_day_ends() -> void:
	var sim := SmallWorld.simulation(1)
	for i in Simulation.HOURS_PER_DAY - 1:
		sim.tick()
	assert_eq(sim.world.get_city("port").price_history["wine"].size(), 0)
	sim.tick()
	assert_eq(sim.world.get_city("port").price_history["wine"].size(), 1)


func test_only_the_last_days_are_kept() -> void:
	var sim := SmallWorld.simulation(1)
	sim.advance_days(PriceHistorySystem.HISTORY_DAYS)
	var full: PackedInt64Array = sim.world.get_city("town").price_history["grain"].duplicate()
	sim.advance_days(5)
	var history: PackedInt64Array = sim.world.get_city("town").price_history["grain"]
	assert_eq(history.size(), PriceHistorySystem.HISTORY_DAYS)
	assert_eq(Array(history.slice(0, -5)), Array(full.slice(5)))
	assert_eq(history[-1], _closing_price(sim, "town", "grain"))


func test_recorded_prices_stay_within_the_clamped_range() -> void:
	var sim := SmallWorld.simulation(1)
	sim.advance_days(60)
	for city in sim.world.cities:
		for good in sim.data.goods:
			var lowest := PriceHistorySystem.min_scaled_price(sim.data.economy, good)
			var highest := PriceHistorySystem.max_scaled_price(sim.data.economy, good)
			for price in city.price_history[good.id]:
				assert_between(price, lowest, highest)
