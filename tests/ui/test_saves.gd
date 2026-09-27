extends GutTest
## Named save slots, the autosave and the start screen, through the real UI.

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
	_start_screen().show_screen()
	await wait_process_frames(1)


func after_each() -> void:
	TestSaves.clear()


func test_the_start_screen_opens_paused_and_new_game_runs() -> void:
	assert_true(_start_screen().visible)
	assert_eq(_session.speed, 0)
	assert_true(_button("Continue").disabled, "no saves yet")
	_press("NewGame")
	assert_false(_start_screen().visible)
	assert_eq(_session.speed, 1)


func test_continue_loads_the_newest_save() -> void:
	_session.advance(5)
	assert_true(_session.save_game("Harbour"))
	_session.advance(30)
	_start_screen().show_screen()
	assert_eq(_button("Continue").text, "Continue (Harbour)")
	_press("Continue")
	assert_eq(_session.sim.world.hour, 5)
	assert_false(_start_screen().visible)
	assert_eq(_session.speed, 1)


func test_loading_from_the_start_screen() -> void:
	assert_true(_session.save_game("First"))
	_press("LoadFromStart")
	assert_true(_menu().visible)
	_press("Slot_First")
	assert_false(_menu().visible)
	assert_false(_start_screen().visible)
	assert_eq(_session.speed, 1)


func test_the_save_menu_pauses_and_restores_the_speed() -> void:
	_press("NewGame")
	_session.set_speed(2)
	_press("SaveGame")
	assert_true(_menu().visible)
	assert_eq(_session.speed, 0)
	_press("CloseSaveMenu")
	assert_false(_menu().visible)
	assert_eq(_session.speed, 2)


func test_bad_names_are_refused_in_the_menu() -> void:
	_press("NewGame")
	_press("SaveGame")
	_name_edit().text = "../escape"
	_press("ConfirmSave")
	assert_true(_menu().visible)
	assert_eq(_text("SaveMenuNote"), "Save names can only use letters, digits, spaces, - and _")
	assert_eq(Array(_session.list_saves()), [])


func test_picking_a_save_fills_in_its_name_to_overwrite_it() -> void:
	assert_true(_session.save_game("Old"))
	_press("NewGame")
	_session.advance(10)
	_press("SaveGame")
	_press("Slot_Old")
	assert_eq(_name_edit().text, "Old")
	_press("ConfirmSave")
	assert_eq(Array(_session.list_saves()), ["Old"])
	var loader := SaveGame.new()
	var world := loader.load_file(_session.sim.data, SaveGame.path_for("Old", TestSaves.DIR))
	assert_eq(world.hour, 10)


func test_the_game_autosaves_every_few_days() -> void:
	_press("NewGame")
	_session.advance(Simulation.HOURS_PER_DAY * GameSession.AUTOSAVE_DAYS - 1)
	assert_eq(Array(_session.list_saves()), [])
	_session.advance(1)
	assert_eq(Array(_session.list_saves()), [GameSession.AUTOSAVE_SLOT])
	assert_eq(_session.save_slot, "", "the autosave isn't offered as the player's slot")


func test_loading_starts_a_fresh_log() -> void:
	assert_true(_session.save_game("Clean"))
	_session.notify("Adler arrived in Danzig")
	assert_true(_session.load_game("Clean"))
	assert_eq(Array(_session.notification_log), [])
	assert_eq(_text("LogEntries"), "Nothing yet.")


func _start_screen() -> StartScreen:
	return _main.get_node("StartScreen")


func _menu() -> SaveMenu:
	return _main.get_node("SaveMenu")


func _name_edit() -> LineEdit:
	return _main.find_child("SaveName", true, false)


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
