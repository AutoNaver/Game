extends GutTest
## Smoke tests of the real main scene on the shipped data.

const MainScene := preload("res://ui/main.tscn")
## The headless test window is tiny; lay the scene out as on a real screen.
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


func test_starts_a_game_from_the_scenario() -> void:
	var start_coins := _session.sim.data.scenario.coins
	assert_eq(_text("Hud", "CoinsLabel"), "%d coins" % start_coins)
	assert_eq(_text("Hud", "DateLabel"), "Day 1, 00:00")
	assert_eq(_session.selected_city, "lubeck")
	assert_eq(_session.selected_ship, "ship_1")
	assert_eq(_text("SidePanel", "CityTitle"), "Lübeck")


func test_time_advances_and_the_hud_follows() -> void:
	_session.advance(Simulation.HOURS_PER_DAY + 5)
	assert_eq(_text("Hud", "DateLabel"), "Day 2, 05:00")


func test_paused_game_does_not_advance() -> void:
	await wait_process_frames(5)
	assert_eq(_session.sim.world.hour, 0)


func test_only_the_active_speed_button_is_pressed() -> void:
	_session.set_speed(2)
	var pressed: Array[String] = []
	for button in _find("Hud").find_children("*", "Button", true, false):
		if (button as Button).button_pressed:
			pressed.append((button as Button).text)
	assert_eq(pressed, ["2×"])


func test_running_game_advances() -> void:
	_session.set_speed(4)
	await wait_seconds(0.5)
	assert_gt(_session.sim.world.hour, 0)


func test_clicking_a_city_on_the_map_selects_it() -> void:
	var map := _find("Map") as MapView
	var danzig := _session.sim.data.get_city("danzig")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = map.to_screen(danzig.map_position) + Vector2(5, 5)
	map._gui_input(click)
	assert_eq(_session.selected_city, "danzig")
	assert_eq(_text("SidePanel", "CityTitle"), "Danzig")


func test_map_uses_the_space_next_to_the_side_panel() -> void:
	var map := _find("Map") as MapView
	assert_gt(map.size.x, SCREEN_SIZE.x / 2.0)


func test_open_sea_is_not_a_city() -> void:
	var map := _find("Map") as MapView
	assert_eq(map.city_at(Vector2(1, 1)), "")


func test_failed_command_shows_a_message() -> void:
	_session.execute(SailCommand.new(WorldState.PLAYER_ID, "ship_1", "lubeck"))
	assert_eq(_text("Hud", "MessageLabel"), "Adler is already in Lübeck")


func _find(node_name: String) -> Node:
	return _main.find_child(node_name, true, false)


func _text(panel: String, label: String) -> String:
	return (_find(panel).find_child(label, true, false) as Label).text
