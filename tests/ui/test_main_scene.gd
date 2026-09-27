extends GutTest
## Smoke tests of the real main scene on the shipped data.

const MainScene := preload("res://ui/main.tscn")
const TestSaves := preload("res://tests/support/test_saves.gd")
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
	TestSaves.use(_session)
	_session.set_speed(0)
	await wait_process_frames(1)


func after_each() -> void:
	TestSaves.clear()


func test_starts_a_game_from_the_scenario() -> void:
	var start_coins := _session.sim.data.scenario.coins
	assert_eq(_text("Hud", "CoinsLabel"), "%d coins" % start_coins)
	assert_eq(_text("Hud", "DateLabel"), "Day 1, 00:00")
	assert_eq(_session.selected_city, "lubeck")
	assert_eq(_session.selected_ship, "ship_1")
	assert_eq(_text("SidePanel", "CityTitle"), "Lübeck")


func test_the_game_uses_the_shared_theme() -> void:
	assert_not_null(_main.theme)
	assert_eq((_find("Hud") as Control).theme_type_variation, UiStyle.HUD_PANEL)
	var title := _find("SidePanel").find_child("CityTitle", true, false) as Label
	assert_eq(title.theme_type_variation, UiStyle.TITLE_LABEL)
	assert_eq(title.get_theme_color("font_color"), UiStyle.GOLD)


func test_focused_buttons_show_a_visible_ring() -> void:
	var button := _find("Hud").find_children("*", "Button", true, false)[0] as Button
	var focus := button.get_theme_stylebox("focus") as StyleBoxFlat
	assert_not_null(focus, "focus style must be a visible box, not empty")
	assert_eq(focus.border_color, UiStyle.GOLD)
	assert_gt(focus.border_width_top, 0)


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


func test_switching_speed_keeps_partial_hours() -> void:
	_session.set_speed(1)
	# 0.4 s at 1x is 0.8 of an hour; switching to 2x must not throw that away.
	_session._process(0.4)
	_session.set_speed(2)
	_session._process(0.05)
	assert_eq(_session.sim.world.hour, 1)


func test_running_game_advances() -> void:
	_session.set_speed(4)
	await wait_seconds(0.5)
	assert_gt(_session.sim.world.hour, 0)


func test_clicking_a_city_on_the_map_selects_it() -> void:
	var map := _find("Map") as MapView
	var danzig := _session.sim.data.get_city("danzig")
	_click(map, map.to_screen(danzig.map_position) + Vector2(5, 5))
	assert_eq(_session.selected_city, "danzig")
	assert_eq(_text("SidePanel", "CityTitle"), "Danzig")


func test_map_uses_the_space_next_to_the_side_panel() -> void:
	var map := _find("Map") as MapView
	assert_gt(map.size.x, SCREEN_SIZE.x / 2.0)


func test_dragging_pans_instead_of_selecting() -> void:
	var map := _find("Map") as MapView
	map.zoom_at(map.size / 2.0, 3.0)
	var danzig := map.to_screen(_session.sim.data.get_city("danzig").map_position)
	map._gui_input(_button(danzig, true))
	var drag := InputEventMouseMotion.new()
	drag.button_mask = MOUSE_BUTTON_MASK_LEFT
	drag.position = danzig + Vector2(-40, 0)
	drag.relative = Vector2(-40, 0)
	map._gui_input(drag)
	map._gui_input(_button(drag.position, false))
	assert_eq(_session.selected_city, "lubeck", "a drag is not a click")
	var moved := map.to_screen(_session.sim.data.get_city("danzig").map_position)
	assert_almost_eq(moved.x, danzig.x - 40.0, 0.01)


func test_zoom_keeps_the_point_under_the_cursor() -> void:
	var map := _find("Map") as MapView
	var visby := _session.sim.data.get_city("visby").map_position
	var cursor := map.to_screen(visby)
	map.zoom_at(cursor, 2.0)
	assert_eq(map.zoom(), 2.0)
	assert_almost_eq(map.to_screen(visby).distance_to(cursor), 0.0, 0.01)


func test_zoom_and_pan_stay_within_the_map() -> void:
	var map := _find("Map") as MapView
	map.zoom_at(Vector2.ZERO, 0.1)
	assert_eq(map.zoom(), 1.0, "cannot zoom out past the map covering the view")
	map.zoom_at(Vector2.ZERO, 100.0)
	assert_eq(map.zoom(), MapView.MAX_ZOOM)
	map.pan(Vector2(10_000, 10_000))
	assert_eq(map.to_screen(Vector2.ZERO), Vector2.ZERO, "north-west corner stops at the edge")


func test_side_panel_scrolls_instead_of_stretching_the_screen() -> void:
	await wait_process_frames(2)
	var body := _find("Map").get_parent() as Control
	assert_true(body.size.y <= SCREEN_SIZE.y, "the body fits the window")
	assert_true(_find("SidePanel").find_child("Scroll", true, false) is ScrollContainer)


func test_open_sea_is_not_a_city() -> void:
	var map := _find("Map") as MapView
	assert_eq(map.city_at(Vector2(1, 1)), "")


func test_failed_command_shows_a_message() -> void:
	_session.execute(SailCommand.new(WorldState.PLAYER_ID, "ship_1", "lubeck"))
	assert_eq(_text("Hud", "MessageLabel"), "Adler is already in Lübeck")


func _button(at: Vector2, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = at
	return event


func _click(map: MapView, at: Vector2) -> void:
	map._gui_input(_button(at, true))
	map._gui_input(_button(at, false))


func _find(node_name: String) -> Node:
	return _main.find_child(node_name, true, false)


func _text(panel: String, label: String) -> String:
	return (_find(panel).find_child(label, true, false) as Label).text
