extends GutTest
## Ranks gate ships, kontors and routes, rise with worth and standing, and never fall (ADR 0015).

const SmallWorld := preload("res://tests/support/small_world.gd")
const PLAYER := WorldState.PLAYER_ID

var _sim: Simulation


func before_each() -> void:
	_sim = Simulation.new_game(SmallWorld.with_ranks(SmallWorld.data()), 1)


func _player() -> TraderState:
	return _sim.world.player()


func _grain_route() -> Array[RouteStop]:
	var buy: Array[RouteOrder] = [RouteOrder.new(RouteOrder.Action.BUY, "grain", 5)]
	var sell: Array[RouteOrder] = [RouteOrder.new(RouteOrder.Action.SELL, "grain", 5)]
	return [RouteStop.new("port", buy), RouteStop.new("town", sell)]


func test_shipped_ranks_load_in_order() -> void:
	var data := GameDataLoader.new().load_dir(GameDataLoader.DEFAULT_DIR)
	var names: Array[String] = []
	for rank in data.ranks:
		names.append(rank.name)
	assert_eq(names, ["Skipper", "Merchant", "Trading house", "Councillor", "Alderman"])
	assert_eq(data.get_ship("hulk").rank_id, "trading_house")
	var sim := Simulation.new_game(data, 1)
	for trader in sim.world.traders:
		assert_eq(trader.rank_id, "skipper", trader.id)


func test_bad_ranks_are_reported() -> void:
	var loader := GameDataLoader.new()
	assert_null(loader.load_dir("res://tests/fixtures/bad_ranks"))
	var expected: Array[String] = [
		"ranks.json reputation: 'per_workshop_day' must be a whole number of at least 0",
		"ranks.json ranks[0]: the first rank must need nothing",
		"ranks.json ranks[1]: 'richest' must be true or false",
		(
			"ranks.json ranks[1]: unknown unlock 'flying' (known: routes, factors, buy_assets,"
			+ " buy_out_houses)"
		),
		"ranks.json ranks[2]: duplicate id 'skipper'",
		"ships.json[1]: unknown rank 'admiral'",
	]
	for message in expected:
		assert_has(loader.errors, message)


func test_a_skipper_owns_one_ship_and_no_ranked_types() -> void:
	_player().coins = 10_000
	assert_eq(
		_sim.execute(BuyShipCommand.new(PLAYER, "port", "boat")),
		"A Skipper owns at most 1 ship; the rank Merchant allows more"
	)
	_player().rank_id = "merchant"
	assert_eq(_sim.execute(BuyShipCommand.new(PLAYER, "port", "barge")), "")
	assert_eq(_player().ships.size(), 2)
	_player().rank_id = "skipper"
	_sim.execute(MovePersonCommand.new())
	assert_eq(_sim.execute(SellShipCommand.new(PLAYER, "ship_2")), "")
	assert_eq(
		_sim.execute(BuyShipCommand.new(PLAYER, "port", "barge")), "A Barge needs the rank Merchant"
	)


func test_a_kontor_abroad_needs_reputation_and_the_count_is_capped() -> void:
	_player().coins = 10_000
	assert_eq(
		_sim.execute(BuyKontorCommand.new(PLAYER, "town")),
		"A kontor in Town needs reputation 10 there (you have 0)"
	)
	assert_eq(_sim.execute(BuyKontorCommand.new(PLAYER, "port")), "", "home needs none")
	ReputationSystem.add(_sim.data, _player(), "town", 10)
	assert_eq(
		_sim.execute(BuyKontorCommand.new(PLAYER, "town")),
		"A Skipper holds at most 1 kontor; the rank Merchant allows more"
	)
	_player().rank_id = "merchant"
	assert_eq(_sim.execute(BuyKontorCommand.new(PLAYER, "town")), "")


func test_routes_need_the_rank_merchant() -> void:
	var locked := "Trade routes need the rank Merchant"
	assert_eq(_sim.execute(SaveRouteCommand.new(PLAYER, "", "Run", _grain_route())), locked)
	_player().rank_id = "merchant"
	assert_eq(_sim.execute(SaveRouteCommand.new(PLAYER, "", "Run", _grain_route())), "")
	_player().rank_id = "skipper"
	assert_eq(_sim.execute(AssignRouteCommand.new(PLAYER, SmallWorld.SHIP_ID, "route_1")), locked)


func test_houses_rise_with_worth_and_standing_and_never_fall() -> void:
	RankSystem.run_day(_sim.data, _sim.world)
	assert_eq(_player().rank_id, "skipper")
	_player().coins = 2000
	RankSystem.run_day(_sim.data, _sim.world)
	assert_eq(_player().rank_id, "merchant")
	_player().coins = 10_000
	var house := _sim.data.ranks[2]
	assert_eq(
		RankSystem.missing(_sim.data, _sim.world, _player(), house),
		PackedStringArray(["reputation 20 in 2 cities (0 so far)"])
	)
	ReputationSystem.add(_sim.data, _player(), "port", 20)
	ReputationSystem.add(_sim.data, _player(), "town", 20)
	RankSystem.run_day(_sim.data, _sim.world)
	assert_eq(_player().rank_id, "house")
	assert_null(RankSystem.next_rank(_sim.data, _player()))
	_player().coins = 0
	_player().reputation.clear()
	RankSystem.run_day(_sim.data, _sim.world)
	assert_eq(_player().rank_id, "house", "ranks are never lost")


func test_the_richest_rank_needs_the_top_worth() -> void:
	var data := SmallWorld.with_ranks(SmallWorld.with_rival(SmallWorld.data()))
	data.ranks[1].richest = true
	var sim := Simulation.new_game(data, 1)
	var player := sim.world.player()
	var rival := sim.world.get_trader(SmallWorld.RIVAL_ID)
	player.coins = 2000
	rival.coins = 5000
	assert_has(RankSystem.missing(data, sim.world, player, data.ranks[1]), "the richest house")
	RankSystem.run_day(data, sim.world)
	assert_eq([player.rank_id, rival.rank_id], ["skipper", "merchant"])


func test_rivals_only_plan_ships_their_rank_allows() -> void:
	var sim := Simulation.new_game(
		SmallWorld.with_ranks(SmallWorld.with_rival(SmallWorld.data())), 1
	)
	var rival := sim.world.get_trader(SmallWorld.RIVAL_ID)
	assert_null(RivalSystem.ship_to_buy(sim, rival, 10_000), "a Skipper's fleet is full")
	rival.rank_id = "merchant"
	assert_eq(RivalSystem.ship_to_buy(sim, rival, 10_000).id, "boat")


func test_older_saves_rank_by_worth_and_new_ones_keep_rank_and_reputation() -> void:
	_player().rank_id = "house"
	ReputationSystem.add(_sim.data, _player(), "town", 15)
	var save := SaveGame.to_dict(_sim.world)
	var loaded := SaveGame.new().from_dict(_sim.data, save)
	assert_eq(loaded.player().rank_id, "house")
	assert_eq(loaded.player().reputation, {"town": 15})
	assert_eq(SaveGame.to_dict(loaded), save)
	var old: Dictionary = save.duplicate(true)
	old["save_version"] = 9
	old["traders"][0]["coins"] = 5000
	var migrated := SaveGame.new().from_dict(_sim.data, old)
	assert_not_null(migrated)
	assert_eq(migrated.player().rank_id, "merchant", "worth 5300 but no standing")
	assert_true(migrated.player().reputation.is_empty())


func test_bad_rank_and_reputation_in_saves_are_rejected() -> void:
	var save := SaveGame.to_dict(_sim.world)
	save["traders"][0]["rank"] = "king"
	save["traders"][0]["reputation"] = {"town": 101, "atlantis": 5}
	var loader := SaveGame.new()
	assert_null(loader.from_dict(_sim.data, save))
	assert_has(loader.errors, "traders[0]: unknown rank 'king'")
	assert_has(loader.errors, "traders[0] reputation: town 101 outside 1 to 100")
	assert_has(loader.errors, "traders[0] reputation: unknown city 'atlantis'")
