extends GutTest
## Ranks, reputation and the kontor factor in the UI on the shipped data (ADR 0015): locked actions
## show the rank or reputation they need, and the factor takes orders through its grid.

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
	_player().coins = 50_000
	_session.changed.emit()
	await wait_process_frames(1)


func after_each() -> void:
	TestSaves.clear()


func test_a_skippers_locked_actions_show_what_they_need() -> void:
	var cog := _button("BuyShip_cog")
	assert_true(cog.disabled, "a Skipper owns one ship")
	assert_string_contains(cog.tooltip_text, "Locked: A Skipper owns at most 1 ship")
	assert_string_contains(
		_button("BuyShip_hulk").tooltip_text, "A Hulk needs the rank Trading house"
	)
	assert_true(_button("NewRoute").disabled)
	assert_eq(_text("RoutesLocked"), "Locked: Trade routes need the rank Merchant")
	_session.select_city("visby")
	assert_true(_button("BuyKontor").disabled)
	assert_eq(
		_text("KontorLocked"), "Locked: A kontor in Visby needs reputation 50 there (you have 0)"
	)
	assert_eq(_text("Reputation"), "Your reputation here: 0 (standing from 100)")
	_session.select_city("lubeck")
	assert_false(_button("BuyKontor").disabled, "the home city needs no reputation")
	assert_false(_label("KontorLocked").visible)


func test_rising_a_rank_unlocks_ships_and_routes() -> void:
	_session.advance(Simulation.HOURS_PER_DAY)
	assert_eq(_player().rank_id, "merchant", "50,000 coins are enough for Merchant")
	assert_false(_button("BuyShip_cog").disabled)
	assert_false(_button("NewRoute").disabled)
	assert_false(_label("RoutesLocked").visible)
	assert_true(_button("BuyShip_hulk").disabled, "Hulks need Trading house")


func test_the_houses_panel_shows_ranks_and_the_next_one() -> void:
	_player().coins = 1000
	_session.houses_toggled.emit()
	var row := _main.find_child("House_player", true, false)
	assert_eq((row.get_node("Rank") as Label).text, "Skipper")
	var worth := HouseValue.net_worth(_session.sim.data, _player())
	assert_eq(
		_text("NextRank"), "Next rank: Merchant, needs worth %d of 25000. Unlocks routes." % worth
	)


func test_the_factor_is_locked_until_trading_house_then_takes_orders() -> void:
	_press("BuyKontor")
	assert_true(_label("FactorLocked").visible)
	assert_eq(_text("FactorLocked"), "Locked: Factors need the rank Trading house")
	assert_false(_button("SaveFactor").visible)
	_player().rank_id = "trading_house"
	_session.changed.emit()
	assert_false(_label("FactorLocked").visible)
	(_main.find_child("FactorMode_grain", true, false) as OptionButton).select(1)
	(_main.find_child("FactorAmount_grain", true, false) as SpinBox).value = 40
	(_main.find_child("FactorLimit_grain", true, false) as SpinBox).value = 30
	(_main.find_child("FactorMode_beer", true, false) as OptionButton).select(2)
	(_main.find_child("FactorAmount_beer", true, false) as SpinBox).value = 5
	_press("SaveFactor")
	var orders := _player().get_kontor("lubeck").factor_orders
	assert_eq(orders.size(), 2)
	assert_eq(
		[orders[0].action, orders[0].good_id, orders[0].amount, orders[0].price_limit],
		[FactorOrder.Action.BUY, "grain", 40, 30]
	)
	assert_eq(
		[orders[1].action, orders[1].good_id, orders[1].amount, orders[1].price_limit],
		[FactorOrder.Action.SELL, "beer", 5, 0]
	)
	_session.changed.emit()
	var mode := _main.find_child("FactorMode_grain", true, false) as OptionButton
	assert_eq(mode.selected, 1, "the grid shows the saved orders")


func _player() -> TraderState:
	return _session.player()


func _button(node_name: String) -> Button:
	var button := _main.find_child(node_name, true, false) as Button
	assert_not_null(button, "button %s exists" % node_name)
	return button


func _press(node_name: String) -> void:
	var button := _button(node_name)
	assert_false(button.disabled, "%s is enabled" % node_name)
	button.pressed.emit()


func _label(node_name: String) -> Label:
	return _main.find_child(node_name, true, false) as Label


func _text(node_name: String) -> String:
	return _label(node_name).text
