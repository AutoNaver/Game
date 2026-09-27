extends GutTest
## Kontor, workshop and shipyard panels driven through their real buttons on the shipped data.

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
	_session.sim.world.player().coins = 50_000
	_session.changed.emit()
	await wait_process_frames(1)


func after_each() -> void:
	TestSaves.clear()


func test_buying_a_kontor_shows_its_storage() -> void:
	assert_true(_button("BuyKontor").visible)
	_press("BuyKontor")
	assert_not_null(_player().get_kontor("lubeck"))
	assert_false(_button("BuyKontor").visible)
	assert_eq(_text("KontorStorage"), "Storage 0/300")


func test_trading_with_the_kontor() -> void:
	_press("BuyKontor")
	_press("TradeWithKontor")
	_press("Quantity_10")
	_press("Buy_beer")
	assert_eq(_player().get_kontor("lubeck").cargo, {"beer": 10})
	assert_eq(_ship().cargo, {}, "the ship was not used")
	assert_string_contains(_text("TradeNote"), "Trading with your kontor (10/300)")


func test_moving_goods_between_ship_and_kontor() -> void:
	_press("BuyKontor")
	_press("Quantity_10")
	_press("Buy_salt")
	assert_true(_button("Unload_salt").visible)
	_press("Unload_salt")
	assert_eq(_player().get_kontor("lubeck").cargo, {"salt": 10})
	_press("Quantity_5")
	_press("Load_salt")
	assert_eq(_ship().cargo, {"salt": 5})


func test_building_a_workshop_and_watching_it_work() -> void:
	_press("BuyKontor")
	_press("Build_brewery")
	var kontor := _player().get_kontor("lubeck")
	assert_eq(kontor.workshops.size(), 1)
	var status := _main.find_child("Workshop_workshop_1", true, false) as Label
	assert_eq(status.text, "Brewery: starts tomorrow")
	_session.advance(Simulation.HOURS_PER_DAY)
	assert_eq(status.text, "Brewery: idle, needs Grain")
	assert_string_contains(_text("Workforce"), "Free workers: ")


func test_building_several_workshops_in_one_frame_labels_each_one() -> void:
	_press("BuyKontor")
	_press("Build_brewery")
	_session.advance(Simulation.HOURS_PER_DAY)
	_press("Build_smithy")
	_press("Build_weaving_mill")
	var list := _main.find_child("Workshop_workshop_1", true, false).get_parent().get_parent()
	var texts: Array[String] = []
	for row in list.get_children():
		if not row.is_queued_for_deletion():
			texts.append((row.get_child(0) as Label).text)
	assert_eq(
		texts,
		[
			"Brewery: idle, needs Grain",
			"Smithy: starts tomorrow",
			"Weaving Mill: starts tomorrow",
		]
	)


func test_closing_a_workshop() -> void:
	_press("BuyKontor")
	_press("Build_brewery")
	_press("Close_workshop_1")
	assert_eq(_player().get_kontor("lubeck").workshops.size(), 0)
	await wait_process_frames(1)
	assert_null(_main.find_child("Workshop_workshop_1", true, false), "its row is gone")


func test_close_buttons_follow_a_loaded_game() -> void:
	_press("BuyKontor")
	_press("Build_brewery")
	_press("SaveGame")
	(_main.find_child("SaveName", true, false) as LineEdit).text = "One brewery"
	_press("ConfirmSave")
	_press("Close_workshop_1")
	_press("Build_smithy")
	await wait_process_frames(1)
	_press("LoadGame")
	_press("Slot_One_brewery")
	await wait_process_frames(1)
	_press("Close_workshop_1")
	assert_eq(_player().get_kontor("lubeck").workshops.size(), 0, "the loaded brewery closed")


func test_build_buttons_need_coins() -> void:
	_press("BuyKontor")
	_player().coins = 100
	_session.changed.emit()
	assert_true(_button("Build_brewery").disabled)


func test_buying_and_selling_ships() -> void:
	_press("BuyShip_snaikka")
	assert_eq(_player().ships.size(), 2)
	# Ship ids and names are numbered across all houses; the rivals' ships come first.
	var new_ship := _player().ships[1]
	assert_eq(_session.selected_ship, new_ship.id, "the new ship is selected")
	assert_string_contains(_button("SellShip").text, "Sell %s (+1800)" % new_ship.name)
	var coins := _player().coins
	_press("SellShip")
	assert_eq(_player().ships.size(), 1)
	assert_eq(_player().coins, coins + 1800)
	assert_eq(_session.selected_ship, "ship_1", "selection falls back to a remaining ship")


func test_a_loaded_ship_cannot_be_sold() -> void:
	_press("Buy_salt")
	assert_true(_button("SellShip").disabled)


func test_save_and_load_menus_restore_the_game() -> void:
	_press("BuyKontor")
	_press("BuyShip_snaikka")
	_press("SaveGame")
	(_main.find_child("SaveName", true, false) as LineEdit).text = "Before selling"
	_press("ConfirmSave")
	assert_eq(_text("MessageLabel"), 'Game saved as "Before selling"')
	var coins := _player().coins
	_press("SellShip")
	_session.advance(30)
	_press("LoadGame")
	_press("Slot_Before_selling")
	assert_eq(_text("MessageLabel"), "Game loaded (day 1)")
	assert_eq(_player().coins, coins)
	assert_eq(_player().ships.size(), 2)
	assert_not_null(_player().get_kontor("lubeck"))
	assert_eq(_session.sim.world.hour, 0)
	var new_ship_id := _player().ships[1].id
	assert_not_null(
		_main.find_child("Ship_%s" % new_ship_id, true, false), "fleet list shows the loaded ships"
	)


func _player() -> TraderState:
	return _session.player()


func _ship() -> ShipState:
	return _player().get_ship("ship_1")


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
