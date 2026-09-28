extends GutTest
## World events and spoilage in the UI (ADR 0011): notifications, the city panel, the price
## tooltip and slowed ships, on the shipped data with the event chances forced.

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


## Only `type_id` can start, and it starts every day where it can.
func _only(type_id: String) -> EventDef:
	for event_type in _session.sim.data.events:
		event_type.chance_per_day = 1.0 if event_type.id == type_id else 0.0
	return _session.sim.data.get_event(type_id)


func _no_events() -> void:
	for event_type in _session.sim.data.events:
		event_type.chance_per_day = 0.0


func test_events_are_announced_shown_in_the_city_and_their_end_logged() -> void:
	_only("war")
	_session.advance(Simulation.HOURS_PER_DAY)
	_no_events()
	var event := _session.sim.world.events[0]
	var headline := EventText.headline(_session.sim.data, event)
	assert_string_contains(_text("LogEntries"), headline + ": overland imports down to 20%")
	_session.select_city(event.city_id)
	if not MarketKnowledgeSystem.has_presence(_session.sim.data, _session.player(), event.city_id):
		assert_false(_label("CityEvents").visible, "remote events are not live market knowledge")
		assert_eq(
			_session.sim.execute(BuyKontorCommand.new(WorldState.PLAYER_ID, event.city_id)), ""
		)
		_session.changed.emit()
	assert_true(_label("CityEvents").visible)
	assert_string_contains(_text("CityEvents"), "War: overland imports down to 20%")
	var tooltip := (_main.find_child("Good_grain", true, false) as Label).tooltip_text
	assert_string_contains(tooltip, headline)
	_session.advance((event.end_day - _session.sim.day()) * Simulation.HOURS_PER_DAY)
	assert_string_contains(_text("LogEntries"), "Over: " + headline)
	assert_false(_label("CityEvents").visible)


func test_fires_report_the_players_losses() -> void:
	_no_events()
	_press("BuyKontor")
	_press("TradeWithKontor")
	_press("Quantity_25")
	_press("Buy_salt")
	_only("fire")
	_session.advance(Simulation.HOURS_PER_DAY)
	var entries := _text("LogEntries")
	assert_string_contains(entries, "Fire in Lübeck")
	assert_string_contains(entries, "Fire destroyed in your kontor in Lübeck: 6 Salt")


func test_large_spoilage_is_reported_and_small_spoilage_is_not() -> void:
	_no_events()
	_press("Quantity_25")
	_press("Buy_fish")
	_session.advance(Simulation.HOURS_PER_DAY)
	assert_false(_text("LogEntries").contains("Spoiled"), "half a fish a day is too little")
	_session.sim.data.get_good("fish").spoilage_per_day = 0.2
	_session.advance(Simulation.HOURS_PER_DAY)
	assert_string_contains(_text("LogEntries"), "Spoiled aboard Adler: 5 Fish")


func test_storms_show_on_the_ship_and_the_manifest_warns_of_spoilage() -> void:
	_no_events()
	_press("Quantity_10")
	_press("Buy_fish")
	assert_string_contains(_text("CargoManifest"), "coins · spoils 0.2 a day")
	_press("Sail_visby")
	var world := _session.sim.world
	world.events.append(
		EventState.new("event_%d" % world.next_event_number, "storm", "visby", 0, 3)
	)
	world.next_event_number += 1
	_session.advance(2)
	var button := _main.find_child("Ship_ship_1", true, false) as Button
	assert_string_contains(button.text, "at 1/2 speed (storm)")


func _press(node_name: String) -> void:
	var button := _main.find_child(node_name, true, false) as Button
	assert_not_null(button, "button %s exists" % node_name)
	button.pressed.emit()


func _label(node_name: String) -> Label:
	return _main.find_child(node_name, true, false) as Label


func _text(node_name: String) -> String:
	return _label(node_name).text
