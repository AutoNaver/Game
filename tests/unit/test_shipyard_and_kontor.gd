extends GutTest
## Shipyard (buy and sell ships), kontors, trading with a kontor and moving goods ship <-> kontor.

const SmallWorld := preload("res://tests/support/small_world.gd")
const PLAYER := WorldState.PLAYER_ID
const SHIP := SmallWorld.SHIP_ID

var _sim: Simulation


func before_each() -> void:
	_sim = SmallWorld.simulation()


func _player() -> TraderState:
	return _sim.world.player()


func _ok(command: Command) -> void:
	assert_eq(_sim.execute(command), "")


func _assert_healthy() -> void:
	assert_eq(EconomyInvariants.check(_sim.data, _sim.world), PackedStringArray())


func test_buying_a_ship_docks_it_in_the_city() -> void:
	_ok(BuyShipCommand.new(PLAYER, "town", "boat"))
	assert_eq(_player().coins, SmallWorld.START_COINS - 500)
	var ship := _player().get_ship("ship_2")
	assert_eq([ship.name, ship.type_id, ship.docked_at, ship.cargo], ["Boat 2", "boat", "town", {}])
	_assert_healthy()


func test_invalid_ship_purchases_change_nothing() -> void:
	_player().coins = 499
	var cases := {
		"A Boat costs 500 coins, you have 499": BuyShipCommand.new(PLAYER, "port", "boat"),
		"unknown ship type 'galleon'": BuyShipCommand.new(PLAYER, "port", "galleon"),
		"unknown city 'atlantis'": BuyShipCommand.new(PLAYER, "atlantis", "boat"),
		"unknown trader 'nobody'": BuyShipCommand.new("nobody", "port", "boat"),
	}
	for expected: String in cases:
		assert_eq(_sim.execute(cases[expected] as Command), expected)
	assert_eq(_player().ships.size(), 1)
	assert_eq(_player().coins, 499)


func test_selling_a_ship_refunds_the_resale_price() -> void:
	_ok(SellShipCommand.new(PLAYER, SHIP))
	assert_eq(_player().coins, SmallWorld.START_COINS + 300, "60% of 500")
	assert_null(_player().get_ship(SHIP))


func test_only_empty_docked_ships_can_be_sold() -> void:
	_ok(BuyCommand.new(PLAYER, SHIP, "grain", 1))
	assert_eq(_sim.execute(SellShipCommand.new(PLAYER, SHIP)), "Unload Test before selling it")
	_ok(SellCommand.new(PLAYER, SHIP, "grain", 1))
	_ok(SailCommand.new(PLAYER, SHIP, "town"))
	assert_eq(_sim.execute(SellShipCommand.new(PLAYER, SHIP)), "Test is at sea")
	assert_eq(_player().ships.size(), 1)


func test_buying_a_kontor() -> void:
	_ok(BuyKontorCommand.new(PLAYER, "port"))
	assert_eq(_player().coins, SmallWorld.START_COINS - SmallWorld.KONTOR_PRICE)
	assert_not_null(_player().get_kontor("port"))
	assert_eq(
		_sim.execute(BuyKontorCommand.new(PLAYER, "port")), "You already have a kontor in Port"
	)
	_player().coins = 10
	assert_eq(
		_sim.execute(BuyKontorCommand.new(PLAYER, "town")), "A kontor costs 300 coins, you have 10"
	)
	assert_null(_player().get_kontor("town"))


func test_trading_with_a_kontor() -> void:
	assert_eq(
		_sim.execute(BuyCommand.for_kontor(PLAYER, "port", "grain", 5)),
		"you have no kontor in Port"
	)
	_ok(BuyKontorCommand.new(PLAYER, "port"))
	_ok(BuyCommand.for_kontor(PLAYER, "port", "grain", 5))
	var kontor := _player().get_kontor("port")
	assert_eq(kontor.cargo, {"grain": 5})
	assert_eq(_sim.world.get_city("port").stock["grain"], 15)
	_ok(SellCommand.for_kontor(PLAYER, "port", "grain", 2))
	assert_eq(kontor.cargo, {"grain": 3})
	assert_eq(
		_sim.execute(SellCommand.for_kontor(PLAYER, "port", "grain", 9)),
		"Your kontor carries only 3 Grain"
	)
	_assert_healthy()


func test_kontor_capacity_limits_buying() -> void:
	_ok(BuyKontorCommand.new(PLAYER, "port"))
	SmallWorld.set_stock(_sim, "port", "grain", 40)
	_ok(BuyCommand.for_kontor(PLAYER, "port", "grain", 20))
	assert_eq(
		_sim.execute(BuyCommand.for_kontor(PLAYER, "port", "grain", 1)),
		"Your kontor has room for only 0 more units"
	)


func test_transfers_between_ship_and_kontor() -> void:
	_ok(BuyCommand.new(PLAYER, SHIP, "grain", 6))
	assert_eq(
		_sim.execute(TransferCommand.new(PLAYER, SHIP, "grain", 2, true)),
		"You have no kontor in Port"
	)
	_ok(BuyKontorCommand.new(PLAYER, "port"))
	var ship := _player().get_ship(SHIP)
	var kontor := _player().get_kontor("port")
	_ok(TransferCommand.new(PLAYER, SHIP, "grain", 4, true))
	assert_eq([ship.cargo, kontor.cargo], [{"grain": 2}, {"grain": 4}])
	_ok(TransferCommand.new(PLAYER, SHIP, "grain", 1, false))
	assert_eq([ship.cargo, kontor.cargo], [{"grain": 3}, {"grain": 3}])
	assert_eq(
		_sim.execute(TransferCommand.new(PLAYER, SHIP, "grain", 5, true)), "Test holds only 3 Grain"
	)
	assert_eq(
		_sim.execute(TransferCommand.new(PLAYER, SHIP, "wine", 1, false)),
		"Your kontor holds only 0 Wine"
	)
	_assert_healthy()


func test_transfers_respect_the_destination_capacity() -> void:
	_ok(BuyKontorCommand.new(PLAYER, "port"))
	SmallWorld.set_stock(_sim, "port", "grain", 40)
	_ok(BuyCommand.for_kontor(PLAYER, "port", "grain", 12))
	assert_eq(
		_sim.execute(TransferCommand.new(PLAYER, SHIP, "grain", 11, false)),
		"Test has room for only 10 more units"
	)
	_ok(BuyCommand.new(PLAYER, SHIP, "grain", 10))
	assert_eq(
		_sim.execute(TransferCommand.new(PLAYER, SHIP, "grain", 9, true)),
		"Your kontor has room for only 8 more units"
	)
	_assert_healthy()


func test_cannot_transfer_at_sea() -> void:
	_ok(BuyKontorCommand.new(PLAYER, "port"))
	_ok(SailCommand.new(PLAYER, SHIP, "town"))
	assert_eq(_sim.execute(TransferCommand.new(PLAYER, SHIP, "grain", 1, true)), "Test is at sea")
