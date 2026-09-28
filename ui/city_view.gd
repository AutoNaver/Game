class_name CityView
extends Control
## A visual town scene for the selected city. Plots are derived from stable workshop ids until
## construction makes positions part of the simulation in M17. Walkers use UI time only.
## Like the sea map, the wheel zooms around the cursor, dragging pans, and a click selects.

signal landmark_selected(section: String)

const LANDMARKS: Array[String] = ["market", "tavern", "shipyard", "kontor", "town_hall"]
const GRID_SIZE: int = 14
const MAX_WALKERS: int = 24
const MIN_ZOOM: float = 0.7
const MAX_ZOOM: float = 2.2
## Tile width at zoom 1 is the largest that fits this many tiles across and down the view, so the
## whole town (walls, quay and moored ships) shows on entry. Capped by MAX_TILE_WIDTH.
const VIEW_TILES: Vector2 = Vector2(14.0, 8.3)
const MAX_TILE_WIDTH: float = 64.0
## Screen depth, in tile widths below the town's north corner, shown at the view's centre: midway
## between the tallest roofs at the back and the harbour wall at the front.
const VIEW_CENTRE_DEPTH: float = 2.75
const GROUND: Color = Color("#6b7850")
const ROAD: Color = Color("#a7a18a")
const WALL: Color = Color("#c0ae89")
const WATER: Color = Color("#244354")
const PLAYER: Color = Color("#d4ae5a")
const LABEL_OUTLINE: Color = Color("#18232b")
const PLAQUE: Color = Color("#232b24d9")

var _session: GameSession
var _phase: float = 0.0
var _zoom: float = 1.0
var _pan := Vector2.ZERO
var _press_position := Vector2.ZERO
var _dragging: bool = false
var _art := CityArt.new()
var _hovered: String = ""


func setup(session: GameSession) -> void:
	_session = session
	_art.canvas = self
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	clip_contents = true
	_session.changed.connect(queue_redraw)
	resized.connect(_clamp_pan)
	mouse_exited.connect(_set_hovered.bind(""))
	set_process(false)


func set_city_visible(value: bool) -> void:
	visible = value
	set_process(value)
	if value:
		reset_camera()
	else:
		_dragging = false
		_set_hovered("")


func _process(delta: float) -> void:
	_phase += delta
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), WATER)
	if _session == null or _session.sim == null:
		return
	var city_id := _session.selected_city
	var city_def := _session.sim.data.get_city(city_id)
	if city_def == null:
		return
	var variant := _city_variant(city_id)
	var crossing := _main_crossing(variant)
	var road_col := crossing.x
	var road_row := crossing.y
	_draw_ground(variant, road_col, road_row)
	_draw_waterfront(road_col, road_row)
	_draw_neighbourhood(city_id, variant, road_col, road_row)
	_draw_title(city_def.name)


func _draw_ground(variant: int, road_col: int, road_row: int) -> void:
	# Low-contrast ripples give the harbour depth without competing with the town.
	for i in 180:
		var at := Vector2(
			fposmod(float(i * 97) + _phase * 2, size.x), float(i * 47 % maxi(1, int(size.y)))
		)
		draw_line(at, at + Vector2(8 + i % 12, -2), Color(0.6, 0.75, 0.72, 0.09), 1)
	for y in GRID_SIZE:
		for x in GRID_SIZE:
			var road := x == road_col or y == road_row or (y == road_row + 3 and x >= road_col)
			var paved := (
				road or x >= GRID_SIZE - 2 or (absi(x - road_col) <= 1 and absi(y - road_row) <= 1)
			)
			var tint := float((x * 7 + y * 11 + variant * 3) % 5) * 0.012
			_draw_tile(x, y, (ROAD if paved else GROUND).lightened(tint))
			for i in 12:
				var u := float((i * 7 + x) % 11) / 12.0 - 0.45
				var v := float((i * 5 + y) % 11) / 12.0 - 0.45
				var at := _tile_center(float(x) + u, float(y) + v)
				var length := _tile_width() * (0.06 if paved else 0.025)
				draw_line(
					at,
					at + Vector2(length, length * 0.4),
					Color(0.16, 0.23, 0.14, 0.2),
					maxf(1, _zoom)
				)


func _draw_tile(x: int, y: int, color: Color) -> void:
	var at := _tile_center(float(x), float(y))
	var half_w := _tile_width() * 0.5
	var half_h := _tile_width() * 0.25
	draw_colored_polygon(
		PackedVector2Array(
			[
				at + Vector2(0, -half_h),
				at + Vector2(half_w, 0),
				at + Vector2(0, half_h),
				at + Vector2(-half_w, 0)
			]
		),
		color
	)


func _draw_waterfront(road_col: int, road_row: int) -> void:
	var unit := _tile_width() / 64.0
	# The eastern edge is a working stone quay; piers grow out from its road access.
	var a := _tile_center(13.5, -0.5)
	var b := _tile_center(13.5, 13.5)
	draw_line(a + Vector2(0, 6 * unit), b + Vector2(0, 6 * unit), Color("#4d5248"), 13 * unit)
	draw_line(a, b, Color("#b0a486"), 6 * unit)
	for i in 28:
		var p := a.lerp(b, float(i) / 28)
		draw_line(p, p + Vector2(0, 10 * unit), Color("#676a58"), unit)
	for row: int in [road_row, road_row + 3]:
		var start := _tile_center(13.5, float(row))
		var end := _tile_center(16.0, float(row))
		draw_line(
			start + Vector2(0, 5 * unit), end + Vector2(0, 5 * unit), Color("#4d3f2e"), 18 * unit
		)
		draw_line(start, end, Color("#a38a5f"), 17 * unit)
		for i in 16:
			var p := start.lerp(end, float(i) / 15)
			draw_line(p + Vector2(-7, 4) * unit, p + Vector2(7, -4) * unit, Color("#68543c"), unit)
			if i % 5 == 0:
				draw_line(
					p + Vector2(7, -4) * unit,
					p + Vector2(7, -13) * unit,
					Color("#65533b"),
					3 * unit
				)
	# A paved approach links the shipyard road to the waterfront.
	for x in range(road_col + 1, 14):
		_draw_tile(x, road_row + 3, ROAD)


func _draw_neighbourhood(city_id: String, variant: int, road_col: int, road_row: int) -> void:
	var items: Array[Dictionary] = []
	var reserved := _landmark_tiles(road_col, road_row)
	var workshops := workshop_plots()
	var workshop_tiles := workshops.values()
	for y in range(0, GRID_SIZE):
		for x in range(0, GRID_SIZE - 2):
			if x == road_col or y == road_row or (y == road_row + 3 and x >= road_col):
				continue
			var plot := Vector2i(x, y)
			if reserved.has(plot) or workshop_tiles.has(plot):
				continue
			var seed_value := x * 13 + y * 17 + variant * 19
			if seed_value % 7 > 4:
				continue
			var kind := "house" if seed_value % 7 < 3 else "tree"
			items.append({"at": _tile_center(x, y), "kind": kind, "seed": seed_value})
	for section in LANDMARKS:
		var plot := _landmark_tile(section, road_col, road_row)
		items.append({"at": _tile_center(plot.x, plot.y), "kind": "landmark", "section": section})
	for trader in _session.sim.world.traders:
		var kontor := trader.get_kontor(city_id)
		if kontor == null:
			continue
		for workshop in kontor.workshops:
			if not workshops.has(workshop.id):
				continue
			var plot: Vector2i = workshops[workshop.id]
			var color := (
				PLAYER
				if trader.id == WorldState.PLAYER_ID
				else MapView.house_color(_session.sim.data, trader.id)
			)
			items.append(
				{
					"at": _tile_center(plot.x, plot.y),
					"kind": "workshop",
					"color": color,
					"seed": plot.x + plot.y
				}
			)
	for y in range(1, 14, 2):
		items.append({"at": _tile_center(13, y), "kind": "cargo"})
	var ship_index := 0
	for trader in _session.sim.world.traders:
		for ship in trader.ships:
			if ship.docked_at != city_id:
				continue
			var color := (
				PLAYER
				if trader.id == WorldState.PLAYER_ID
				else MapView.house_color(_session.sim.data, trader.id)
			)
			var at := _tile_center(
				15.0 + float(ship_index / 4) * 1.6,
				float(road_row) - 0.8 + float(ship_index % 4) * 1.8
			)
			items.append(
				{
					"at": at,
					"kind": "ship",
					"color": color,
					"label": ship.name if trader.id == WorldState.PLAYER_ID else ""
				}
			)
			ship_index += 1
	var city := _session.sim.world.get_city(city_id)
	var employed := CityEconomy.workers_employed(_session.sim.data, _session.sim.world, city_id)
	var count := clampi(4 + city.population / 1000 + employed / 100, 4, MAX_WALKERS)
	for i in count:
		var travel := fposmod(
			_phase * (0.45 + float(i % 3) * 0.08) + float(i) * 1.91, GRID_SIZE - 1.0
		)
		var at := (
			_tile_center(travel, float(road_row) + 0.25)
			if i % 2 == 0
			else _tile_center(float(road_col) + 0.25, travel)
		)
		items.append({"at": at, "kind": "person", "seed": i})
	# Wall sections participate in the same painter's order as buildings and people.
	for i in GRID_SIZE:
		items.append({"at": _tile_center(-0.5, i), "kind": "wall", "axis": Vector2(-1, 0.5)})
		items.append({"at": _tile_center(i, 13.5), "kind": "wall", "axis": Vector2(1, 0.5)})
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.at.y < b.at.y)
	for item in items:
		_draw_item(item)
	# Plaques are drawn last so roofs cannot hide navigation targets. They sit on the street in
	# front of each landmark, inside its click area.
	for section in LANDMARKS:
		var at := landmark_center(section)
		_draw_plaque(
			at + Vector2(0, 18 * _tile_width() / 64), _landmark_name(section), section == _hovered
		)


func _draw_item(item: Dictionary) -> void:
	var at: Vector2 = item.at
	var unit := _tile_width() / 64.0
	match item.kind:
		"house":
			_art.house(at, unit, item.seed, Color.TRANSPARENT, false)
		"workshop":
			_art.house(at, unit, item.seed, item.color, false)
		"tree":
			_art.tree(at, unit, item.seed)
		"cargo":
			_art.cargo(at, unit)
		"ship":
			_art.ship(at, unit, item.color)
			if not item.label.is_empty():
				_draw_label(at + Vector2(0, 30 * unit), item.label, 11)
		"person":
			_art.person(at, unit, item.seed, _phase)
		"wall":
			var axis: Vector2 = item.axis * _tile_width() * 0.25
			draw_line(at - axis, at + axis, Color("#6a6958"), 15 * unit)
			draw_line(
				at - axis - Vector2(0, 8 * unit), at + axis - Vector2(0, 8 * unit), WALL, 5 * unit
			)
			for i in 4:
				var p := (at - axis).lerp(at + axis, float(i) / 4)
				draw_rect(Rect2(p - Vector2(2, 14) * unit, Vector2(4, 7) * unit), WALL)
		"landmark":
			var section: String = item.section
			if section == _hovered:
				draw_arc(at, 26 * unit, 0, TAU, 40, PLAYER, 2)
			if section == "market":
				_art.stall(at + Vector2(-12, -4) * unit, unit, Color("#95644c"))
				_art.stall(at + Vector2(14, 8) * unit, unit, Color("#596d68"))
			else:
				var accent := (
					PLAYER
					if (
						section == "kontor"
						and _session.player().get_kontor(_session.selected_city) != null
					)
					else Color("#718994")
				)
				_art.house(at, unit, 2 if section == "town_hall" else 0, accent, true)


## Stable UI-only plots for the workshops in the selected city. M17 will save player-chosen plots.
func workshop_plots() -> Dictionary[String, Vector2i]:
	var result: Dictionary[String, Vector2i] = {}
	if _session == null or _session.sim == null:
		return result
	var variant := _city_variant(_session.selected_city)
	var crossing := _main_crossing(variant)
	var road_col := crossing.x
	var road_row := crossing.y
	var reserved := _landmark_tiles(road_col, road_row)
	var candidates: Array[Vector2i] = []
	# The two columns by the harbour are paved quay, so workshops stay inland like houses.
	for y in range(1, GRID_SIZE - 1):
		for x in range(1, GRID_SIZE - 2):
			var plot := Vector2i(x, y)
			if x == road_col or y == road_row or (y == road_row + 3 and x >= road_col):
				continue
			if not reserved.has(plot):
				candidates.append(plot)
	var ids: Array[String] = []
	for trader in _session.sim.world.traders:
		var kontor := trader.get_kontor(_session.selected_city)
		if kontor != null:
			for workshop in kontor.workshops:
				ids.append(workshop.id)
	# Numeric order places older workshops first, so building a new one never moves them.
	ids.sort_custom(
		func(a: String, b: String) -> bool: return _workshop_number(a) < _workshop_number(b)
	)
	var occupied: Array[Vector2i] = []
	for id in ids:
		var start := (_workshop_number(id) * 37 + variant * 11) % candidates.size()
		for offset in candidates.size():
			var plot := candidates[(start + offset) % candidates.size()]
			if not occupied.has(plot):
				result[id] = plot
				occupied.append(plot)
				break
	return result


func _workshop_number(id: String) -> int:
	return int(id.trim_prefix("workshop_"))


func _draw_title(city_name: String) -> void:
	var font := get_theme_default_font()
	var origin := Vector2(maxf(12, size.x - 330), 12)
	draw_style_box(_title_style(), Rect2(origin, Vector2(318, 57)))
	draw_string(
		font,
		origin + Vector2(12, 24),
		"%s · Harbour quarter" % city_name,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		18,
		Color("#ead4a8")
	)
	draw_string(
		font,
		origin + Vector2(12, 44),
		"Wheel: zoom · Drag: pan · Home: reset",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		12,
		Color("#c9bda4")
	)


func _title_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#343c32e8")
	style.border_color = Color("#a78a51")
	style.set_border_width_all(1)
	return style


## A landmark name on a dark plaque, outlined in gold while the pointer is over the landmark.
func _draw_plaque(baseline: Vector2, value: String, hovered: bool) -> void:
	var font := get_theme_default_font()
	var font_size := 13
	var width := font.get_string_size(value, 0, -1, font_size).x
	var box := Rect2(baseline + Vector2(-width * 0.5 - 6, -14), Vector2(width + 12, 19))
	var style := StyleBoxFlat.new()
	style.bg_color = PLAQUE
	style.border_color = PLAYER if hovered else Color("#8a7a58")
	style.set_border_width_all(2 if hovered else 1)
	style.set_corner_radius_all(3)
	draw_style_box(style, box)
	draw_string(
		font,
		baseline - Vector2(width * 0.5, 0),
		value,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		PLAYER if hovered else UiStyle.INK
	)


func _draw_label(at: Vector2, value: String, font_size: int) -> void:
	var font := get_theme_default_font()
	var width := font.get_string_size(value, 0, -1, font_size).x
	var where := at - Vector2(width * 0.5, 0)
	draw_string_outline(
		font, where, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 3, LABEL_OUTLINE
	)
	draw_string(font, where, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, UiStyle.INK)


func _tile_width() -> float:
	var fit := size / VIEW_TILES
	return minf(MAX_TILE_WIDTH, minf(fit.x, fit.y)) * _zoom


## Screen position of a ground point in tile coordinates. The view's centre is the fixed point
## that zoom_at scales around.
func _tile_center(x: float, y: float) -> Vector2:
	var iso := Vector2((x - y) * 0.5, (x + y) * 0.25 - VIEW_CENTRE_DEPTH)
	return size * 0.5 + iso * _tile_width() + _pan


func _city_variant(city_id: String) -> int:
	for i in _session.sim.data.cities.size():
		if _session.sim.data.cities[i].id == city_id:
			return i
	return 0


## Where the town's main street and cross street meet; the market square. Each city's position in
## the data gives it a different street plan.
func _main_crossing(variant: int) -> Vector2i:
	@warning_ignore("integer_division")
	return Vector2i(5 + variant % 3, 5 + variant / 3)


func _landmark_tiles(road_col: int, road_row: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for section in LANDMARKS:
		result.append(_landmark_tile(section, road_col, road_row))
	return result


func _landmark_tile(section: String, road_col: int, road_row: int) -> Vector2i:
	match section:
		"market":
			return Vector2i(road_col, road_row)
		"tavern":
			return Vector2i(road_col - 2, road_row)
		"shipyard":
			return Vector2i(road_col + 3, road_row + 3)
		"kontor":
			return Vector2i(road_col + 2, road_row)
		_:
			return Vector2i(road_col, road_row - 2)


func _landmark_name(section: String) -> String:
	match section:
		"market":
			return "Market"
		"tavern":
			return "Tavern"
		"shipyard":
			return "Shipyard"
		"kontor":
			return "Kontor"
		_:
			return "Town hall"


## Screen centre of a landmark, useful to mouse and keyboard navigation tests.
func landmark_center(section: String) -> Vector2:
	var crossing := _main_crossing(_city_variant(_session.selected_city))
	var tile := _landmark_tile(section, crossing.x, crossing.y)
	return _tile_center(float(tile.x), float(tile.y))


func landmark_at(point: Vector2) -> String:
	var nearest := ""
	var distance := INF
	for section in LANDMARKS:
		var at := landmark_center(section)
		var reach := _tile_width() * 0.55
		var unit := _tile_width() / 64.0
		var rect := Rect2(at + Vector2(-reach, -76 * unit), Vector2(reach * 2.0, 98 * unit))
		if rect.has_point(point):
			var current := rect.get_center().distance_to(point)
			if current < distance:
				distance = current
				nearest = section
	return nearest


func _gui_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and key.keycode == KEY_HOME:
		reset_camera()
		accept_event()
		return
	var button := event as InputEventMouseButton
	if button != null:
		_handle_button(button)
		return
	var motion := event as InputEventMouseMotion
	if motion == null:
		return
	if motion.button_mask & MOUSE_BUTTON_MASK_LEFT:
		if motion.position.distance_to(_press_position) > MapView.DRAG_THRESHOLD:
			_dragging = true
		if _dragging:
			_pan += motion.relative
			_clamp_pan()
			accept_event()
	_set_hovered("" if _dragging else landmark_at(motion.position))


func _handle_button(button: InputEventMouseButton) -> void:
	match button.button_index:
		MOUSE_BUTTON_WHEEL_UP when button.pressed:
			zoom_at(button.position, MapView.ZOOM_STEP)
		MOUSE_BUTTON_WHEEL_DOWN when button.pressed:
			zoom_at(button.position, 1.0 / MapView.ZOOM_STEP)
		MOUSE_BUTTON_LEFT when button.pressed:
			grab_focus()
			_press_position = button.position
			_dragging = false
		MOUSE_BUTTON_LEFT:
			# A drag pans the town; only a click without travel opens a landmark.
			if not _dragging:
				var section := landmark_at(button.position)
				if not section.is_empty():
					landmark_selected.emit(section)
			_dragging = false
		_:
			return
	accept_event()


func _set_hovered(section: String) -> void:
	_hovered = section
	tooltip_text = _landmark_name(section) if not section.is_empty() else ""
	mouse_default_cursor_shape = (
		Control.CURSOR_ARROW if section.is_empty() else Control.CURSOR_POINTING_HAND
	)


## Zoom around the cursor so the inspected building stays under the pointer.
func zoom_at(point: Vector2, factor: float) -> void:
	var old := _zoom
	_zoom = clampf(_zoom * factor, MIN_ZOOM, MAX_ZOOM)
	var centre := size * 0.5
	_pan = point - centre - (point - centre - _pan) * (_zoom / old)
	_clamp_pan()


func reset_camera() -> void:
	_zoom = 1.0
	_pan = Vector2.ZERO
	_dragging = false
	queue_redraw()


## Keeps the view's centre within the town's ground, so the player can't lose it in open water.
func _clamp_pan() -> void:
	var unit := _tile_width()
	# The ground diamond spans half a tile width per tile each side, and a quarter per tile down.
	var half_width := float(GRID_SIZE - 1) * 0.5 * unit
	var north := -VIEW_CENTRE_DEPTH * unit
	var south := (float(GRID_SIZE - 1) * 0.5 - VIEW_CENTRE_DEPTH) * unit
	_pan = Vector2(clampf(_pan.x, -half_width, half_width), clampf(_pan.y, -south, -north))
	queue_redraw()
