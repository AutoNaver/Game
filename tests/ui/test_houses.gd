extends GutTest
## The rival houses in the UI: the houses ranking, news of their expansion in the log, and their
## ships on the map.

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


func test_the_houses_button_toggles_the_ranking() -> void:
	var panel := _main.find_child("HousesPanel", true, false) as HousesPanel
	assert_false(panel.visible, "hidden until asked for")
	(_main.find_child("Houses", true, false) as Button).pressed.emit()
	assert_true(panel.visible)
	(_main.find_child("Houses", true, false) as Button).pressed.emit()
	assert_false(panel.visible)


func test_the_ranking_lists_every_house_by_worth() -> void:
	_session.houses_toggled.emit()
	var data := _session.sim.data
	_session.sim.world.get_trader("castorp").coins = 90_000
	_session.changed.emit()
	var rows := _main.find_child("HouseRows", true, false)
	assert_eq(rows.get_child_count(), 1 + data.rivals.size())
	var first := rows.get_child(0)
	assert_eq(first.name, "House_castorp", "the richest house comes first")
	var castorp := _session.sim.world.get_trader("castorp")
	var worth := HouseValue.net_worth(data, castorp)
	var cells: Array[String] = []
	for i in range(1, first.get_child_count()):
		cells.append((first.get_child(i) as Label).text)
	assert_eq(cells, [str(worth), "90000", "1", "0", "0"])
	var player_row := rows.get_node("House_player")
	assert_eq((player_row.find_child("Name", true, false) as Label).text, "You")


func test_rival_expansion_is_logged() -> void:
	var castorp := _session.sim.world.get_trader("castorp")
	castorp.coins = 100_000
	var ai := _session.sim.data.rival_ai
	_session.advance(ai.expansion_days * Simulation.HOURS_PER_DAY)
	var news: Array[String] = []
	for entry in _session.notification_log:
		if entry.contains("Castorp"):
			news.append(entry)
	assert_eq(news.size(), 1, "one expansion on the first expansion day: %s" % [news])
	var day := "Day %d: Castorp " % (ai.expansion_days + 1)
	assert_true(
		news[0].begins_with(day + "bought a ") or news[0].begins_with(day + "opened a "), news[0]
	)


func test_rival_ships_at_sea_are_drawn_in_their_colours() -> void:
	var map := _main.find_child("Map", true, false) as MapView
	_session.advance(2)
	var at_sea := 0
	for rival in _session.sim.data.rivals:
		for ship in _session.sim.world.get_trader(rival.id).ships:
			if not ship.is_docked():
				at_sea += 1
	assert_gt(at_sea, 0, "rivals sail in their first hours")
	assert_eq(MapView.house_color(_session.sim.data, "castorp"), Color("#5fb37a"))
	assert_eq(MapView.house_color(_session.sim.data, WorldState.PLAYER_ID), MapView.SHIP_COLOR)
	map.queue_redraw()
	await wait_process_frames(1)
