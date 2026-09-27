extends GutTest
## Rival ships sometimes sail to the city their house knows least recently (RivalAiDef
## explore_chance), so a house that stopped visiting a city learns again when it pays.


func test_the_stalest_city_is_unknown_first_then_oldest_in_data_order() -> void:
	var data := GameDataLoader.new().load_dir(GameDataLoader.DEFAULT_DIR)
	var trader := TraderState.new("castorp", "Castorp", 0)
	for city in data.cities:
		trader.market_book[city.id] = MarketRecord.new(city.id, 10)
	assert_eq(RivalSystem.stalest_city(trader, data, "lubeck"), "danzig", "all equal: data order")
	trader.market_book["reval"].day = 3
	assert_eq(RivalSystem.stalest_city(trader, data, "lubeck"), "reval")
	trader.market_book.erase("bergen")
	assert_eq(RivalSystem.stalest_city(trader, data, "lubeck"), "bergen", "unknown beats old")
	assert_eq(RivalSystem.stalest_city(trader, data, "bergen"), "reval", "never its own port")


func test_shipped_rivals_explore_now_and_then() -> void:
	var data := GameDataLoader.new().load_dir(GameDataLoader.DEFAULT_DIR)
	assert_almost_eq(data.rival_ai.explore_chance, 0.15, 0.0001)
	var sim := Simulation.new_game(data, 1)
	sim.advance_days(120)
	for rival in data.rivals:
		var known := sim.world.get_trader(rival.id).market_book.size()
		assert_gt(known, 3, "%s has heard of more than its own corner" % rival.name)
	assert_eq(EconomyInvariants.check(data, sim.world), PackedStringArray())
