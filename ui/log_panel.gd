class_name LogPanel
extends PanelContainer
## The latest notifications (ships arrived, workshops stopped) in a corner of the map, newest at
## the bottom, and the "pause when a ship arrives" switch.

## Entries shown; the session keeps more.
const VISIBLE_ENTRIES: int = 5

var _session: GameSession
var _entries: Label = Label.new()
var _pause_toggle: CheckBox = CheckBox.new()


func setup(session: GameSession) -> void:
	_session = session
	custom_minimum_size = Vector2(340, 0)
	var margin := UiStyle.add_padding(self, 8)
	var column := VBoxContainer.new()
	margin.add_child(column)
	column.add_child(UiStyle.label("Log", UiStyle.HEADER_LABEL))
	_entries.name = "LogEntries"
	_entries.theme_type_variation = UiStyle.MUTED_LABEL
	_entries.autowrap_mode = TextServer.AUTOWRAP_WORD
	column.add_child(_entries)
	_pause_toggle.name = "PauseOnArrival"
	_pause_toggle.text = "Pause when a ship arrives"
	_pause_toggle.toggled.connect(func(on: bool) -> void: _session.pause_on_arrival = on)
	column.add_child(_pause_toggle)
	_session.notified.connect(func(_entry: String) -> void: refresh())
	_session.changed.connect(refresh)
	refresh()


func refresh() -> void:
	var all := _session.notification_log
	var shown := all.slice(maxi(0, all.size() - VISIBLE_ENTRIES))
	_entries.text = "\n".join(shown) if not shown.is_empty() else "Nothing yet."
	_pause_toggle.set_pressed_no_signal(_session.pause_on_arrival)
