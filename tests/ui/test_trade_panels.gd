extends GutTest
## Plays the core loop through the real UI: buy in Lübeck, sail, sell elsewhere.

const MainScene := preload("res://ui/main.tscn")
const SCREEN_SIZE: Vector2 = Vector2(1280, 720)

var _main: Control
var _session: GameSession


func before_each() -> void:
	_main = MainScene.instantiate()
	add_child_autofree(_main)
	_main.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_main.size = SCREEN_SIZE
	_session = _main.get_node("Session")
	_session.set_speed(0)
	await wait_process_frames(1)


func test_buy_button_loads_the_chosen_quantity() -> void:
	_press("Quantity_10")
	var coins := _session.player().coins
	_press("Buy_beer")
	assert_eq(_ship().cargo, {"beer": 10})
	assert_lt(_session.player().coins, coins)
	assert_string_contains(_text("TradeNote"), "Trading with Adler (10/50)")


func test_buying_stops_at_free_cargo_space() -> void:
	_press("Quantity_25")
	_press("Buy_beer")
	_press("Buy_salt")
	_press("Buy_cloth")
	assert_eq(_ship().cargo_total(), 50)
	_press("Buy_fish")
	assert_eq(_text("MessageLabel"), "Adler has no room left")


func test_sell_button_sells_at_most_what_is_aboard() -> void:
	_press("Quantity_5")
	_press("Buy_salt")
	_press("Quantity_25")
	_press("Sell_salt")
	assert_eq(_ship().cargo, {})


func test_trade_buttons_are_disabled_without_a_ship_in_port() -> void:
	_session.select_city("visby")
	assert_true(_button("Buy_grain").disabled)
	assert_true(_button("Sell_grain").disabled)
	assert_string_contains(_text("TradeNote"), "None of your ships is docked here")


func test_sail_button_sends_the_ship_and_it_arrives() -> void:
	assert_false(_button("Sail_lubeck").visible, "no sailing to where the ship already is")
	_press("Sail_danzig")
	assert_false(_ship().is_docked())
	assert_string_contains(_button("Ship_ship_1").text, "to Danzig")
	_session.advance(_ship().voyage_hours)
	assert_eq(_ship().docked_at, "danzig")
	assert_eq(_text("MessageLabel"), "Adler arrived in Danzig")


func test_full_loop_buy_sail_sell() -> void:
	_press("Quantity_25")
	_press("Buy_salt")
	_press("Sail_danzig")
	_session.advance(_ship().voyage_hours)
	_session.select_city("danzig")
	var coins := _session.player().coins
	_press("Sell_salt")
	assert_eq(_ship().cargo, {})
	assert_gt(_session.player().coins, coins)


func _ship() -> ShipState:
	return _session.player().get_ship("ship_1")


func _button(node_name: String) -> Button:
	var button := _main.find_child(node_name, true, false) as Button
	assert_not_null(button, "button %s exists" % node_name)
	return button


func _press(node_name: String) -> void:
	var button := _button(node_name)
	assert_false(button.disabled, "%s is enabled" % node_name)
	button.pressed.emit()


func _text(node_name: String) -> String:
	return (_main.find_child(node_name, true, false) as Label).text
