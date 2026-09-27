class_name StartScreen
extends ColorRect
## Shown on launch over the (paused) new game: start it, continue the newest save, or pick one.

var _session: GameSession
var _menu: SaveMenu
var _continue: Button = Button.new()
var _title: Label


func setup(session: GameSession, menu: SaveMenu) -> void:
	_session = session
	_menu = menu
	color = Color(UiStyle.PANEL, 0.94)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	center.add_child(column)
	_title = UiStyle.label("Hanse", UiStyle.TITLE_LABEL)
	column.add_child(_title)
	column.add_child(UiStyle.label("A trading house in the Baltic, 1400", UiStyle.MUTED_LABEL))
	var new_game := Button.new()
	new_game.name = "NewGame"
	new_game.text = "New game"
	new_game.pressed.connect(_begin)
	column.add_child(new_game)
	_continue.name = "Continue"
	_continue.pressed.connect(_continue_newest)
	column.add_child(_continue)
	var load_button := Button.new()
	load_button.name = "LoadFromStart"
	load_button.text = "Load game..."
	load_button.pressed.connect(_menu.open.bind(false))
	column.add_child(load_button)
	_menu.closed.connect(_on_menu_closed)
	show_screen()


func show_screen() -> void:
	_session.set_speed(0)
	_title.text = "Hanse"
	var saves := _session.list_saves()
	_continue.disabled = saves.is_empty()
	_continue.text = "Continue" if saves.is_empty() else "Continue (%s)" % saves[0]
	visible = true


## A failed house may restart or load a saved game.
func show_game_over() -> void:
	show_screen()
	_title.text = "Bankrupt · Game over"


func _continue_newest() -> void:
	var saves := _session.list_saves()
	if not saves.is_empty() and _session.load_game(saves[0]):
		_begin()


func _on_menu_closed(loaded: bool) -> void:
	if visible and loaded:
		_begin()


func _begin() -> void:
	if _session.player().bankrupt:
		_session.start(_session.sim.data, 1)
	visible = false
	_session.set_speed(1)
