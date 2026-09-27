extends GutTest

const SmallWorld := preload("res://tests/support/small_world.gd")
const PLAYER := WorldState.PLAYER_ID
const SHIP := SmallWorld.SHIP_ID

var _sim: Simulation
var _port: CityState
var _ship: ShipState


func before_each() -> void:
	_sim = SmallWorld.simulation()
	_port = _sim.world.get_city("port")
	_ship = _sim.world.player().get_ship(SHIP)


func test_buy_moves_goods_and_coins() -> void:
	var grain := _sim.data.get_good("grain")
	var cost := CityEconomy.buy_cost(_sim.data.economy, _port, grain, 5)
	assert_eq(_sim.execute(BuyCommand.new(PLAYER, SHIP, "grain", 5)), "")
	assert_eq(_sim.world.player().coins, SmallWorld.START_COINS - cost)
	assert_eq(_port.stock["grain"], 15)
	assert_eq(_ship.cargo, {"grain": 5})


func test_sell_moves_goods_and_coins() -> void:
	_sim.execute(BuyCommand.new(PLAYER, SHIP, "grain", 5))
	var coins := _sim.world.player().coins
	var grain := _sim.data.get_good("grain")
	var revenue := CityEconomy.sell_revenue(_sim.data.economy, _port, grain, 3)
	assert_eq(_sim.execute(SellCommand.new(PLAYER, SHIP, "grain", 3)), "")
	assert_eq(_sim.world.player().coins, coins + revenue)
	assert_eq(_port.stock["grain"], 18)
	assert_eq(_ship.cargo, {"grain": 2})
	_sim.execute(SellCommand.new(PLAYER, SHIP, "grain", 2))
	assert_eq(_ship.cargo, {}, "empty cargo entries are removed")


func test_buying_then_selling_back_loses_the_spread() -> void:
	_sim.execute(BuyCommand.new(PLAYER, SHIP, "grain", 10))
	_sim.execute(SellCommand.new(PLAYER, SHIP, "grain", 10))
	assert_lt(_sim.world.player().coins, SmallWorld.START_COINS)
	assert_eq(_port.stock["grain"], 20)


func test_trades_conserve_goods() -> void:
	var total_before := _port.stock["grain"] + _ship.cargo_of("grain")
	_sim.execute(BuyCommand.new(PLAYER, SHIP, "grain", 7))
	_sim.execute(SellCommand.new(PLAYER, SHIP, "grain", 4))
	assert_eq(_port.stock["grain"] + _ship.cargo_of("grain"), total_before)


func test_invalid_buys_change_nothing() -> void:
	_sim.world.player().coins = 50
	var cases := {
		"unknown ship 'ship_9'": BuyCommand.new(PLAYER, "ship_9", "grain", 1),
		"unknown good 'amber'": BuyCommand.new(PLAYER, SHIP, "amber", 1),
		"quantity must be positive": BuyCommand.new(PLAYER, SHIP, "grain", 0),
		"Port has only 5 Wine": BuyCommand.new(PLAYER, SHIP, "wine", 6),
		"Test has room for only 10 more units": BuyCommand.new(PLAYER, SHIP, "grain", 11),
		"1 Wine cost 278 coins, you have 50": BuyCommand.new(PLAYER, SHIP, "wine", 1),
	}
	for expected: String in cases:
		assert_eq(_sim.execute(cases[expected] as Command), expected)
	assert_eq(_sim.world.player().coins, 50)
	assert_eq(_port.stock, {"grain": 20, "wine": 5})
	assert_eq(_ship.cargo, {})


func test_invalid_sells_change_nothing() -> void:
	_sim.execute(BuyCommand.new(PLAYER, SHIP, "grain", 2))
	var coins := _sim.world.player().coins
	var cases := {
		"Test carries only 2 Grain": SellCommand.new(PLAYER, SHIP, "grain", 3),
		"Test carries only 0 Wine": SellCommand.new(PLAYER, SHIP, "wine", 1),
		"quantity must be positive": SellCommand.new(PLAYER, SHIP, "grain", -1),
	}
	for expected: String in cases:
		assert_eq(_sim.execute(cases[expected] as Command), expected)
	assert_eq(_sim.world.player().coins, coins)
	assert_eq(_ship.cargo, {"grain": 2})


func test_cannot_trade_at_sea() -> void:
	_sim.execute(BuyCommand.new(PLAYER, SHIP, "grain", 2))
	_sim.execute(SailCommand.new(PLAYER, SHIP, "town"))
	assert_eq(_sim.execute(BuyCommand.new(PLAYER, SHIP, "grain", 1)), "Test is at sea")
	assert_eq(_sim.execute(SellCommand.new(PLAYER, SHIP, "grain", 1)), "Test is at sea")


func test_selling_can_push_stock_past_the_cap() -> void:
	SmallWorld.set_stock(_sim, "port", "grain", 39)
	SmallWorld.give_cargo(_sim, _ship, "grain", 5)
	assert_eq(_sim.execute(SellCommand.new(PLAYER, SHIP, "grain", 5)), "")
	assert_eq(_port.stock["grain"], 44)
	assert_eq(EconomyInvariants.check(_sim.data, _sim.world), PackedStringArray())
