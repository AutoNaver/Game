extends Control
## Entry scene: loads the game data, starts a session and lays out the HUD, map and side panel,
## with the start screen and save menu on top.
## If the data is broken, shows every loader error instead of a half-working game.

## Fixed for now, so every new game plays out the same (the rivals draw on the world RNG).
const NEW_GAME_SEED: int = 1
const SIDE_PANEL_WIDTH: float = 420.0

var session: GameSession = GameSession.new()
var _map: MapView
var _city_view: CityView
var _enter_button: Button
var _side: SidePanel
var _city_view_city_id: String = ""


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
	var view_host := Control.new()
	view_host.name = "ViewHost"
	view_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view_host.clip_contents = true
	body.add_child(view_host)
	_map = MapView.new()
	_map.name = "Map"
	_map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view_host.add_child(_map)
	_city_view = CityView.new()
	_city_view.name = "CityView"
	_city_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view_host.add_child(_city_view)
	_side = SidePanel.new()
	_side.name = "SidePanel"
	_side.custom_minimum_size = Vector2(SIDE_PANEL_WIDTH, 0.0)
	body.add_child(_side)

	hud.setup(session)
	_map.setup(session)
	_city_view.setup(session)
	_city_view.set_city_visible(false)
	_side.setup(session)
	_city_view.landmark_selected.connect(_side.focus_section)
	_enter_button = Button.new()
	_enter_button.name = "ToggleCityView"
	_enter_button.position = Vector2(12, 12)
	_enter_button.pressed.connect(_toggle_city_view)
	view_host.add_child(_enter_button)
	var hints := HintPanel.new()
	hints.name = "Hints"
	hints.position = Vector2(12, 52)
	view_host.add_child(hints)
	hints.setup(session)
	var log_panel := LogPanel.new()
	log_panel.name = "Log"
	view_host.add_child(log_panel)
	log_panel.setup(session)
	# Bottom-left corner of the map, growing upwards as entries wrap.
	log_panel.set_anchors_and_offsets_preset(
		Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 12
	)
	log_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var houses := HousesPanel.new()
	houses.name = "HousesPanel"
	view_host.add_child(houses)
	houses.setup(session)
	houses.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 12)
	houses.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	session.changed.connect(_sync_city_view)
	_sync_city_view()

	var save_menu := SaveMenu.new()
	save_menu.name = "SaveMenu"
	var start := StartScreen.new()
	start.name = "StartScreen"
	add_child(start)
	# The menu goes last so it also shows on top of the start screen.
	add_child(save_menu)
	save_menu.setup(session)
	start.setup(session, save_menu)
	session.game_over.connect(start.show_game_over)
	session.save_menu_requested.connect(save_menu.open)
	var route_editor := RouteEditor.new()
	route_editor.name = "RouteEditor"
	add_child(route_editor)
	route_editor.setup(session)
	session.route_editor_requested.connect(route_editor.open)


func _toggle_city_view() -> void:
	if _city_view.visible:
		_city_view.set_city_visible(false)
	else:
		if not _can_enter_selected_city():
			return
		_city_view_city_id = session.selected_city
		_city_view.set_city_visible(true)
	_map.visible = not _city_view.visible
	_sync_city_view()


func _can_enter_selected_city() -> bool:
	return (
		session.sim != null
		and not session.selected_city.is_empty()
		and MarketKnowledgeSystem.has_presence(
			session.sim.data, session.player(), session.selected_city
		)
	)


func _sync_city_view() -> void:
	if (
		_city_view.visible
		and (_city_view_city_id != session.selected_city or not _can_enter_selected_city())
	):
		_city_view.set_city_visible(false)
		_map.visible = true
	var present := _can_enter_selected_city()
	_enter_button.disabled = not _city_view.visible and not present
	if _city_view.visible:
		_enter_button.text = "Sea map"
		_enter_button.tooltip_text = "Return to the Baltic map"
	else:
		var city := session.sim.data.get_city(session.selected_city)
		_enter_button.text = "Enter %s" % city.name
		_enter_button.tooltip_text = (
			"Enter with a docked ship, kontor, or the player ashore"
			if not present
			else "Visit this city"
		)


func _show_fatal(text: String) -> void:
	var label := Label.new()
	label.name = "FatalLabel"
	label.text = text
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(label)
