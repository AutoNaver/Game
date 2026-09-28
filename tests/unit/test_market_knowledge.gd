extends GutTest
## Market books are per house, preserve stale reports, and travel as dated ship news.

const SmallWorld := preload("res://tests/support/small_world.gd")


func test_new_game_knows_only_places_with_presence() -> void:
	var sim := SmallWorld.simulation(1)
	var player := sim.world.player()
	assert_true(player.market_book.has("port"))
	assert_false(player.market_book.has("town"))
	assert_eq(player.market_book["port"].day, 0)
	assert_eq(player.ships[0].news.city_id, "port")
	assert_true(MarketKnowledgeSystem.has_presence(sim.data, player, "port"))


func test_a_departed_city_stays_stale_and_history_gets_a_gap() -> void:
	var sim := SmallWorld.simulation(1)
	var ship := sim.world.player().ships[0]
	assert_eq(sim.execute(SailCommand.new(WorldState.PLAYER_ID, ship.id, "town")), "")
	for i in ship.voyage_hours:
		sim.tick()
	assert_true(sim.world.player().market_book.has("town"))
	sim.advance_days(1)
	var record: MarketRecord = sim.world.player().market_book["town"]
	assert_gt(record.history["grain"][-1], 0)
	assert_eq(sim.execute(SailCommand.new(WorldState.PLAYER_ID, ship.id, "port")), "")
	for i in ship.voyage_hours:
		sim.tick()
	var old_stock := record.stock["grain"]
	var old_day := record.day
	SmallWorld.set_stock(sim, "town", "grain", 0)
	sim.advance_days(1)
	assert_eq(record.stock["grain"], old_stock)
	assert_eq(record.day, old_day)
	assert_eq(record.history["grain"][-1], -1)


func test_arriving_ship_shares_its_departure_report_not_newer_home_prices() -> void:
	var sim := SmallWorld.rival_simulation(1, "town")
	var ship := sim.world.player().ships[0]
	SmallWorld.set_stock(sim, "port", "grain", 40)
	# The player stays ashore at home and keeps seeing it while the ship sails.
	assert_eq(sim.execute(MovePersonCommand.new()), "")
	assert_eq(sim.execute(SailCommand.new(WorldState.PLAYER_ID, ship.id, "town")), "")
	SmallWorld.set_stock(sim, "port", "grain", 0)
	MarketKnowledgeSystem.observe_presence(sim.data, sim.world)
	for i in ship.voyage_hours:
		sim.world.hour += 1
		var arrivals := MovementSystem.run_hour(sim.data, sim.world)
		MarketKnowledgeSystem.on_arrivals(sim.data, sim.world, arrivals)
	var rival := sim.world.get_trader(SmallWorld.RIVAL_ID)
	assert_eq(rival.market_book["port"].stock["grain"], 40)
	assert_eq(sim.world.player().market_book["port"].stock["grain"], 0)


func test_the_player_in_person_sees_only_the_port_they_are_ashore_in() -> void:
	var sim := SmallWorld.simulation(1)
	var player := sim.world.player()
	var ship := player.ships[0]
	assert_eq(player.person_ship_id, ship.id)
	assert_eq(sim.execute(SailCommand.new(WorldState.PLAYER_ID, ship.id, "town")), "")
	assert_false(MarketKnowledgeSystem.has_presence(sim.data, player, "port"))
	for i in ship.voyage_hours:
		sim.tick()
	assert_eq(sim.execute(MovePersonCommand.new()), "")
	assert_eq(player.person_city_id, "town")
	assert_eq(sim.execute(SailCommand.new(WorldState.PLAYER_ID, ship.id, "port")), "")
	assert_true(MarketKnowledgeSystem.has_presence(sim.data, player, "town"))
	assert_false(MarketKnowledgeSystem.has_presence(sim.data, player, "port"))


func test_planner_uses_only_remembered_prices() -> void:
	var sim := SmallWorld.simulation(1)
	var trader := sim.world.player()
	SmallWorld.set_stock(sim, "port", "grain", 40)
	SmallWorld.set_stock(sim, "town", "grain", 0)
	MarketKnowledgeSystem.observe_presence(sim.data, sim.world)
	var boat := sim.data.get_ship("boat")
	assert_eq(TradePlanner.plan(sim.data, trader, boat, "port", 10, 1000).size(), 0)
	trader.market_book["town"] = MarketKnowledgeSystem.current_report(
		sim.data, sim.world.get_city("town"), sim.day()
	)
	assert_eq(TradePlanner.plan(sim.data, trader, boat, "port", 10, 1000).size(), 1)
	SmallWorld.set_stock(sim, "town", "grain", 40)
	assert_eq(TradePlanner.plan(sim.data, trader, boat, "port", 10, 1000).size(), 1)


func test_market_books_save_and_old_saves_get_initial_reports() -> void:
	var sim := SmallWorld.simulation(1)
	sim.advance_days(1)
	var save := SaveGame.to_dict(sim.world)
	var loader := SaveGame.new()
	var loaded := loader.from_dict(sim.data, save)
	assert_not_null(loaded)
	assert_eq(SaveGame.to_dict(loaded), save)
	var old: Dictionary = save.duplicate(true)
	old["save_version"] = 7
	for trader: Dictionary in old["traders"]:
		trader.erase("market_book")
		for ship: Dictionary in trader["ships"]:
			ship.erase("news")
	var migrated := loader.from_dict(sim.data, old)
	assert_not_null(migrated)
	assert_eq(migrated.player().market_book.size(), sim.data.cities.size())


func test_loaded_quotes_follow_the_remembered_stock() -> void:
	var sim := SmallWorld.simulation(1)
	var original: MarketRecord = sim.world.player().market_book["port"]
	var save := SaveGame.to_dict(sim.world)
	var saved: Dictionary = save["traders"][0]["market_book"][0]
	assert_false(saved.has("sell_price"), "quotes are derived, not saved")
	var loader := SaveGame.new()
	var loaded: MarketRecord = loader.from_dict(sim.data, save).player().market_book["port"]
	assert_eq(loaded.buy_price, original.buy_price)
	assert_eq(loaded.sell_price, original.sell_price)
	assert_eq(loaded.mid_price, original.mid_price)
	saved["stock"]["grain"] = saved["stock"]["grain"] * 3 + 10
	var edited: MarketRecord = SaveGame.new().from_dict(sim.data, save).player().market_book["port"]
	assert_lt(edited.sell_price["grain"], original.sell_price["grain"])
	assert_eq(
		edited.sell_price["grain"],
		CityEconomy.sell_revenue(sim.data.economy, edited.as_city(), sim.data.get_good("grain"), 1)
	)


func test_bad_market_report_is_rejected() -> void:
	var sim := SmallWorld.simulation(1)
	var save := SaveGame.to_dict(sim.world)
	save["traders"][0]["market_book"][0]["stock"].erase("grain")
	var loader := SaveGame.new()
	assert_null(loader.from_dict(sim.data, save))
	assert_string_contains("\n".join(loader.errors), "missing grain")
