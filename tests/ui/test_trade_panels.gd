extends GutTest
## Plays the core loop through the real UI: buy in Lübeck, sail, sell elsewhere.

const MainScene := preload("res://ui/main.tscn")
const TestSaves := preload("res://tests/support/test_saves.gd")
const SCREEN_SIZE: Vector2 = Vector2(1280, 720)

var _main: Control
var _session: GameSession


func before_each() -> void:
	_main = MainScene.instantiate()
	add_child_autofree(_main)
	_main.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_main.size = SCREEN_SIZE
	_session = _main.get_node("Session")
	TestSaves.use(_session)
	_session.set_speed(0)
	await wait_process_frames(1)


func after_each() -> void:
	TestSaves.clear()


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


func test_market_shows_price_history_and_trend() -> void:
	var sparkline: Sparkline = _main.find_child("Sparkline_grain", true, false)
	assert_eq(sparkline.point_count(), 0)
	assert_eq(_text("Trend_grain"), "")
	_session.advance(Simulation.HOURS_PER_DAY * 10)
	assert_eq(sparkline.point_count(), 10)
	var history: PackedInt64Array = _session.sim.world.get_city("lubeck").price_history["grain"]
	assert_eq(_text("Trend_grain"), MarketPanel.trend_arrow(history))


func test_hovering_a_good_explains_its_price() -> void:
	var label: Label = _main.find_child("Good_grain", true, false)
	assert_eq(label.mouse_filter, Control.MOUSE_FILTER_PASS)
	var city := _session.sim.world.get_city("lubeck")
	var target := CityEconomy.target_stock(_session.sim.data.economy, city, _grain())
	assert_string_contains(
		label.tooltip_text, "Stock %d of a normal %d" % [city.stock["grain"], target]
	)
	assert_string_contains(label.tooltip_text, "Townsfolk use")


func test_trend_arrow_compares_with_a_week_ago() -> void:
	assert_eq(MarketPanel.trend_arrow(PackedInt64Array([1000])), "")
	assert_eq(MarketPanel.trend_arrow(PackedInt64Array([1000, 1020])), "→")
	assert_eq(MarketPanel.trend_arrow(PackedInt64Array([1000, 1100])), "▲")
	# Only the last 7 days count: a big rise before that doesn't.
	var history := PackedInt64Array([500, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 900])
	assert_eq(MarketPanel.trend_arrow(history), "▼")
	history[-1] = 1000
	assert_eq(MarketPanel.trend_arrow(history), "→")


func test_cargo_ideas_load_the_suggested_cargo() -> void:
	assert_false(_main.find_child("Idea_0", true, false).visible, "balanced markets at the start")
	_session.advance(Simulation.HOURS_PER_DAY * 20)
	var ship := _ship()
	var ship_type := _session.sim.data.get_ship(ship.type_id)
	var options := TradePlanner.plan(
		_session.sim.data,
		_session.sim.world,
		ship_type,
		"lubeck",
		ship_type.capacity,
		_session.player().coins
	)
	assert_gt(options.size(), 0, "markets have drifted apart after 20 days")
	assert_true(_main.find_child("Idea_0", true, false).visible)
	_press("Load_0")
	assert_eq(ship.cargo, {options[0].good_id: options[0].quantity})


func test_cargo_ideas_need_a_ship_in_port() -> void:
	_session.select_city("visby")
	assert_string_contains(_text("PlannerNote"), "Dock a ship here")


func test_sparklines_scale_to_their_values_and_base_price() -> void:
	var sparkline: Sparkline = autofree(Sparkline.new())
	sparkline.set_values(PackedInt64Array([800, 1500]), 1000.0)
	assert_eq(sparkline.value_range(), Vector2(800, 1500))
	# A small wobble is padded to at least 20% of the base price, centred on the data and base.
	sparkline.set_values(PackedInt64Array([1000, 1010]), 1000.0)
	assert_eq(sparkline.value_range(), Vector2(905, 1105))


func test_the_side_panel_keeps_its_width() -> void:
	# A market grid wider than the panel would stretch it and squeeze the map.
	var side: Control = _main.find_child("SidePanel", true, false)
	assert_eq(side.get_combined_minimum_size().x, _main.SIDE_PANEL_WIDTH)
	assert_eq(side.size.x, _main.SIDE_PANEL_WIDTH)


func _grain() -> GoodDef:
	return _session.sim.data.get_good("grain")


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
