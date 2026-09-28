class_name ShipyardPanel
extends VBoxContainer
## The selected city's shipyard: buy new ships there, or sell the selected ship if it is docked
## here and empty.

var _session: GameSession
var _buy_buttons: Dictionary[String, Button] = {}
var _sell_button: Button = Button.new()


func setup(session: GameSession) -> void:
	_session = session
	add_child(UiStyle.label("Shipyard", UiStyle.HEADER_LABEL))
	var buy_row := HFlowContainer.new()
	buy_row.add_child(UiStyle.label("Buy:", UiStyle.MUTED_LABEL))
	for ship_type in _session.sim.data.ships:
		var button := Button.new()
		button.name = "BuyShip_%s" % ship_type.id
		button.text = "%s (%d)" % [ship_type.name, ship_type.price]
		button.pressed.connect(_buy.bind(ship_type.id))
		buy_row.add_child(button)
		_buy_buttons[ship_type.id] = button
	add_child(buy_row)
	_sell_button.name = "SellShip"
	_sell_button.pressed.connect(_sell)
	add_child(_sell_button)
	_session.changed.connect(refresh)
	refresh()


func refresh() -> void:
	for ship_type in _session.sim.data.ships:
		var button := _buy_buttons[ship_type.id]
		var locked := RankSystem.ship_error(_session.sim.data, _session.player(), ship_type)
		button.disabled = not locked.is_empty() or _session.player().coins < ship_type.price
		var stats := [ship_type.capacity, ship_type.speed]
		button.tooltip_text = "Holds %d units, sails %.1f km/h" % stats
		if not locked.is_empty():
			button.tooltip_text += "\nLocked: %s" % locked
	var ship := _session.player().get_ship(_session.selected_ship)
	_sell_button.visible = ship != null and ship.docked_at == _session.selected_city
	if _sell_button.visible:
		var price := SellShipCommand.resale_price(
			_session.sim.data, _session.sim.data.get_ship(ship.type_id)
		)
		_sell_button.text = "Sell %s (+%d)" % [ship.name, price]
		_sell_button.disabled = ship.cargo_total() > 0
		_sell_button.tooltip_text = "Unload it first" if _sell_button.disabled else ""


func _buy(ship_type_id: String) -> void:
	var command := BuyShipCommand.new(WorldState.PLAYER_ID, _session.selected_city, ship_type_id)
	if _session.execute(command):
		var ships := _session.player().ships
		_session.select_ship(ships[ships.size() - 1].id)


func _sell() -> void:
	_session.execute(SellShipCommand.new(WorldState.PLAYER_ID, _session.selected_ship))
