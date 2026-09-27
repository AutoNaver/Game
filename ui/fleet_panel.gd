class_name FleetPanel
extends VBoxContainer
## The player's ships: where each one is and what it carries. Click a ship to select it; a docked
## selected ship can be sent to another city with the "Sail to" buttons.

var _session: GameSession
var _ship_list: VBoxContainer = VBoxContainer.new()
var _ship_buttons: Dictionary[String, Button] = {}
var _sail_row: HFlowContainer = HFlowContainer.new()
var _sail_buttons: Dictionary[String, Button] = {}


func setup(session: GameSession) -> void:
	_session = session
	var title := Label.new()
	title.text = "Fleet"
	title.add_theme_font_size_override("font_size", 20)
	add_child(title)
	add_child(_ship_list)
	var sail_label := Label.new()
	sail_label.text = "Sail to:"
	_sail_row.add_child(sail_label)
	for city in _session.sim.data.cities:
		var button := Button.new()
		button.name = "Sail_%s" % city.id
		button.pressed.connect(_sail.bind(city.id))
		_sail_row.add_child(button)
		_sail_buttons[city.id] = button
	add_child(_sail_row)
	_session.changed.connect(refresh)
	refresh()


func refresh() -> void:
	var ships := _session.player().ships
	if _ship_buttons.size() != ships.size():
		_rebuild_ship_buttons(ships)
	for ship in ships:
		var button := _ship_buttons[ship.id]
		button.text = _describe(ship)
		button.set_pressed_no_signal(ship.id == _session.selected_ship)
	var selected := _session.player().get_ship(_session.selected_ship)
	_sail_row.visible = selected != null and selected.is_docked()
	if not _sail_row.visible:
		return
	var ship_type := _session.sim.data.get_ship(selected.type_id)
	for city in _session.sim.data.cities:
		var button := _sail_buttons[city.id]
		button.visible = city.id != selected.docked_at
		var hours := Navigation.travel_hours(
			_session.sim.data, ship_type, selected.docked_at, city.id
		)
		button.text = "%s (%dh)" % [city.name, hours]


func _rebuild_ship_buttons(ships: Array[ShipState]) -> void:
	for child in _ship_list.get_children():
		child.queue_free()
	_ship_buttons.clear()
	for ship in ships:
		var button := Button.new()
		button.name = "Ship_%s" % ship.id
		button.toggle_mode = true
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_select.bind(ship.id))
		_ship_list.add_child(button)
		_ship_buttons[ship.id] = button


func _describe(ship: ShipState) -> String:
	var data := _session.sim.data
	var ship_type := data.get_ship(ship.type_id)
	var where := ""
	if ship.is_docked():
		where = "in %s" % data.get_city(ship.docked_at).name
	else:
		var hours_left := ship.voyage_hours - ship.hours_sailed
		where = "to %s, %dh left" % [data.get_city(ship.destination).name, hours_left]
	var cargo := "cargo %d/%d" % [ship.cargo_total(), ship_type.capacity]
	return "%s (%s), %s, %s" % [ship.name, ship_type.name, where, cargo]


func _select(ship_id: String) -> void:
	_session.select_ship(ship_id)
	var ship := _session.player().get_ship(ship_id)
	if ship.is_docked():
		_session.select_city(ship.docked_at)


func _sail(city_id: String) -> void:
	_session.execute(SailCommand.new(WorldState.PLAYER_ID, _session.selected_ship, city_id))
