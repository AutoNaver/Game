extends GutTest
## The notification log: ship arrivals and stopped workshops, and pausing when a ship arrives.

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


func test_an_arrival_is_logged_and_pauses_the_game() -> void:
	var hours := _sail_to("danzig")
	_session.set_speed(1)
	_session.advance(hours)
	assert_eq(_session.speed, 0, "paused on arrival")
	assert_eq(_session.notification_log[-1], "Day %d: Adler arrived in Danzig" % _day())
	assert_string_contains(_entries(), "Adler arrived in Danzig")
	assert_eq(_text("MessageLabel"), "Adler arrived in Danzig")


func test_arrivals_can_leave_the_game_running() -> void:
	var toggle: CheckBox = _main.find_child("PauseOnArrival", true, false)
	assert_true(toggle.button_pressed)
	toggle.button_pressed = false
	assert_false(_session.pause_on_arrival)
	var hours := _sail_to("danzig")
	_session.set_speed(2)
	_session.advance(hours)
	assert_eq(_session.speed, 2)
	assert_string_contains(_entries(), "Adler arrived in Danzig")


func test_a_stopped_workshop_is_logged_once() -> void:
	_session.sim.world.player().coins = 50_000
	_press("BuyKontor")
	_press("Build_brewery")
	_session.advance(Simulation.HOURS_PER_DAY)
	var entry := "Day %d: Brewery in Lübeck: idle, needs Grain" % _day()
	assert_eq(Array(_session.notification_log), [entry])
	_session.advance(Simulation.HOURS_PER_DAY * 2)
	assert_eq(_session.notification_log.size(), 1, "still idle for the same reason")


func test_the_log_keeps_the_latest_entries() -> void:
	for i in GameSession.MAX_LOG + 5:
		_session.notify("entry %d" % i)
	assert_eq(_session.notification_log.size(), GameSession.MAX_LOG)
	assert_string_ends_with(_session.notification_log[-1], "entry %d" % (GameSession.MAX_LOG + 4))
	var shown := _entries().split("\n")
	assert_eq(shown.size(), LogPanel.VISIBLE_ENTRIES)


## Sends the starting ship from Lübeck and returns the voyage's hours.
func _sail_to(city_id: String) -> int:
	_press("Sail_%s" % city_id)
	return _session.player().get_ship("ship_1").voyage_hours


func _day() -> int:
	return _session.sim.day() + 1


func _entries() -> String:
	return _text("LogEntries")


func _press(node_name: String) -> void:
	var button := _main.find_child(node_name, true, false) as Button
	assert_not_null(button, "button %s exists" % node_name)
	button.pressed.emit()


func _text(node_name: String) -> String:
	return (_main.find_child(node_name, true, false) as Label).text
