extends GutTest
## The visual town shares the live game session without changing the simulation or save shape.

const MainScene := preload("res://ui/main.tscn")
const TestSaves := preload("res://tests/support/test_saves.gd")
const SCREEN_SIZE: Vector2 = Vector2(1280, 720)

var _main: Control
var _session: GameSession
var _city: CityView
var _map: MapView
var _toggle: Button


func before_each() -> void:
	_main = MainScene.instantiate()
	add_child_autofree(_main)
	_main.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_main.size = SCREEN_SIZE
	_session = _main.get_node("Session")
	TestSaves.use(_session)
	_session.set_speed(0)
	_city = _main.find_child("CityView", true, false) as CityView
	_map = _main.find_child("Map", true, false) as MapView
	_toggle = _main.find_child("ToggleCityView", true, false) as Button
	await wait_process_frames(2)


func after_each() -> void:
	TestSaves.clear()


func test_enter_and_leave_preserves_clock_and_save_state() -> void:
	var before := SaveGame.to_dict(_session.sim.world)
	assert_false(_city.visible)
	assert_false(_toggle.disabled)
	assert_eq(_toggle.text, "Enter Lübeck")
	_toggle.pressed.emit()
	assert_true(_city.visible)
	assert_false(_map.visible)
	assert_eq(_toggle.text, "Sea map")
	_toggle.pressed.emit()
	assert_false(_city.visible)
	assert_true(_map.visible)
	assert_eq(SaveGame.to_dict(_session.sim.world), before)


func test_remote_city_requires_presence() -> void:
	_session.select_city("visby")
	assert_true(_toggle.disabled)
	assert_false(_city.visible)
	_session.player().person_city_id = "visby"
	_session.changed.emit()
	assert_false(_toggle.disabled)
	_toggle.pressed.emit()
	assert_true(_city.visible)
	assert_eq(_session.selected_city, "visby")


func test_departing_last_ship_returns_to_map() -> void:
	_toggle.pressed.emit()
	assert_true(_city.visible)
	assert_true(_session.execute(SailCommand.new(WorldState.PLAYER_ID, "ship_1", "danzig")))
	assert_false(_city.visible)
	assert_true(_map.visible)
	assert_true(_toggle.disabled)


func test_landmarks_are_clickable_and_focus_existing_controls() -> void:
	_toggle.pressed.emit()
	await wait_process_frames(1)
	for section in CityView.LANDMARKS:
		assert_eq(_city.landmark_at(_city.landmark_center(section)), section)
	var scroll := _main.find_child("Scroll", true, false) as ScrollContainer
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = _city.landmark_center("shipyard")
	_city._gui_input(release)
	await wait_process_frames(2)
	assert_gt(scroll.scroll_vertical, 0, "shipyard click brings its existing controls into view")
	release.position = _city.landmark_center("town_hall")
	_city._gui_input(release)
	await wait_process_frames(2)
	assert_lt(scroll.scroll_vertical, 30, "town hall click returns to city information")


func test_all_nine_city_layouts_have_distinct_landmarks() -> void:
	var markets: Array[Vector2] = []
	for city in _session.sim.data.cities:
		_session.player().person_city_id = city.id
		_session.select_city(city.id)
		_toggle.pressed.emit()
		assert_true(_city.visible, "%s has a town view" % city.id)
		for section in CityView.LANDMARKS:
			var centre := _city.landmark_center(section)
			assert_true(Rect2(Vector2.ZERO, _city.size).has_point(centre))
		markets.append(_city.landmark_center("market"))
		_toggle.pressed.emit()
	assert_eq(markets.size(), 9)
	for i in markets.size():
		for j in range(i + 1, markets.size()):
			assert_ne(markets[i], markets[j], "city market positions distinguish the layouts")


func test_workshops_appear_and_disappear_without_saved_plot_state() -> void:
	_toggle.pressed.emit()
	_session.player().coins = 20_000
	assert_true(_session.execute(BuyKontorCommand.new(WorldState.PLAYER_ID, "lubeck")))
	assert_true(
		_session.execute(BuildWorkshopCommand.new(WorldState.PLAYER_ID, "lubeck", "brewery"))
	)
	var workshop := _session.player().get_kontor("lubeck").workshops[0]
	assert_true(_city.workshop_plots().has(workshop.id))
	var plot: Vector2i = _city.workshop_plots()[workshop.id]
	assert_true(_session.save_game("cityview"))
	assert_true(_session.load_game("cityview"))
	assert_eq(_city.workshop_plots()[workshop.id], plot)
	assert_true(
		_session.execute(CloseWorkshopCommand.new(WorldState.PLAYER_ID, "lubeck", workshop.id))
	)
	assert_false(_city.workshop_plots().has(workshop.id))


func test_new_workshops_never_move_older_ones() -> void:
	_session.player().coins = 20_000
	assert_true(_session.execute(BuyKontorCommand.new(WorldState.PLAYER_ID, "lubeck")))
	var workshops := _session.player().get_kontor("lubeck").workshops
	workshops.append(WorkshopState.new("workshop_5", "brewery"))
	var plot: Vector2i = _city.workshop_plots()["workshop_5"]
	# Ids past 99 sort before "workshop_5" as text; some of them hash to its plot.
	for number in range(6, 1000):
		workshops.append(WorkshopState.new("workshop_%d" % number, "brewery"))
		if _city.workshop_plots()["workshop_5"] != plot:
			fail_test("workshop_%d moved workshop_5" % number)
			return
		workshops.pop_back()
	pass_test("workshop_5 kept its plot")


func test_drag_pans_zoom_keeps_cursor_anchor_and_home_resets() -> void:
	_toggle.pressed.emit()
	var before := SaveGame.to_dict(_session.sim.world)
	var anchor := _city.landmark_center("market")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.position = anchor
	_city._gui_input(wheel)
	assert_almost_eq(_city.landmark_center("market"), anchor, Vector2(0.01, 0.01))
	watch_signals(_city)
	_drag(anchor, Vector2(53, 31))
	assert_almost_eq(_city.landmark_center("market"), anchor + Vector2(53, 31), Vector2(0.01, 0.01))
	assert_signal_not_emitted(_city, "landmark_selected", "a drag pans instead of selecting")
	for section in CityView.LANDMARKS:
		assert_eq(_city.landmark_at(_city.landmark_center(section)), section)
	var home := InputEventKey.new()
	home.keycode = KEY_HOME
	home.pressed = true
	_city._gui_input(home)
	assert_eq(_city.landmark_center("market"), anchor)
	assert_eq(SaveGame.to_dict(_session.sim.world), before)


func test_click_without_travel_selects_landmark() -> void:
	_toggle.pressed.emit()
	watch_signals(_city)
	_drag(_city.landmark_center("kontor"), Vector2(2, 1))
	assert_signal_emitted_with_parameters(_city, "landmark_selected", ["kontor"])


func test_camera_limits_keep_the_town_in_view() -> void:
	_toggle.pressed.emit()
	var anchor := _city.landmark_center("market")
	_city.zoom_at(anchor, 1000)
	assert_eq(_city._zoom, CityView.MAX_ZOOM)
	_city.zoom_at(anchor, 0.0001)
	assert_eq(_city._zoom, CityView.MIN_ZOOM)
	_city.zoom_at(anchor, 1000)
	var centre := _city.size * 0.5
	for direction: Vector2 in [Vector2(1, 1), Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1)]:
		_drag(centre, direction * 100_000)
		var town := Rect2(_city._tile_center(0, 0), Vector2.ZERO)
		for corner: Vector2 in [Vector2(13, 0), Vector2(0, 13), Vector2(13, 13)]:
			town = town.expand(_city._tile_center(corner.x, corner.y))
		# has_point excludes the far edges, where the clamp stops exactly.
		assert_true(
			town.grow(0.5).has_point(centre), "view centre stays over the town after %s" % direction
		)
	_toggle.pressed.emit()
	_toggle.pressed.emit()
	assert_eq(_city.landmark_center("market"), anchor)
	assert_eq(_city._zoom, 1.0)


func test_whole_town_fits_on_entry_at_1280x720() -> void:
	_toggle.pressed.emit()
	var view := Rect2(Vector2.ZERO, _city.size)
	# North corner with room for the tallest roofs above it, and the harbour wall at the front.
	var roofs := _city._tile_center(0, 0) - Vector2(0, _city._tile_width() * 1.4)
	assert_true(view.has_point(roofs), "back roofs are below the top edge")
	assert_true(view.has_point(_city._tile_center(13.5, 13.5)), "front wall is on screen")
	assert_true(view.has_point(_city._tile_center(0, 13.5)), "west wall is on screen")


## Presses the left button at `from`, moves by `travel`, and releases there.
func _drag(from: Vector2, travel: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = from
	_city._gui_input(press)
	var motion := InputEventMouseMotion.new()
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	motion.position = from + travel
	motion.relative = travel
	_city._gui_input(motion)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = from + travel
	_city._gui_input(release)
