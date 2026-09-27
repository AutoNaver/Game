class_name SaveMenu
extends PanelContainer
## Save or load a game by slot name. Saving takes a typed name (clicking an existing save fills it
## in, to overwrite); loading lists the saves, newest first. Time stops while the menu is open.

## Emitted when the menu closes; `loaded` is true if a game was loaded.
signal closed(loaded: bool)

var _session: GameSession
var _saving: bool = false
var _speed_before: int = 0
var _title: Label = Label.new()
var _name_row: HBoxContainer = HBoxContainer.new()
var _name_edit: LineEdit = LineEdit.new()
var _slots: VBoxContainer = VBoxContainer.new()
var _note: Label = Label.new()


func setup(session: GameSession) -> void:
	_session = session
	visible = false
	theme_type_variation = UiStyle.DIALOG_PANEL
	custom_minimum_size = Vector2(380, 0)
	var margin := UiStyle.add_padding(self, 16)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	_title.theme_type_variation = UiStyle.HEADER_LABEL
	column.add_child(_title)
	_name_edit.name = "SaveName"
	_name_edit.max_length = SaveGame.MAX_SLOT_NAME
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.text_submitted.connect(func(_text: String) -> void: _save())
	_name_row.add_child(_name_edit)
	var save_button := Button.new()
	save_button.name = "ConfirmSave"
	save_button.text = "Save"
	save_button.pressed.connect(_save)
	_name_row.add_child(save_button)
	column.add_child(_name_row)
	_slots.name = "Slots"
	column.add_child(_slots)
	_note.name = "SaveMenuNote"
	_note.theme_type_variation = UiStyle.MUTED_LABEL
	column.add_child(_note)
	var close := Button.new()
	close.name = "CloseSaveMenu"
	close.text = "Close"
	close.pressed.connect(_close.bind(false))
	column.add_child(close)


## Shows the menu for saving (`saving`) or loading, and pauses the game until it closes.
func open(saving: bool) -> void:
	_saving = saving
	_speed_before = _session.speed
	_session.set_speed(0)
	_title.text = "Save game" if saving else "Load game"
	_name_row.visible = saving
	var suggestion := _session.save_slot
	if suggestion.is_empty():
		suggestion = "Day %d" % (_session.sim.day() + 1)
	_name_edit.text = suggestion
	_rebuild_slots()
	visible = true
	# Centre over whatever the menu is shown on.
	set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)


func _rebuild_slots() -> void:
	for child in _slots.get_children():
		_slots.remove_child(child)
		child.queue_free()
	var saves := _session.list_saves()
	for slot in saves:
		var button := Button.new()
		button.name = "Slot_%s" % slot.replace(" ", "_")
		button.text = slot
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_pick.bind(slot))
		_slots.add_child(button)
	if saves.is_empty():
		_note.text = "No saves yet."
	elif _saving:
		_note.text = "Pick a save to overwrite it, or type a new name."
	else:
		_note.text = (
			"Newest first. The autosave is written every %d days." % [GameSession.AUTOSAVE_DAYS]
		)


func _pick(slot: String) -> void:
	if _saving:
		_name_edit.text = slot
	elif _session.load_game(slot):
		_close(true)


func _save() -> void:
	if _session.save_game(_name_edit.text):
		_close(false)
	else:
		_note.text = SaveGame.check_slot_name(_name_edit.text)


func _close(loaded: bool) -> void:
	visible = false
	if not loaded:
		_session.set_speed(_speed_before)
	closed.emit(loaded)
