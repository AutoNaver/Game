extends Control
## Entry scene: loads the game data, starts a session and lays out the HUD, map and side panel,
## with the start screen and save menu on top.
## If the data is broken, shows every loader error instead of a half-working game.

## Fixed for now: nothing draws from the RNG yet, so every new game is the same.
const NEW_GAME_SEED: int = 1
const SIDE_PANEL_WIDTH: float = 420.0

var session: GameSession = GameSession.new()


func _ready() -> void:
	var loader := GameDataLoader.new()
	var data := loader.load_dir(GameDataLoader.DEFAULT_DIR)
	if data == null:
		for message in loader.errors:
			push_error(message)
		_show_fatal("Game data failed to load:\n%s" % "\n".join(loader.errors))
		return

	theme = UiStyle.make_theme()
	session.name = "Session"
	add_child(session)
	# Start first: panels build their rows from the running game in setup().
	session.start(data, NEW_GAME_SEED)
	var layout := VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(layout)

	var hud := Hud.new()
	hud.name = "Hud"
	hud.theme_type_variation = UiStyle.HUD_PANEL
	layout.add_child(hud)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(body)
	var map := MapView.new()
	map.name = "Map"
	map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(map)
	var side := SidePanel.new()
	side.name = "SidePanel"
	side.custom_minimum_size = Vector2(SIDE_PANEL_WIDTH, 0.0)
	body.add_child(side)

	hud.setup(session)
	map.setup(session)
	side.setup(session)
	var hints := HintPanel.new()
	hints.name = "Hints"
	hints.position = Vector2(12, 12)
	map.add_child(hints)
	hints.setup(session)
	var log_panel := LogPanel.new()
	log_panel.name = "Log"
	map.add_child(log_panel)
	log_panel.setup(session)
	# Bottom-left corner of the map, growing upwards as entries wrap.
	log_panel.set_anchors_and_offsets_preset(
		Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 12
	)
	log_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN

	var save_menu := SaveMenu.new()
	save_menu.name = "SaveMenu"
	var start := StartScreen.new()
	start.name = "StartScreen"
	add_child(start)
	# The menu goes last so it also shows on top of the start screen.
	add_child(save_menu)
	save_menu.setup(session)
	start.setup(session, save_menu)
	session.save_menu_requested.connect(save_menu.open)
	var route_editor := RouteEditor.new()
	route_editor.name = "RouteEditor"
	add_child(route_editor)
	route_editor.setup(session)
	session.route_editor_requested.connect(route_editor.open)


func _show_fatal(text: String) -> void:
	var label := Label.new()
	label.name = "FatalLabel"
	label.text = text
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(label)
