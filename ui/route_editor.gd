class_name RouteEditor
extends PanelContainer
## Creates or edits a trade route: its name, its stops in order, and each stop's orders. Works on a
## copy and saves through SaveRouteCommand, so nothing changes until "Save route" succeeds. Time
## stops while the editor is open.

const ACTION_NAMES: Dictionary[RouteOrder.Action, String] = {
	RouteOrder.Action.BUY: "Buy",
	RouteOrder.Action.SELL: "Sell",
	RouteOrder.Action.LOAD: "Load from kontor",
	RouteOrder.Action.UNLOAD: "Unload to kontor",
}
## Defaults for a new order: a full small ship's worth, no price limit.
const NEW_ORDER_QUANTITY: int = 50
## Largest quantity and price limit the spin boxes offer.
const MAX_QUANTITY: int = 10_000
const MAX_PRICE_LIMIT: int = 100_000

var _session: GameSession
var _route_id: String = ""
var _stops: Array[RouteStop] = []
var _speed_before: int = 0
var _title: Label = Label.new()
var _name_edit: LineEdit = LineEdit.new()
var _stop_list: VBoxContainer = VBoxContainer.new()
var _add_stop: Button = Button.new()
var _note: Label = Label.new()


func setup(session: GameSession) -> void:
	_session = session
	visible = false
	theme_type_variation = UiStyle.DIALOG_PANEL
	custom_minimum_size = Vector2(600, 0)
	var margin := UiStyle.add_padding(self, 16)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	_title.theme_type_variation = UiStyle.HEADER_LABEL
	column.add_child(_title)
	_name_edit.name = "RouteName"
	_name_edit.placeholder_text = "Route name"
	_name_edit.max_length = RouteState.MAX_NAME_LENGTH
	column.add_child(_name_edit)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 380)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_stop_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_stop_list)
	column.add_child(scroll)
	_add_stop.name = "AddStop"
	_add_stop.text = "Add stop"
	_add_stop.pressed.connect(_on_add_stop)
	column.add_child(_add_stop)
	_note.name = "RouteEditorNote"
	_note.theme_type_variation = UiStyle.MESSAGE_LABEL
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD
	column.add_child(_note)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	var save := Button.new()
	save.name = "SaveRoute"
	save.text = "Save route"
	save.pressed.connect(_save)
	buttons.add_child(save)
	var cancel := Button.new()
	cancel.name = "CancelRoute"
	cancel.text = "Cancel"
	cancel.pressed.connect(_close)
	buttons.add_child(cancel)
	column.add_child(buttons)


## Opens the editor on a copy of route `route_id`, or on a new two-stop route if it's "".
func open(route_id: String) -> void:
	_route_id = route_id
	_stops = []
	var route := _session.player().get_route(route_id)
	if route != null:
		_name_edit.text = route.name
		for stop in route.stops:
			_stops.append(stop.duplicate_stop())
	else:
		_name_edit.text = "Route %d" % (_session.player().routes.size() + 1)
		var cities := _session.sim.data.cities
		_stops.append(RouteStop.new(_session.selected_city, []))
		var other := cities[0].id if cities[0].id != _session.selected_city else cities[1].id
		_stops.append(RouteStop.new(other, []))
	_title.text = "Edit route" if route != null else "New route"
	_note.text = ""
	_speed_before = _session.speed
	_session.set_speed(0)
	_rebuild()
	visible = true
	set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)


## The stops as currently edited (for tests and the save button).
func edited_stops() -> Array[RouteStop]:
	return _stops


func _rebuild() -> void:
	for child in _stop_list.get_children():
		_stop_list.remove_child(child)
		child.queue_free()
	for i in _stops.size():
		_stop_list.add_child(_build_stop(i))
	_add_stop.disabled = _stops.size() >= RouteState.MAX_STOPS


func _build_stop(index: int) -> VBoxContainer:
	var stop := _stops[index]
	var box := VBoxContainer.new()
	box.name = "Stop_%d" % index
	var header := HBoxContainer.new()
	header.add_child(UiStyle.label("Stop %d:" % (index + 1), UiStyle.MUTED_LABEL))
	var city := OptionButton.new()
	city.name = "Stop_%d_City" % index
	for city_def in _session.sim.data.cities:
		city.add_item(city_def.name)
		if city_def.id == stop.city_id:
			city.select(city.item_count - 1)
	city.item_selected.connect(_on_city_selected.bind(index))
	header.add_child(city)
	var add_order := Button.new()
	add_order.name = "Stop_%d_AddOrder" % index
	add_order.text = "Add order"
	add_order.disabled = stop.orders.size() >= RouteState.MAX_ORDERS_PER_STOP
	add_order.pressed.connect(_on_add_order.bind(index))
	header.add_child(add_order)
	var remove := Button.new()
	remove.name = "RemoveStop_%d" % index
	remove.text = "Remove stop"
	remove.disabled = _stops.size() <= RouteState.MIN_STOPS
	remove.pressed.connect(_on_remove_stop.bind(index))
	header.add_child(remove)
	box.add_child(header)
	for j in stop.orders.size():
		box.add_child(_build_order(index, j))
	box.add_child(HSeparator.new())
	return box


func _build_order(stop_index: int, order_index: int) -> HBoxContainer:
	var order := _stops[stop_index].orders[order_index]
	var prefix := "Stop_%d_Order_%d" % [stop_index, order_index]
	var row := HBoxContainer.new()
	row.name = prefix
	var action := OptionButton.new()
	action.name = prefix + "_Action"
	for value: RouteOrder.Action in ACTION_NAMES:
		action.add_item(ACTION_NAMES[value], value)
	action.select(action.get_item_index(order.action))
	action.item_selected.connect(
		func(item: int) -> void:
			order.action = action.get_item_id(item) as RouteOrder.Action
			_rebuild()
	)
	row.add_child(action)
	var good := OptionButton.new()
	good.name = prefix + "_Good"
	for good_def in _session.sim.data.goods:
		good.add_item(good_def.name)
		if good_def.id == order.good_id:
			good.select(good.item_count - 1)
	good.item_selected.connect(
		func(item: int) -> void: order.good_id = _session.sim.data.goods[item].id
	)
	row.add_child(good)
	var quantity := _spin_box(prefix + "_Quantity", 1, MAX_QUANTITY, order.quantity)
	quantity.tooltip_text = "At most this many units per visit"
	quantity.value_changed.connect(func(value: float) -> void: order.quantity = int(value))
	row.add_child(quantity)
	var trades := order.action == RouteOrder.Action.BUY or order.action == RouteOrder.Action.SELL
	if trades:
		var limit := _spin_box(prefix + "_Limit", 0, MAX_PRICE_LIMIT, order.price_limit)
		limit.prefix = "max" if order.action == RouteOrder.Action.BUY else "min"
		limit.tooltip_text = "Price limit per unit; 0 means any price"
		limit.value_changed.connect(func(value: float) -> void: order.price_limit = int(value))
		row.add_child(limit)
	var remove := Button.new()
	remove.name = prefix + "_Remove"
	remove.text = "×"
	remove.tooltip_text = "Remove this order"
	remove.pressed.connect(_on_remove_order.bind(stop_index, order_index))
	row.add_child(remove)
	return row


static func _spin_box(node_name: String, low: int, high: int, value: int) -> SpinBox:
	var box := SpinBox.new()
	box.name = node_name
	box.min_value = low
	box.max_value = high
	box.step = 1
	box.value = value
	return box


func _on_city_selected(item: int, index: int) -> void:
	_stops[index].city_id = _session.sim.data.cities[item].id


func _on_add_stop() -> void:
	# Default to a city that differs from the last stop, so the route stays valid.
	var last := _stops[-1].city_id
	for city in _session.sim.data.cities:
		if city.id != last and city.id != _stops[0].city_id:
			_stops.append(RouteStop.new(city.id, []))
			_rebuild()
			return
	_stops.append(RouteStop.new(_session.sim.data.cities[0].id, []))
	_rebuild()


func _on_remove_stop(index: int) -> void:
	_stops.remove_at(index)
	_rebuild()


func _on_add_order(stop_index: int) -> void:
	var first_good := _session.sim.data.goods[0].id
	_stops[stop_index].orders.append(
		RouteOrder.new(RouteOrder.Action.BUY, first_good, NEW_ORDER_QUANTITY)
	)
	_rebuild()


func _on_remove_order(stop_index: int, order_index: int) -> void:
	_stops[stop_index].orders.remove_at(order_index)
	_rebuild()


func _save() -> void:
	var command := SaveRouteCommand.new(WorldState.PLAYER_ID, _route_id, _name_edit.text, _stops)
	if _session.execute(command):
		_close()
	else:
		_note.text = command.validate(_session.sim)


func _close() -> void:
	visible = false
	_session.set_speed(_speed_before)
