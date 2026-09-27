class_name Hud
extends PanelContainer
## Top bar: the player's coins, the date, the latest message, quick save/load and time controls.

var _session: GameSession
var _coins_label: Label = Label.new()
var _date_label: Label = Label.new()
var _message_label: Label = Label.new()
var _speed_buttons: Dictionary[int, Button] = {}


func setup(session: GameSession) -> void:
	_session = session
	var margin := UiStyle.add_padding(self, 6)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	margin.add_child(row)
	_coins_label.name = "CoinsLabel"
	_date_label.name = "DateLabel"
	_message_label.name = "MessageLabel"
	row.add_child(_coins_label)
	row.add_child(_date_label)
	_message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.theme_type_variation = UiStyle.MESSAGE_LABEL
	row.add_child(_message_label)
	for action: Array in [
		["SaveGame", "Save", _session.save_game], ["LoadGame", "Load", _session.load_game]
	]:
		var file_button := Button.new()
		file_button.name = action[0]
		file_button.text = action[1]
		file_button.pressed.connect(func() -> void: (action[2] as Callable).call())
		row.add_child(file_button)
	row.add_child(VSeparator.new())
	var group := ButtonGroup.new()
	for speed in GameSession.SPEEDS:
		var button := Button.new()
		button.text = "Pause" if speed == 0 else "%d×" % speed
		button.toggle_mode = true
		button.button_group = group
		button.pressed.connect(_session.set_speed.bind(speed))
		row.add_child(button)
		_speed_buttons[speed] = button
	_session.changed.connect(refresh)
	_session.message_posted.connect(_show_message)
	refresh()


func refresh() -> void:
	if _session.sim == null:
		return
	_coins_label.text = "%d coins" % _session.player().coins
	var hour := _session.sim.world.hour
	_date_label.text = "Day %d, %02d:00" % [_session.sim.day() + 1, hour % Simulation.HOURS_PER_DAY]
	for speed: int in _speed_buttons:
		_speed_buttons[speed].set_pressed_no_signal(speed == _session.speed)


func _show_message(text: String) -> void:
	_message_label.text = text
