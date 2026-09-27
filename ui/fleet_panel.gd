class_name FleetPanel
extends VBoxContainer
## The player's ships: where each one is and what it carries. Click a ship to select it; a docked
## selected ship can be sent to another city with the "Sail to" buttons, and any selected ship can
## be put on one of the player's trade routes. The cargo manifest values goods only at a port the
## ship has reached, so it does not reveal a distant market ahead of the ship.

var _session: GameSession
var _ship_list: VBoxContainer = VBoxContainer.new()
var _ship_buttons: Dictionary[String, Button] = {}
var _summary: Label = Label.new()
var _manifest: Label = Label.new()
var _sail_row: HFlowContainer = HFlowContainer.new()
var _sail_buttons: Dictionary[String, Button] = {}
var _route_row: HBoxContainer = HBoxContainer.new()
var _route_picker: OptionButton = OptionButton.new()
var _route_status: Label = Label.new()
## Route ids behind the picker's items after "(no route)", to rebuild only when routes change.
var _picker_routes: PackedStringArray = []


func setup(session: GameSession) -> void:
	_session = session
	add_child(UiStyle.label("Fleet", UiStyle.HEADER_LABEL))
	_summary.name = "FleetSummary"
	_summary.theme_type_variation = UiStyle.MUTED_LABEL
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD
	add_child(_summary)
	add_child(_ship_list)
	_manifest.name = "CargoManifest"
	_manifest.autowrap_mode = TextServer.AUTOWRAP_WORD
	add_child(_manifest)
	_sail_row.add_child(UiStyle.label("Sail to:", UiStyle.MUTED_LABEL))
	for city in _session.sim.data.cities:
		var button := Button.new()
		button.name = "Sail_%s" % city.id
		button.pressed.connect(_sail.bind(city.id))
		_sail_row.add_child(button)
		_sail_buttons[city.id] = button
	add_child(_sail_row)
	_route_row.add_child(UiStyle.label("Route:", UiStyle.MUTED_LABEL))
	_route_picker.name = "ShipRoute"
	_route_picker.item_selected.connect(_on_route_picked)
	_route_row.add_child(_route_picker)
	add_child(_route_row)
	_route_status.name = "ShipRouteStatus"
	_route_status.theme_type_variation = UiStyle.MUTED_LABEL
	_route_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	add_child(_route_status)
	_session.changed.connect(refresh)
	refresh()


func refresh() -> void:
	var ships := _session.player().ships
	_refresh_summary(ships)
	# Rebuild when the set of ships changed (bought, sold or a game loaded), not just the count.
	var ids := PackedStringArray()
	for ship in ships:
		ids.append(ship.id)
	if ids != PackedStringArray(_ship_buttons.keys()):
		_rebuild_ship_buttons(ships)
	for ship in ships:
		var button := _ship_buttons[ship.id]
		button.text = _describe(ship)
		button.set_pressed_no_signal(ship.id == _session.selected_ship)
	var selected := _session.player().get_ship(_session.selected_ship)
	_refresh_manifest(selected)
	_refresh_route(selected)
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


func _refresh_summary(ships: Array[ShipState]) -> void:
	var docked := 0
	var sailing := 0
	var on_routes := 0
	var loaded := 0
	var capacity := 0
	for ship in ships:
		if ship.is_docked():
			docked += 1
		else:
			sailing += 1
		if not ship.route_id.is_empty():
			on_routes += 1
		loaded += ship.cargo_total()
		capacity += _session.sim.data.get_ship(ship.type_id).capacity
	_summary.text = (
		"Ships %d · Docked %d · Sailing %d · Routes %d\nCargo %d/%d"
		% [ships.size(), docked, sailing, on_routes, loaded, capacity]
	)


func _refresh_manifest(ship: ShipState) -> void:
	if ship == null:
		_manifest.text = "Select a ship to see its cargo."
		return
	var lines: PackedStringArray = ["%s cargo:" % ship.name]
	if ship.cargo_total() == 0:
		lines.append("Empty hold")
		_manifest.text = "\n".join(lines)
		return
	var port: CityState = null
	if ship.is_docked():
		port = _session.sim.world.get_city(ship.docked_at)
	var total := 0
	for good in _session.sim.data.goods:
		var units := ship.cargo_of(good.id)
		if units == 0:
			continue
		var line := "%d %s" % [units, good.name]
		if port != null:
			var economy := _session.sim.data.economy
			var revenue := batched_revenue(economy, port, good, units, _session.trade_quantity)
			line += " · %d coins" % revenue
			total += revenue
		lines.append(line)
	if port != null:
		var batch := _session.trade_quantity
		lines.append("Sell here now, %d at a time: %d coins total" % [batch, total])
	else:
		lines.append("Sale prices available when docked")
	_manifest.text = "\n".join(lines)


## Coins for selling `units` of `good` in `city` with Sell clicks of `batch` units each, as the
## market panel sells them: each click is priced and rounded down on its own (SellCommand), so
## small batches can pay a coin or two less than one large sale.
static func batched_revenue(
	economy: EconomyDef, city: CityState, good: GoodDef, units: int, batch: int
) -> int:
	var target := CityEconomy.target_stock(economy, city, good)
	var stock: int = city.stock[good.id]
	var total := 0
	var left := units
	while left > 0:
		var quantity := mini(batch, left)
		total += Pricing.sell_revenue(economy, good.base_price, target, stock, quantity)
		stock += quantity
		left -= quantity
	return total


func _refresh_route(ship: ShipState) -> void:
	var routes := _session.player().routes
	_route_row.visible = ship != null and not routes.is_empty()
	_route_status.visible = ship != null and not ship.route_id.is_empty()
	if not _route_row.visible:
		return
	var ids := PackedStringArray()
	for route in routes:
		ids.append(route.id)
	if ids != _picker_routes or _route_picker.item_count == 0:
		_route_picker.clear()
		_route_picker.add_item("(no route)")
		for route in routes:
			_route_picker.add_item(route.name)
		_picker_routes = ids
	for i in routes.size():
		_route_picker.set_item_text(i + 1, routes[i].name)
	_route_picker.select(ids.find(ship.route_id) + 1)
	if ship.route_id.is_empty():
		return
	var route := _session.player().get_route(ship.route_id)
	var stop := route.stops[ship.route_stop]
	var status := (
		"Next stop %d of %d: %s"
		% [ship.route_stop + 1, route.stops.size(), _session.sim.data.get_city(stop.city_id).name]
	)
	if not ship.route_note.is_empty():
		status += "\nLast stop: %s" % ship.route_note
	_route_status.text = status


func _on_route_picked(item: int) -> void:
	var route_id := "" if item == 0 else _picker_routes[item - 1]
	var ship := _session.player().get_ship(_session.selected_ship)
	if ship == null or ship.route_id == route_id:
		return
	_session.execute(AssignRouteCommand.new(WorldState.PLAYER_ID, ship.id, route_id))


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
	var text := "%s (%s), %s, %s" % [ship.name, ship_type.name, where, cargo]
	if not ship.route_id.is_empty():
		text += ", on %s" % _session.player().get_route(ship.route_id).name
	return text


func _select(ship_id: String) -> void:
	_session.select_ship(ship_id)
	var ship := _session.player().get_ship(ship_id)
	if ship.is_docked():
		_session.select_city(ship.docked_at)


func _sail(city_id: String) -> void:
	_session.execute(SailCommand.new(WorldState.PLAYER_ID, _session.selected_ship, city_id))
