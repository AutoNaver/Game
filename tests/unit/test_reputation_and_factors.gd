extends GutTest
## Reputation per city, and the kontor factor's standing orders (ADR 0015).

const SmallWorld := preload("res://tests/support/small_world.gd")
const PLAYER := WorldState.PLAYER_ID
const SHIP := SmallWorld.SHIP_ID

var _sim: Simulation


func before_each() -> void:
	_sim = Simulation.new_game(SmallWorld.with_ranks(SmallWorld.data()), 1)
	_sim.world.player().coins = 10_000


func _player() -> TraderState:
	return _sim.world.player()


func _ok(command: Command) -> void:
	assert_eq(_sim.execute(command), "")


func _orders(list: Array) -> Array[FactorOrder]:
	var orders: Array[FactorOrder] = []
	orders.assign(list)
	return orders


func test_selling_into_a_shortage_earns_reputation_per_unit_short() -> void:
	SmallWorld.set_stock(_sim, "town", "grain", 17)
	SmallWorld.give_cargo(_sim, _player().ships[0], "grain", 10)
	_player().ships[0].docked_at = "town"
	_ok(SellCommand.new(PLAYER, SHIP, "grain", 5))
	assert_eq(ReputationSystem.of(_player(), "town"), 3, "target 20: only 3 units were short")
	_ok(SellCommand.new(PLAYER, SHIP, "grain", 5))
	assert_eq(ReputationSystem.of(_player(), "town"), 3, "a full market earns nothing")


func test_kontors_and_workshops_earn_and_idle_workshops_cost_reputation() -> void:
	_ok(BuyKontorCommand.new(PLAYER, "port"))
	_ok(BuildWorkshopCommand.new(PLAYER, "port", "vintner"))
	var kontor := _player().get_kontor("port")
	var workshop := kontor.workshops[0]
	ReputationSystem.run_day(_sim.data, _sim.world)
	assert_eq(ReputationSystem.of(_player(), "port"), 1, "a new workshop has not worked yet")
	workshop.status = WorkshopState.Status.WORKED
	ReputationSystem.run_day(_sim.data, _sim.world)
	assert_eq(ReputationSystem.of(_player(), "port"), 3)
	workshop.status = WorkshopState.Status.NO_INPUTS
	ReputationSystem.run_day(_sim.data, _sim.world)
	assert_eq(ReputationSystem.of(_player(), "port"), 2, "kontor +1, idle workshop -2")
	for i in 5:
		ReputationSystem.run_day(_sim.data, _sim.world)
	assert_eq(ReputationSystem.of(_player(), "port"), 0, "never below zero")
	assert_false(_player().reputation.has("port"), "zero is stored as no entry")
	ReputationSystem.add(_sim.data, _player(), "port", 500)
	assert_eq(ReputationSystem.of(_player(), "port"), 100, "capped at the maximum")


func test_reputation_builds_up_over_days_in_the_simulation() -> void:
	_ok(BuyKontorCommand.new(PLAYER, "port"))
	_sim.advance_days(5)
	assert_eq(ReputationSystem.of(_player(), "port"), 5)
	assert_eq(ReputationSystem.standing_cities(_sim.data, _player()), 0)
	_sim.advance_days(15)
	assert_eq(ReputationSystem.standing_cities(_sim.data, _player()), 1)


func test_factors_need_the_rank_and_a_kontor() -> void:
	var orders := _orders([FactorOrder.new(FactorOrder.Action.BUY, "grain", 10)])
	assert_eq(
		_sim.execute(SetFactorOrdersCommand.new(PLAYER, "port", orders)),
		"You have no kontor in Port"
	)
	_ok(BuyKontorCommand.new(PLAYER, "port"))
	assert_eq(
		_sim.execute(SetFactorOrdersCommand.new(PLAYER, "port", orders)),
		"Factors need the rank House"
	)
	_ok(SetFactorOrdersCommand.new(PLAYER, "port", _orders([])))


func test_invalid_factor_orders_are_refused() -> void:
	_ok(BuyKontorCommand.new(PLAYER, "port"))
	_player().rank_id = "house"
	var cases := {
		"unknown good 'amber'": [FactorOrder.new(FactorOrder.Action.BUY, "amber", 1)],
		"Grain: amount must be 0 to 20": [FactorOrder.new(FactorOrder.Action.BUY, "grain", 21)],
		"Grain: price limit must not be negative":
		[FactorOrder.new(FactorOrder.Action.SELL, "grain", 0, -1)],
		"The factor takes one order per good (Grain twice)":
		[
			FactorOrder.new(FactorOrder.Action.BUY, "grain", 5),
			FactorOrder.new(FactorOrder.Action.SELL, "grain", 8),
		],
	}
	for expected: String in cases:
		var command := SetFactorOrdersCommand.new(PLAYER, "port", _orders(cases[expected]))
		assert_eq(_sim.execute(command), expected)
	assert_true(_player().get_kontor("port").factor_orders.is_empty())


func test_the_factor_buys_up_to_its_amount_within_the_price_limit() -> void:
	_ok(BuyKontorCommand.new(PLAYER, "port"))
	_player().rank_id = "house"
	var orders := _orders([FactorOrder.new(FactorOrder.Action.BUY, "grain", 6)])
	_ok(SetFactorOrdersCommand.new(PLAYER, "port", orders))
	orders[0].amount = 99
	assert_eq(_player().get_kontor("port").factor_orders[0].amount, 6, "the kontor keeps a copy")
	FactorSystem.run_day(_sim)
	assert_eq(_player().get_kontor("port").cargo_of("grain"), 6)
	FactorSystem.run_day(_sim)
	assert_eq(_player().get_kontor("port").cargo_of("grain"), 6, "already at its amount")
	var cheap := _orders([FactorOrder.new(FactorOrder.Action.BUY, "grain", 12, 1)])
	_ok(SetFactorOrdersCommand.new(PLAYER, "port", cheap))
	FactorSystem.run_day(_sim)
	assert_eq(_player().get_kontor("port").cargo_of("grain"), 6, "no grain for 1 coin")
	assert_eq(EconomyInvariants.check(_sim.data, _sim.world), PackedStringArray())


func test_the_factor_sells_down_to_its_amount_above_the_price_limit() -> void:
	_ok(BuyKontorCommand.new(PLAYER, "port"))
	_player().rank_id = "house"
	var kontor := _player().get_kontor("port")
	SmallWorld.give_cargo(_sim, _player().ships[0], "grain", 10)
	_ok(TransferCommand.new(PLAYER, SHIP, "grain", 10, true))
	var city := _sim.world.get_city("port")
	var grain := _sim.data.get_good("grain")
	var one := CityEconomy.sell_revenue(_sim.data.economy, city, grain, 1)
	var orders := _orders([FactorOrder.new(FactorOrder.Action.SELL, "grain", 4, one)])
	_ok(SetFactorOrdersCommand.new(PLAYER, "port", orders))
	var coins := _player().coins
	FactorSystem.run_day(_sim)
	assert_between(kontor.cargo_of("grain"), 4, 9, "sold at least one, kept at least 4")
	assert_gt(_player().coins, coins)
	var loose := _orders([FactorOrder.new(FactorOrder.Action.SELL, "grain", 4)])
	_ok(SetFactorOrdersCommand.new(PLAYER, "port", loose))
	FactorSystem.run_day(_sim)
	assert_eq(kontor.cargo_of("grain"), 4, "without a limit it sells down to its amount")


func test_factor_orders_save_and_bad_ones_are_rejected() -> void:
	_ok(BuyKontorCommand.new(PLAYER, "port"))
	_player().rank_id = "house"
	var orders := _orders(
		[
			FactorOrder.new(FactorOrder.Action.BUY, "grain", 6, 50),
			FactorOrder.new(FactorOrder.Action.SELL, "wine", 2, 200),
		]
	)
	_ok(SetFactorOrdersCommand.new(PLAYER, "port", orders))
	var save := SaveGame.to_dict(_sim.world)
	var loaded := SaveGame.new().from_dict(_sim.data, save)
	assert_eq(loaded.player().get_kontor("port").factor_orders.size(), 2)
	assert_eq(SaveGame.to_dict(loaded), save)
	save["traders"][0]["kontors"][0]["factor"][1]["good"] = "grain"
	var loader := SaveGame.new()
	assert_null(loader.from_dict(_sim.data, save))
	assert_has(
		loader.errors,
		"traders[0] kontors[0] factor: The factor takes one order per good (Grain twice)"
	)
