extends GutTest
## Deals with other houses in the houses panel on the shipped data (ADR 0016): buying from a
## bankrupt house's sale, answering a rival's offer, and buying out a house, all through buttons.

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
	_session.player().coins = 1_000_000
	_session.houses_toggled.emit()
	await wait_process_frames(1)


func after_each() -> void:
	TestSaves.clear()


func test_buying_a_ship_from_a_bankrupt_house() -> void:
	var castorp := _session.sim.world.get_trader("castorp")
	var ship := castorp.ships[0]
	AcquisitionSystem.declare_bankrupt(_session.sim.data, _session.sim.world, castorp, 0)
	_session.changed.emit()
	assert_eq(
		(_main.find_child("House_castorp", true, false).get_node("Rank") as Label).text, "Bankrupt"
	)
	_press("Deal_castorp")
	var buy := _button("BuyAsset_%s" % ship.id)
	assert_true(buy.disabled)
	assert_string_contains(buy.tooltip_text, "A Skipper owns at most 1 ship")
	_session.player().rank_id = "merchant"
	_session.changed.emit()
	var price := AcquisitionSystem.asking_price(
		_session.sim.data, castorp, OfferState.Kind.SHIP, ship.id
	)
	_press("BuyAsset_%s" % ship.id)
	assert_not_null(_session.player().get_ship(ship.id))
	assert_eq(
		_session.notification_log[-1],
		"Day 1: You bought the Cog %s from Castorp for %d" % [ship.name, price]
	)


func test_accepting_a_rivals_offer_for_a_kontor() -> void:
	_press("BuyKontor")
	var world := _session.sim.world
	var castorp := world.get_trader("castorp")
	castorp.coins = 100_000
	castorp.reputation["lubeck"] = _session.sim.data.reputation.kontor_abroad
	world.offers.append(
		OfferState.new("offer_1", "castorp", OfferState.Kind.KONTOR, "lubeck", 900, 5)
	)
	world.next_offer_number = 2
	_session.changed.emit()
	assert_string_contains(
		(_main.find_child("Offers", true, false) as VBoxContainer).get_child(1).get_child(0).text,
		"Castorp offers 900 for the kontor in Lübeck (until day 6)"
	)
	var coins := _session.player().coins
	_press("Accept_offer_1")
	assert_null(_session.player().get_kontor("lubeck"))
	assert_not_null(castorp.get_kontor("lubeck"))
	assert_eq(_session.player().coins, coins + 900)
	assert_true(world.offers.is_empty())


func test_buying_out_a_house() -> void:
	_press("Deal_wulflam")
	var buy_out := _button("BuyOut_wulflam")
	assert_true(buy_out.disabled)
	assert_eq(buy_out.tooltip_text, "Buy-outs need the rank Alderman")
	_session.player().rank_id = "alderman"
	_session.changed.emit()
	var price := AcquisitionSystem.buy_out_price(
		_session.sim.data, _session.sim.world.get_trader("wulflam")
	)
	_press("BuyOut_wulflam")
	assert_null(_session.sim.world.get_trader("wulflam"))
	assert_null(_main.find_child("House_wulflam", true, false))
	assert_eq(_session.notification_log[-1], "Day 1: You bought out Wulflam for %d" % price)


func _button(node_name: String) -> Button:
	var button := _main.find_child(node_name, true, false) as Button
	assert_not_null(button, "button %s exists" % node_name)
	return button


func _press(node_name: String) -> void:
	var button := _button(node_name)
	assert_false(button.disabled, "%s is enabled: %s" % [node_name, button.tooltip_text])
	button.pressed.emit()
