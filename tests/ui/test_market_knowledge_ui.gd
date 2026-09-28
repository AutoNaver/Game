extends GutTest
## Market panels show unknown and stale reports without reading the hidden live market.

const MainScene := preload("res://ui/main.tscn")
const TestSaves := preload("res://tests/support/test_saves.gd")
const SmallWorld := preload("res://tests/support/small_world.gd")
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


func test_unknown_and_stale_markets_do_not_show_current_stock() -> void:
	_session.select_city("visby")
	assert_string_contains(_text("MarketSeen"), "Never visited")
	assert_eq(_text("Stock_grain"), "?")
	assert_eq(_text("BuyPrice_grain"), "-")
	assert_eq(_text("CityNeeds"), "Needs unknown")
	var city := _session.sim.world.get_city("visby")
	var report := MarketKnowledgeSystem.current_report(_session.sim.data, city, 0)
	_session.player().market_book["visby"] = report
	SmallWorld.set_stock(_session.sim, "visby", "grain", 0)
	_session.advance(Simulation.HOURS_PER_DAY)
	assert_string_contains(_text("MarketSeen"), "Last seen on day 1 (1d old)")
	assert_eq(_text("Stock_grain"), str(report.stock["grain"]))
	assert_false((_main.find_child("CityEvents", true, false) as Label).visible)


func test_planner_hides_unknown_destinations() -> void:
	SmallWorld.set_stock(_session.sim, "lubeck", "grain", 500)
	SmallWorld.set_stock(_session.sim, "danzig", "grain", 0)
	MarketKnowledgeSystem.observe_presence(_session.sim.data, _session.sim.world)
	_session.changed.emit()
	assert_false(_main.find_child("Idea_0", true, false).visible)
	var city := _session.sim.world.get_city("danzig")
	_session.player().market_book["danzig"] = MarketKnowledgeSystem.current_report(
		_session.sim.data, city, _session.sim.day()
	)
	_session.changed.emit()
	assert_string_contains(_text("PlannerNote"), "last known prices")


func _text(node_name: String) -> String:
	return (_main.find_child(node_name, true, false) as Label).text
