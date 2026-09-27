extends GutTest
## Trade routes through the real UI: the route editor, the routes panel, the fleet panel's route
## picker, and route problems in the log.

const MainScene := preload("res://ui/main.tscn")
const TestSaves := preload("res://tests/support/test_saves.gd")
const SCREEN_SIZE: Vector2 = Vector2(1280, 720)
const PLAYER := WorldState.PLAYER_ID

var _main: Control
var _session: GameSession


func before_each() -> void:
	_main = MainScene.instantiate()
	add_child_autofree(_main)
	_main.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_main.size = SCREEN_SIZE
	_session = _main.get_node("Session")
	TestSaves.use(_session)
	_main.get_node("StartScreen").visible = false
	_session.set_speed(0)
	await wait_process_frames(1)


func after_each() -> void:
	TestSaves.clear()


func test_creating_a_route_in_the_editor() -> void:
	_session.set_speed(2)
	_press("NewRoute")
	assert_true(_editor().visible)
	assert_eq(_session.speed, 0, "paused while editing")
	_pick("Stop_1_City", _city_index("danzig"))
	_press("Stop_0_AddOrder")
	_pick("Stop_0_Order_0_Good", _good_index("salt"))
	(_find("Stop_0_Order_0_Quantity") as SpinBox).value = 20
	(_find("Stop_0_Order_0_Limit") as SpinBox).value = 30
	_press("Stop_1_AddOrder")
	_pick("Stop_1_Order_0_Action", RouteOrder.Action.SELL)
	_pick("Stop_1_Order_0_Good", _good_index("salt"))
	_press("SaveRoute")
	assert_false(_editor().visible)
	assert_eq(_session.speed, 2, "time runs again")
	var route := _session.player().get_route("route_1")
	assert_eq([route.stops[0].city_id, route.stops[1].city_id], ["lubeck", "danzig"])
	var buy := route.stops[0].orders[0]
	assert_eq(
		[buy.action, buy.good_id, buy.quantity, buy.price_limit],
		[RouteOrder.Action.BUY, "salt", 20, 30]
	)
	var sell := route.stops[1].orders[0]
	assert_eq([sell.action, sell.good_id], [RouteOrder.Action.SELL, "salt"])
	assert_eq(_text("Route_route_1/Summary"), "Route 1: Lübeck → Danzig (no ships)")


func test_invalid_routes_stay_in_the_editor_with_the_reason() -> void:
	_press("NewRoute")
	_pick("Stop_1_City", _city_index("lubeck"))
	_press("SaveRoute")
	assert_true(_editor().visible)
	assert_eq(_text("RouteEditorNote"), "Stops 1 and 2 are both Lübeck")
	assert_eq(_session.player().routes.size(), 0)


func test_cancelling_an_edit_changes_nothing() -> void:
	_make_route(0)
	_press("EditRoute_route_1")
	_press("Stop_0_AddOrder")
	(_find("RouteName") as LineEdit).text = "Renamed"
	_press("CancelRoute")
	var route := _session.player().get_route("route_1")
	assert_eq(route.name, "Run")
	assert_eq(route.stops[0].orders.size(), 1)


func test_putting_a_ship_on_a_route_from_the_fleet_panel() -> void:
	_make_route(0)
	var picker := _find("ShipRoute") as OptionButton
	assert_true(picker.is_visible_in_tree())
	_pick("ShipRoute", 1)
	var ship := _session.player().get_ship("ship_1")
	assert_eq(ship.route_id, "route_1")
	assert_eq(_text("ShipRouteStatus"), "Next stop 1 of 2: Lübeck")
	assert_string_contains((_find("Ship_ship_1") as Button).text, "on Run")
	assert_eq(_text("Route_route_1/Summary"), "Run: Lübeck → Danzig (1 ship)")
	_pick("ShipRoute", 0)
	assert_eq(ship.route_id, "")


func test_route_problems_are_logged() -> void:
	_make_route(1)
	_session.execute(AssignRouteCommand.new(PLAYER, "ship_1", "route_1"))
	_session.advance(1)
	var entry := "Adler (Run): Lübeck: Salt dearer than 1"
	assert_string_ends_with(_session.notification_log[-1], entry)
	assert_string_contains(_text("ShipRouteStatus"), "Last stop: Lübeck: Salt dearer than 1")


func test_route_ships_neither_pause_nor_log_their_arrivals() -> void:
	_make_route(0)
	_session.execute(AssignRouteCommand.new(PLAYER, "ship_1", "route_1"))
	_session.set_speed(1)
	var ship := _session.player().get_ship("ship_1")
	_session.advance(1)
	var hours := ship.voyage_hours
	_session.advance(hours + 1)
	assert_eq(ship.destination, "lubeck", "reached Danzig and turned for home")
	assert_eq(_session.speed, 1, "no pause for a route ship")
	for entry in _session.notification_log:
		assert_false(entry.contains("arrived"), entry)


func test_switching_to_load_drops_the_price_limit() -> void:
	_make_route(40)
	_press("EditRoute_route_1")
	_pick("Stop_0_Order_0_Action", RouteOrder.Action.LOAD)
	assert_null(_main.find_child("Stop_0_Order_0_Limit", true, false))
	assert_eq(_editor().edited_stops()[0].orders[0].price_limit, 0)


func test_deleting_a_route_from_the_panel() -> void:
	_make_route(0)
	_session.execute(AssignRouteCommand.new(PLAYER, "ship_1", "route_1"))
	_press("DeleteRoute_route_1")
	assert_eq(_session.player().routes.size(), 0)
	assert_eq(_session.player().get_ship("ship_1").route_id, "")
	assert_null(_main.find_child("Route_route_1", true, false))


## Lübeck → Danzig, buying 10 salt in Lübeck with `limit` (0 for any price).
func _make_route(limit: int) -> void:
	var orders: Array[RouteOrder] = [RouteOrder.new(RouteOrder.Action.BUY, "salt", 10, limit)]
	var stops: Array[RouteStop] = [RouteStop.new("lubeck", orders), RouteStop.new("danzig")]
	assert_true(_session.execute(SaveRouteCommand.new(PLAYER, "", "Run", stops)))


func _editor() -> RouteEditor:
	return _main.get_node("RouteEditor")


func _city_index(city_id: String) -> int:
	for i in _session.sim.data.cities.size():
		if _session.sim.data.cities[i].id == city_id:
			return i
	return -1


func _good_index(good_id: String) -> int:
	for i in _session.sim.data.goods.size():
		if _session.sim.data.goods[i].id == good_id:
			return i
	return -1


func _find(node_name: String) -> Node:
	var node := _main.find_child(node_name, true, false)
	assert_not_null(node, "%s exists" % node_name)
	return node


func _pick(node_name: String, index: int) -> void:
	var option := _find(node_name) as OptionButton
	option.select(index)
	option.item_selected.emit(index)


func _press(node_name: String) -> void:
	var button := _find(node_name) as Button
	assert_false(button.disabled, "%s is enabled" % node_name)
	button.pressed.emit()


func _text(path: String) -> String:
	var parts := path.split("/")
	var node := _find(parts[0])
	for part in parts.slice(1):
		node = node.get_node(part)
	return (node as Label).text
