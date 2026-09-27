class_name HintPanel
extends PanelContainer
## First-time hints: a small banner over the map showing the next step of the core loop the
## player hasn't done yet. Each hint disappears once done or dismissed; "Hide hints" hides all.
## Dismissals last for the session only.


class Hint:
	extends RefCounted
	var id: String
	var text: String
	## Returns true once the player has done what the hint suggests.
	var done: Callable

	func _init(p_id: String, p_text: String, p_done: Callable) -> void:
		id = p_id
		text = p_text
		done = p_done


var _session: GameSession
var _hints: Array[Hint] = []
var _dismissed: Dictionary[String, bool] = {}
var _hidden: bool = false
var _current: Hint
var _text: Label = Label.new()


func setup(session: GameSession) -> void:
	_session = session
	_hints = _make_hints()
	custom_minimum_size = Vector2(360, 0)
	var margin := UiStyle.add_padding(self, 10)
	var column := VBoxContainer.new()
	margin.add_child(column)
	_text.name = "HintText"
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD
	column.add_child(_text)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(buttons)
	var dismiss := Button.new()
	dismiss.name = "DismissHint"
	dismiss.text = "Got it"
	dismiss.pressed.connect(_dismiss)
	buttons.add_child(dismiss)
	var hide_all := Button.new()
	hide_all.name = "HideHints"
	hide_all.text = "Hide hints"
	hide_all.pressed.connect(_hide_all)
	buttons.add_child(hide_all)
	_session.changed.connect(refresh)
	refresh()


func refresh() -> void:
	_current = null
	if not _hidden:
		for hint in _hints:
			if not _dismissed.has(hint.id) and not hint.done.call():
				_current = hint
				break
	visible = _current != null
	if _current != null:
		_text.text = _current.text


## Id of the hint on show, or "" if none.
func current_hint() -> String:
	return _current.id if _current != null else ""


func _dismiss() -> void:
	if _current != null:
		_dismissed[_current.id] = true
	refresh()


func _hide_all() -> void:
	_hidden = true
	refresh()


func _make_hints() -> Array[Hint]:
	var start_coins := _session.sim.data.scenario.coins
	var start_city := _session.sim.data.scenario.start_city
	return [
		Hint.new(
			"buy",
			"Welcome! Green prices are good deals. Pick a quantity and buy something cheap.",
			func() -> bool: return _has_goods()
		),
		Hint.new(
			"sail",
			"Send your ship with Fleet > Sail to, then press 1x to let time run.",
			func() -> bool: return _has_sailed(start_city)
		),
		Hint.new(
			"sell",
			"Sell where the Sell price is green. Profits buy more ships at the Shipyard.",
			func() -> bool: return _session.player().coins > start_coins
		),
		Hint.new(
			"kontor",
			"A kontor stores goods in a city and lets you build workshops. It's below the Fleet.",
			func() -> bool: return not _session.player().kontors.is_empty()
		),
		Hint.new(
			"workshop",
			"Workshops turn goods in your kontor into other goods. Hover a Build button for details.",
			func() -> bool: return _has_workshop()
		),
	]


func _has_goods() -> bool:
	for ship in _session.player().ships:
		if ship.cargo_total() > 0:
			return true
	return not _session.player().kontors.is_empty()


func _has_sailed(start_city: String) -> bool:
	for ship in _session.player().ships:
		if ship.docked_at != start_city:
			return true
	return false


func _has_workshop() -> bool:
	for kontor: KontorState in _session.player().kontors.values():
		if not kontor.workshops.is_empty():
			return true
	return false
