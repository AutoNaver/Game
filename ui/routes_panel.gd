class_name RoutesPanel
extends VBoxContainer
## The player's trade routes: each with its stops and ships, and buttons to edit or delete it, plus
## "New route". Editing happens in the RouteEditor overlay, opened through the session.

var _session: GameSession
var _list: VBoxContainer = VBoxContainer.new()
var _route_ids: PackedStringArray = []
var _new_route: Button = Button.new()
var _locked: Label = Label.new()


func setup(session: GameSession) -> void:
	_session = session
	add_child(UiStyle.label("Trade routes", UiStyle.HEADER_LABEL))
	_list.name = "RouteList"
	add_child(_list)
	_new_route.name = "NewRoute"
	_new_route.text = "New route"
	_new_route.pressed.connect(_session.route_editor_requested.emit.bind(""))
	add_child(_new_route)
	_locked.name = "RoutesLocked"
	_locked.theme_type_variation = UiStyle.MUTED_LABEL
	_locked.autowrap_mode = TextServer.AUTOWRAP_WORD
	add_child(_locked)
	_session.changed.connect(refresh)
	refresh()


func refresh() -> void:
	var locked := RankSystem.unlock_error(
		_session.sim.data, _session.player(), RankDef.ROUTES, "Trade routes"
	)
	_new_route.disabled = not locked.is_empty()
	_new_route.tooltip_text = locked
	_locked.text = "Locked: %s" % locked
	_locked.visible = not locked.is_empty()
	var routes := _session.player().routes
	var ids := PackedStringArray()
	for route in routes:
		ids.append(route.id)
	if ids != _route_ids:
		_rebuild(routes)
		_route_ids = ids
	for route in routes:
		var label := _list.get_node("Route_%s/Summary" % route.id) as Label
		label.text = _describe(route)


func _rebuild(routes: Array[RouteState]) -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	if routes.is_empty():
		var empty := UiStyle.label("No routes yet. Ships on a route trade on their own.")
		empty.theme_type_variation = UiStyle.MUTED_LABEL
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD
		_list.add_child(empty)
	for route in routes:
		var row := HBoxContainer.new()
		row.name = "Route_%s" % route.id
		var summary := Label.new()
		summary.name = "Summary"
		summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		summary.autowrap_mode = TextServer.AUTOWRAP_WORD
		row.add_child(summary)
		var edit := Button.new()
		edit.name = "EditRoute_%s" % route.id
		edit.text = "Edit"
		edit.pressed.connect(_session.route_editor_requested.emit.bind(route.id))
		row.add_child(edit)
		var delete := Button.new()
		delete.name = "DeleteRoute_%s" % route.id
		delete.text = "Delete"
		delete.pressed.connect(_delete.bind(route.id))
		row.add_child(delete)
		_list.add_child(row)


func _describe(route: RouteState) -> String:
	var cities: PackedStringArray = []
	for stop in route.stops:
		cities.append(_session.sim.data.get_city(stop.city_id).name)
	var ships := 0
	for ship in _session.player().ships:
		if ship.route_id == route.id:
			ships += 1
	var fleet := "no ships" if ships == 0 else "%d ship%s" % [ships, "" if ships == 1 else "s"]
	return "%s: %s (%s)" % [route.name, " → ".join(cities), fleet]


func _delete(route_id: String) -> void:
	_session.execute(DeleteRouteCommand.new(WorldState.PLAYER_ID, route_id))
