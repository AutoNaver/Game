extends GutTest
## RouteSystem: ships on trade routes carry out their orders at each stop through commands and sail
## on, with price, coin and space limits.

const SmallWorld := preload("res://tests/support/small_world.gd")
const PLAYER := WorldState.PLAYER_ID
const SHIP := SmallWorld.SHIP_ID

var _sim: Simulation


func before_each() -> void:
	_sim = SmallWorld.simulation()
	# A grain glut in port and none in town: grain from port to town pays.
	SmallWorld.set_stock(_sim, "port", "grain", 40)
	SmallWorld.set_stock(_sim, "town", "grain", 0)


func _route(port_orders: Array[RouteOrder], town_orders: Array[RouteOrder]) -> void:
	var stops: Array[RouteStop] = [
		RouteStop.new("port", port_orders), RouteStop.new("town", town_orders)
	]
	assert_eq(_sim.execute(SaveRouteCommand.new(PLAYER, "", "Grain run", stops)), "")
	assert_eq(_sim.execute(AssignRouteCommand.new(PLAYER, SHIP, "route_1")), "")


func _order(
	action: RouteOrder.Action, good_id: String, quantity: int, limit: int = 0
) -> RouteOrder:
	return RouteOrder.new(action, good_id, quantity, limit)


func _ship() -> ShipState:
	return _sim.world.player().get_ship(SHIP)


func _invariants_hold() -> void:
	assert_eq(EconomyInvariants.check(_sim.data, _sim.world), PackedStringArray())


func test_a_ship_buys_sails_sells_and_loops() -> void:
	var buy: Array[RouteOrder] = [_order(RouteOrder.Action.BUY, "grain", 10)]
	var sell: Array[RouteOrder] = [_order(RouteOrder.Action.SELL, "grain", 10)]
	_route(buy, sell)
	var coins := _sim.world.player().coins
	_sim.tick()
	assert_eq(_ship().cargo, {"grain": 10})
	assert_eq([_ship().destination, _ship().route_stop], ["town", 1])
	for i in _ship().voyage_hours:
		_sim.tick()
	assert_eq(_ship().cargo, {}, "sold on arrival")
	assert_eq([_ship().destination, _ship().route_stop], ["port", 0], "and on its way back")
	assert_gt(_sim.world.player().coins, coins)
	assert_eq(_ship().route_note, "")
	_invariants_hold()


func test_price_limits_stop_buying_and_selling() -> void:
	var buy: Array[RouteOrder] = [_order(RouteOrder.Action.BUY, "grain", 10, 1)]
	_route(buy, [])
	_sim.tick()
	assert_eq(_ship().cargo, {})
	assert_eq(_ship().route_note, "Port: Grain dearer than 1")
	assert_eq(_ship().destination, "town", "the ship keeps to its route")

	var sell_all: Array[RouteOrder] = [_order(RouteOrder.Action.SELL, "grain", 10, 1000)]
	_sim.execute(
		SaveRouteCommand.new(
			PLAYER, "route_1", "Grain run", [RouteStop.new("port"), RouteStop.new("town", sell_all)]
		)
	)
	SmallWorld.give_cargo(_sim, _ship(), "grain", 4)
	for i in _ship().voyage_hours - _ship().hours_sailed:
		_sim.tick()
	assert_eq(_ship().cargo, {"grain": 4}, "nothing sold below the limit")
	assert_eq(_ship().route_note, "Town: Grain cheaper than 1000")


func test_a_buy_limit_takes_only_the_units_within_it() -> void:
	var economy := _sim.data.economy
	var grain := _sim.data.get_good("grain")
	var port := _sim.world.get_city("port")
	# Limit between the 3rd and 4th unit's price: exactly three units qualify.
	var fourth := (
		Pricing.mid_price(economy, grain.base_price, 20, 40 - 4) * (1.0 + economy.spread / 2.0)
	)
	var third := (
		Pricing.mid_price(economy, grain.base_price, 20, 40 - 3) * (1.0 + economy.spread / 2.0)
	)
	assert_lt(third, fourth)
	var buy: Array[RouteOrder] = [_order(RouteOrder.Action.BUY, "grain", 10, floori(fourth))]
	assert_lt(third, float(floori(fourth)), "fixture: the limit sits between the two prices")
	_route(buy, [])
	_sim.tick()
	assert_eq(_ship().cargo, {"grain": 3})
	assert_eq(port.stock["grain"], 37)


func test_buying_stops_at_the_coins_available() -> void:
	_sim.world.player().coins = 50
	var buy: Array[RouteOrder] = [_order(RouteOrder.Action.BUY, "grain", 10)]
	_route(buy, [])
	_sim.tick()
	var bought := _ship().cargo_of("grain")
	assert_gt(bought, 0)
	assert_lt(bought, 10)
	var grain := _sim.data.get_good("grain")
	var port := _sim.world.get_city("port")
	assert_gte(_sim.world.player().coins, 0)
	assert_gt(CityEconomy.buy_cost(_sim.data.economy, port, grain, 1), _sim.world.player().coins)
	_invariants_hold()


func test_loading_and_unloading_through_a_kontor() -> void:
	_sim.world.player().coins = 5000
	assert_eq(_sim.execute(BuyKontorCommand.new(PLAYER, "port")), "")
	assert_eq(_sim.execute(BuyCommand.for_kontor(PLAYER, "port", "grain", 8)), "")
	SmallWorld.give_cargo(_sim, _ship(), "wine", 4)
	var orders: Array[RouteOrder] = [
		_order(RouteOrder.Action.UNLOAD, "wine", 99), _order(RouteOrder.Action.LOAD, "grain", 5)
	]
	_route(orders, [_order(RouteOrder.Action.UNLOAD, "grain", 5)])
	_sim.tick()
	var kontor := _sim.world.player().get_kontor("port")
	assert_eq(_ship().cargo, {"grain": 5})
	assert_eq(kontor.cargo, {"grain": 3, "wine": 4})
	for i in _ship().voyage_hours:
		_sim.tick()
	assert_eq(_ship().cargo, {"grain": 5}, "no kontor in town")
	assert_eq(_ship().route_note, "Town: no kontor to unload into")
	_invariants_hold()


func test_a_ship_elsewhere_first_sails_to_its_stop() -> void:
	assert_eq(_sim.execute(SailCommand.new(PLAYER, SHIP, "town")), "")
	for i in _ship().voyage_hours:
		_sim.tick()
	var buy: Array[RouteOrder] = [_order(RouteOrder.Action.BUY, "grain", 10)]
	_route(buy, [])
	var coins := _sim.world.player().coins
	_sim.tick()
	assert_eq([_ship().destination, _ship().route_stop], ["port", 0])
	assert_eq(_sim.world.player().coins, coins, "no orders carried out in town")


func test_ships_off_route_are_left_alone() -> void:
	_sim.tick()
	assert_eq(_ship().docked_at, "port")
