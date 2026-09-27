extends GutTest
## Rival trading houses (RivalSystem, ADR 0008) on SmallWorld: they start like the player, trade
## through commands, expand, run and close workshops, and draw every choice from the world RNG.

const SmallWorld := preload("res://tests/support/small_world.gd")
const RIVAL := SmallWorld.RIVAL_ID

var _sim: Simulation


func before_each() -> void:
	_sim = SmallWorld.rival_simulation()


func _rival() -> TraderState:
	return _sim.world.get_trader(RIVAL)


## Runs the rivals' daily step as on day `day` (an expansion day if it divides by 5).
func _run_day(day: int) -> void:
	_sim.world.hour = day * Simulation.HOURS_PER_DAY
	RivalSystem.run_day(_sim)


func test_new_games_start_the_rivals_after_the_player() -> void:
	var ids: Array[String] = []
	for trader in _sim.world.traders:
		ids.append(trader.id)
	assert_eq(ids, [WorldState.PLAYER_ID, RIVAL])
	assert_eq([_rival().name, _rival().coins], ["Hanse", SmallWorld.RIVAL_COINS])
	assert_eq(_rival().ships.size(), 1)
	var ship := _rival().ships[0]
	assert_eq([ship.id, ship.name, ship.docked_at], ["ship_2", "Rival", "port"])


func test_a_docked_rival_ship_buys_a_profitable_load_and_sails() -> void:
	SmallWorld.set_stock(_sim, "port", "grain", 40)
	SmallWorld.set_stock(_sim, "town", "grain", 0)
	_sim.tick()
	var ship := _rival().ships[0]
	assert_false(ship.is_docked(), "sailed in the hour it was docked")
	assert_eq(ship.destination, "town")
	assert_eq(ship.cargo_of("grain"), 10, "a full load: town pays far more than port asks")
	assert_lt(_rival().coins, SmallWorld.RIVAL_COINS)
	assert_eq(EconomyInvariants.check(_sim.data, _sim.world), PackedStringArray())


func test_a_rival_ship_sells_its_cargo_on_arrival() -> void:
	SmallWorld.set_stock(_sim, "port", "grain", 40)
	SmallWorld.set_stock(_sim, "town", "grain", 0)
	_sim.tick()
	var coins_at_sea := _rival().coins
	var ship := _rival().ships[0]
	# It docks, sells and leaves again within the same hour, so wait until it heads elsewhere.
	while ship.destination == "town":
		_sim.tick()
	assert_eq(ship.cargo_of("grain"), 0, "the grain was sold in town")
	assert_gt(_rival().coins, coins_at_sea, "selling earned coins")
	assert_eq(EconomyInvariants.check(_sim.data, _sim.world), PackedStringArray())


func test_with_nothing_worth_carrying_a_rival_ship_sails_empty() -> void:
	_sim.tick()
	var ship := _rival().ships[0]
	assert_false(ship.is_docked())
	assert_eq(ship.destination, "town", "the only other city")
	assert_eq(ship.cargo_total(), 0)
	assert_eq(_rival().coins, SmallWorld.RIVAL_COINS)


func test_rivals_never_move_the_players_ships() -> void:
	var player_ship := _sim.world.player().ships[0]
	SmallWorld.set_stock(_sim, "port", "grain", 40)
	SmallWorld.set_stock(_sim, "town", "grain", 0)
	_sim.tick()
	assert_true(player_ship.is_docked(), "the player's ship is never moved by the AI")


func test_pick_option_draws_among_the_best_few() -> void:
	var options: Array[TradePlanner.Option] = []
	for profit: int in [300, 200, 100]:
		options.append(TradePlanner.Option.new("town", "grain", 1, 0, profit, 24))
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var picked: Dictionary[int, int] = {}
	for i in 300:
		var option := RivalSystem.pick_option(rng, options, 2)
		picked[option.profit()] = picked.get(option.profit(), 0) + 1
	assert_false(picked.has(100), "only the best 2 are candidates")
	assert_gt(picked[300], picked[200], "better options are picked more often")
	assert_null(RivalSystem.pick_option(rng, [] as Array[TradePlanner.Option], 3))
	assert_eq(RivalSystem.pick_option(rng, options, 1).profit(), 300)


func test_expansion_waits_for_the_expansion_day() -> void:
	_rival().coins = 10000
	_run_day(SmallWorld.RIVAL_EXPANSION_DAYS - 1)
	assert_eq(_rival().ships.size(), 1)
	assert_eq(_rival().kontors.size(), 0)


func test_a_rival_without_a_workshop_to_build_buys_the_biggest_ship_it_can() -> void:
	_sim.data.rival_ai.max_kontors = 0
	_sim.data.add_ship(ShipDef.new("barge", "Barge", 30, 5.0, 900))
	_rival().coins = SmallWorld.RIVAL_RESERVE + 899
	_run_day(SmallWorld.RIVAL_EXPANSION_DAYS)
	assert_eq(_rival().ships.size(), 2)
	assert_eq(_rival().ships[1].type_id, "boat", "a barge would dip into the reserve")
	assert_eq(_rival().ships[1].docked_at, "port", "bought in the home city")
	assert_eq(_rival().coins, SmallWorld.RIVAL_RESERVE + 399)
	_rival().coins = 100000
	_run_day(SmallWorld.RIVAL_EXPANSION_DAYS * 2)
	assert_eq(_rival().ships.size(), 2, "max_ships is 2")


func test_a_rival_that_cannot_spare_the_reserve_does_not_expand() -> void:
	_rival().coins = SmallWorld.RIVAL_RESERVE + 400
	_run_day(SmallWorld.RIVAL_EXPANSION_DAYS)
	assert_eq(_rival().ships.size(), 1)
	assert_eq(_rival().kontors.size(), 0)
	assert_eq(_rival().coins, SmallWorld.RIVAL_RESERVE + 400)


func test_a_rival_with_a_full_fleet_sets_up_the_best_workshop() -> void:
	_sim.data.rival_ai.max_ships = 1
	SmallWorld.set_stock(_sim, "town", "wine", 0)
	_run_day(SmallWorld.RIVAL_EXPANSION_DAYS)
	var kontor := _rival().get_kontor("town")
	assert_not_null(kontor, "town, where wine is scarce, pays best")
	assert_eq(kontor.workshops.size(), 1)
	assert_eq(kontor.workshops[0].type_id, "vintner")
	var costs := SmallWorld.KONTOR_PRICE + _sim.data.get_workshop("vintner").build_cost
	assert_eq(_rival().coins, SmallWorld.RIVAL_COINS - costs)


func test_rivals_do_not_open_a_workshop_type_another_house_runs_there() -> void:
	_sim.data.rival_ai.max_ships = 1
	var player := WorldState.PLAYER_ID
	_sim.world.player().coins = 5000
	assert_eq(_sim.execute(BuyKontorCommand.new(player, "port")), "")
	assert_eq(_sim.execute(BuildWorkshopCommand.new(player, "port", "vintner")), "")
	_run_day(SmallWorld.RIVAL_EXPANSION_DAYS)
	assert_null(_rival().get_kontor("port"))
	assert_not_null(_rival().get_kontor("town"), "the vintner goes to the other city")


func test_workshops_must_leave_enough_workers_free() -> void:
	_sim.data.rival_ai.max_ships = 1
	_sim.data.rival_ai.keep_free_workers = 0.75
	_run_day(SmallWorld.RIVAL_EXPANSION_DAYS)
	assert_eq(_rival().kontors.size(), 0, "a vintner would leave only 70 of 100 workers free")


## A rival kontor in port running a vintner, as RivalSystem would set it up.
func _rival_vintner() -> KontorState:
	_rival().coins = 5000
	assert_eq(_sim.execute(BuyKontorCommand.new(RIVAL, "port")), "")
	assert_eq(_sim.execute(BuildWorkshopCommand.new(RIVAL, "port", "vintner")), "")
	return _rival().get_kontor("port")


func test_rivals_stock_workshop_inputs_and_sell_the_output() -> void:
	var kontor := _rival_vintner()
	SmallWorld.set_stock(_sim, "port", "grain", 40)
	kontor.change_cargo("wine", 6)
	_sim.world.goods_ledger["wine"] += 6
	var wine_stock: int = _sim.world.get_city("port").stock["wine"]
	_run_day(1)
	assert_eq(kontor.cargo_of("grain"), 4 * SmallWorld.RIVAL_INPUT_DAYS)
	assert_eq(kontor.cargo_of("wine"), 0, "output is sold")
	assert_eq(_sim.world.get_city("port").stock["wine"], wine_stock + 6)
	assert_eq(EconomyInvariants.check(_sim.data, _sim.world), PackedStringArray())


func test_rivals_do_not_buy_inputs_above_their_price_limit() -> void:
	var kontor := _rival_vintner()
	SmallWorld.set_stock(_sim, "port", "grain", 2)
	_run_day(1)
	assert_eq(kontor.cargo_of("grain"), 0, "near-empty market: far above 1.5x base")


func test_losing_workshops_are_closed_on_expansion_days() -> void:
	var kontor := _rival_vintner()
	SmallWorld.set_stock(_sim, "port", "wine", 10)
	SmallWorld.set_stock(_sim, "port", "grain", 1)
	_run_day(1)
	assert_eq(kontor.workshops.size(), 1, "only reviewed on expansion days")
	_rival().coins = SmallWorld.RIVAL_RESERVE
	_run_day(SmallWorld.RIVAL_EXPANSION_DAYS)
	assert_eq(kontor.workshops.size(), 0, "no grain to be had: the vintner would only cost wages")


func test_the_daily_margin_counts_wages_inputs_and_the_price_walk() -> void:
	var port := _sim.world.get_city("port")
	var vintner := _sim.data.get_workshop("vintner")
	var economy := _sim.data.economy
	var wine := _sim.data.get_good("wine")
	var grain := _sim.data.get_good("grain")
	var expected := (
		CityEconomy.sell_revenue(economy, port, wine, 2)
		- CityEconomy.buy_cost(economy, port, grain, 4)
		- vintner.wages_per_day
	)
	assert_eq(RivalSystem.daily_margin(_sim, port, vintner), float(expected))
	SmallWorld.set_stock(_sim, "port", "grain", 3)
	assert_eq(RivalSystem.daily_margin(_sim, port, vintner), -INF, "can't get 4 grain")


func test_rivals_play_deterministically_from_the_seed() -> void:
	var first := SmallWorld.rival_simulation(11)
	var second := SmallWorld.rival_simulation(11)
	first.advance_days(40)
	second.advance_days(40)
	assert_eq(SaveGame.to_dict(first.world), SaveGame.to_dict(second.world))
	assert_eq(EconomyInvariants.check(first.data, first.world), PackedStringArray())


func test_a_rival_in_a_one_city_world_stays_docked() -> void:
	var data := GameDataLoader.new().load_dir("res://tests/fixtures/valid_data")
	var sim := Simulation.new_game(data, 1)
	sim.advance_days(2)
	var ship := sim.world.get_trader("castorp").ships[0]
	assert_eq(ship.docked_at, "lubeck", "nowhere else to sail")
	assert_eq(EconomyInvariants.check(data, sim.world), PackedStringArray())
