extends GutTest
## First-time hints follow the player's progress through the core loop.

const MainScene := preload("res://ui/main.tscn")
const SCREEN_SIZE: Vector2 = Vector2(1280, 720)
const PLAYER := WorldState.PLAYER_ID

var _main: Control
var _session: GameSession
var _hints: HintPanel


func before_each() -> void:
	_main = MainScene.instantiate()
	add_child_autofree(_main)
	_main.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_main.size = SCREEN_SIZE
	_session = _main.get_node("Session")
	_session.set_speed(0)
	_hints = _main.find_child("Hints", true, false) as HintPanel
	await wait_process_frames(1)


func test_hints_follow_the_core_loop() -> void:
	assert_true(_hints.visible)
	assert_eq(_hints.current_hint(), "buy")
	_session.execute(BuyCommand.new(PLAYER, "ship_1", "salt", 20))
	assert_eq(_hints.current_hint(), "sail")
	_session.execute(SailCommand.new(PLAYER, "ship_1", "danzig"))
	assert_eq(_hints.current_hint(), "sell")
	_session.player().coins += 10_000
	_session.changed.emit()
	assert_eq(_hints.current_hint(), "kontor")
	_session.execute(BuyKontorCommand.new(PLAYER, "lubeck"))
	assert_eq(_hints.current_hint(), "workshop")
	_session.execute(BuildWorkshopCommand.new(PLAYER, "lubeck", "brewery"))
	assert_eq(_hints.current_hint(), "")
	assert_false(_hints.visible)


func test_dismissing_shows_the_next_hint() -> void:
	(_hints.find_child("DismissHint", true, false) as Button).pressed.emit()
	assert_eq(_hints.current_hint(), "sail")
	assert_string_contains((_hints.find_child("HintText", true, false) as Label).text, "Sail to")


func test_hiding_hides_all_hints() -> void:
	(_hints.find_child("HideHints", true, false) as Button).pressed.emit()
	assert_false(_hints.visible)
	_session.changed.emit()
	assert_false(_hints.visible, "stays hidden")
