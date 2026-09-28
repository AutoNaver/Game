class_name CityView
extends Control
## A visual town scene for the selected city. Plots are derived from stable workshop ids until
## construction makes positions part of the simulation in M17. Walkers use UI time only.

signal landmark_selected(section: String)

const GRID_SIZE: int = 14
const MAX_WALKERS: int = 24
const GROUND: Color = Color("#56705c")
const ROAD: Color = Color("#9c9279")
const WALL: Color = Color("#c0ae89")
const WATER: Color = Color("#244354")
const ROOF: Color = Color("#a4543e")
const PLAYER: Color = Color("#d4ae5a")
const LABEL_OUTLINE: Color = Color("#18232b")

var _session: GameSession
var _phase: float = 0.0


func setup(session: GameSession) -> void:
	_session = session
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_session.changed.connect(queue_redraw)
	resized.connect(queue_redraw)
	set_process(false)


func set_city_visible(value: bool) -> void:
	visible = value
	set_process(value)
	if value:
		queue_redraw()


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
	var road_col := 5 + variant % 3
	@warning_ignore("integer_division")
	var road_row := 5 + variant / 3
	_draw_ground(variant, road_col, road_row)
	_draw_walls(variant)
	_draw_decorative_houses(variant, road_col, road_row)
	_draw_landmarks(road_col, road_row)
	_draw_workshops()
	_draw_ships(city_id)
	_draw_walkers(city_id, road_col, road_row)
	_draw_title(city_def.name)


func _draw_ground(variant: int, road_col: int, road_row: int) -> void:
	for y in GRID_SIZE:
		for x in GRID_SIZE:
			var road := x == road_col or y == road_row or (y == road_row + 3 and x >= road_col)
			var tint := float((x * 7 + y * 11 + variant * 3) % 5) * 0.015
			var color := ROAD if road else GROUND.lightened(tint)
			_draw_tile(x, y, color)
	# A jetty leading into the harbour makes the shoreline legible in every layout.
	var jetty := _tile_center(road_col + 3.0, road_row + 3.0)
	var mooring := _tile_center(16.0, 8.0)
	draw_line(jetty, mooring, Color("#806e55"), 12.0, true)
	draw_line(jetty, mooring, Color("#b0966e"), 8.0, true)


func _draw_tile(x: int, y: int, color: Color) -> void:
	var at := _tile_center(float(x), float(y))
	var half_w := _tile_width() * 0.5
	var half_h := _tile_width() * 0.25
	var poly := PackedVector2Array(
		[
			at + Vector2(0, -half_h),
			at + Vector2(half_w, 0),
			at + Vector2(0, half_h),
			at + Vector2(-half_w, 0)
		]
	)
	draw_colored_polygon(poly, color)
	draw_polyline(
		PackedVector2Array([poly[0], poly[1], poly[2], poly[3], poly[0]]), Color(0, 0, 0, 0.08), 1.0
	)


func _draw_walls(variant: int) -> void:
	var corners := PackedVector2Array(
		[
			_tile_center(-0.7, -0.7),
			_tile_center(GRID_SIZE - 0.3, -0.7),
			_tile_center(GRID_SIZE - 0.3, GRID_SIZE - 0.3),
			_tile_center(-0.7, GRID_SIZE - 0.3),
			_tile_center(-0.7, -0.7),
		]
	)
	draw_polyline(corners, Color("#514d45"), 10.0, true)
	draw_polyline(corners, WALL.lightened(float(variant % 3) * 0.05), 6.0, true)
	for i in 4:
		var corner := corners[i]
		draw_circle(corner, 7.0, Color("#5d5549"))
		draw_circle(corner + Vector2(0, -3), 6.0, WALL)


func _draw_decorative_houses(variant: int, road_col: int, road_row: int) -> void:
	var reserved := _landmark_tiles(road_col, road_row)
	var workshops := workshop_plots().values()
	for y in range(1, GRID_SIZE - 1):
		for x in range(1, GRID_SIZE - 1):
			if x == road_col or y == road_row or (y == road_row + 3 and x >= road_col):
				continue
			if reserved.has(Vector2i(x, y)) or workshops.has(Vector2i(x, y)):
				continue
			if (x * 13 + y * 17 + variant * 19) % 4 != 0:
				continue
			var at := _tile_center(float(x), float(y))
			_draw_block(at, 11.0, Color("#d4c19b"), ROOF.darkened(float((x + y) % 3) * 0.12), 0.48)


func _draw_landmarks(road_col: int, road_row: int) -> void:
	for section: String in ["market", "tavern", "shipyard", "kontor", "town_hall"]:
		var plot := _landmark_tile(section, road_col, road_row)
		var at := _tile_center(float(plot.x), float(plot.y))
		var color := Color("#cbb78e")
		if section == "shipyard":
			color = Color("#ad9a77")
		elif section == "town_hall":
			color = Color("#ddd0ae")
		elif section == "kontor":
			color = (
				PLAYER
				if _session.player().get_kontor(_session.selected_city) != null
				else Color("#ada18c")
			)
		_draw_block(at, 23.0 if section == "town_hall" else 17.0, color, ROOF, 0.78)
		_draw_label(at + Vector2(0, -30), _landmark_name(section), 13)


func _draw_workshops() -> void:
	var plots := workshop_plots()
	for trader in _session.sim.world.traders:
		var kontor := trader.get_kontor(_session.selected_city)
		if kontor == null:
			continue
		for workshop in kontor.workshops:
			if not plots.has(workshop.id):
				continue
			var plot: Vector2i = plots[workshop.id]
			var at := _tile_center(float(plot.x), float(plot.y))
			var color := (
				PLAYER
				if trader.id == WorldState.PLAYER_ID
				else MapView.house_color(_session.sim.data, trader.id)
			)
			_draw_block(at, 14.0, color, Color("#494b4a"), 0.6)
			# A short chimney marks workshops separately from decorative housing.
			draw_line(at + Vector2(7, -20), at + Vector2(7, -28), Color("#45423e"), 4.0)
			if trader.id == WorldState.PLAYER_ID:
				_draw_label(
					at + Vector2(0, -29), _session.sim.data.get_workshop(workshop.type_id).name, 11
				)


## Stable UI-only plots for the workshops in the selected city. M17 will save player-chosen plots.
func workshop_plots() -> Dictionary[String, Vector2i]:
	var result: Dictionary[String, Vector2i] = {}
	if _session == null or _session.sim == null:
		return result
	var variant := _city_variant(_session.selected_city)
	var road_col := 5 + variant % 3
	@warning_ignore("integer_division")
	var road_row := 5 + variant / 3
	var reserved := _landmark_tiles(road_col, road_row)
	var candidates: Array[Vector2i] = []
	for y in range(1, GRID_SIZE - 1):
		for x in range(1, GRID_SIZE - 1):
			var plot := Vector2i(x, y)
			if x == road_col or y == road_row or (y == road_row + 3 and x >= road_col):
				continue
			if not reserved.has(plot):
				candidates.append(plot)
	var ids := PackedStringArray()
	for trader in _session.sim.world.traders:
		var kontor := trader.get_kontor(_session.selected_city)
		if kontor != null:
			for workshop in kontor.workshops:
				ids.append(workshop.id)
	ids.sort()
	var occupied: Array[Vector2i] = []
	for id in ids:
		@warning_ignore("integer_division")
		var start := (int(id.trim_prefix("workshop_")) * 37 + variant * 11) % candidates.size()
		for offset in candidates.size():
			var plot := candidates[(start + offset) % candidates.size()]
			if not occupied.has(plot):
				result[id] = plot
				occupied.append(plot)
				break
	return result


func _draw_ships(city_id: String) -> void:
	var index := 0
	for trader in _session.sim.world.traders:
		for ship in trader.ships:
			if ship.docked_at != city_id:
				continue
			var at := _tile_center(16.0, 8.0) + Vector2(24 * index, 13 * index)
			var color := (
				PLAYER
				if trader.id == WorldState.PLAYER_ID
				else MapView.house_color(_session.sim.data, trader.id)
			)
			var hull := PackedVector2Array(
				[at + Vector2(-13, 2), at + Vector2(13, 2), at + Vector2(8, 8), at + Vector2(-8, 8)]
			)
			draw_colored_polygon(hull, Color("#503b32"))
			draw_line(at + Vector2(0, 1), at + Vector2(0, -17), color, 2.0)
			draw_colored_polygon(
				PackedVector2Array(
					[at + Vector2(1, -15), at + Vector2(10, -2), at + Vector2(1, -2)]
				),
				color
			)
			if trader.id == WorldState.PLAYER_ID:
				_draw_label(at + Vector2(0, 22), ship.name, 11)
			index += 1


func _draw_walkers(city_id: String, road_col: int, road_row: int) -> void:
	var city := _session.sim.world.get_city(city_id)
	var employed := CityEconomy.workers_employed(_session.sim.data, _session.sim.world, city_id)
	var count := clampi(4 + city.population / 1000 + employed / 100, 4, MAX_WALKERS)
	for i in count:
		var shift := float(i) * 1.91
		var travel := fposmod(_phase * (0.45 + float(i % 3) * 0.08) + shift, GRID_SIZE - 1.0)
		var at := (
			_tile_center(travel, float(road_row))
			if i % 2 == 0
			else _tile_center(float(road_col), travel)
		)
		var color := Color("#e7d6ae") if i % 3 == 0 else Color("#364d5a")
		draw_circle(at + Vector2(0, -5), 2.5, color)
		draw_line(at + Vector2(0, -2), at + Vector2(0, 2), color, 2.0)


func _draw_title(city_name: String) -> void:
	var font := get_theme_default_font()
	var width := font.get_string_size(city_name, 0, -1, 24).x
	draw_string(
		font,
		Vector2(size.x - width - 20, 35),
		city_name,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		24,
		UiStyle.GOLD
	)
	var hint := "Town view · click a landmark"
	width = font.get_string_size(hint, 0, -1, 13).x
	draw_string(
		font, Vector2(size.x - width - 20, 56), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UiStyle.INK
	)


func _draw_block(
	at: Vector2, height: float, wall_color: Color, roof_color: Color, scale_factor: float
) -> void:
	var half_w := _tile_width() * 0.5 * scale_factor
	var half_h := _tile_width() * 0.25 * scale_factor
	var top := at + Vector2(0, -height)
	var front := PackedVector2Array(
		[
			top + Vector2(-half_w, 0),
			top + Vector2(0, half_h),
			at + Vector2(0, half_h),
			at + Vector2(-half_w, 0)
		]
	)
	var side := PackedVector2Array(
		[
			top + Vector2(0, half_h),
			top + Vector2(half_w, 0),
			at + Vector2(half_w, 0),
			at + Vector2(0, half_h)
		]
	)
	var roof := PackedVector2Array(
		[
			top + Vector2(0, -half_h),
			top + Vector2(half_w, 0),
			top + Vector2(0, half_h),
			top + Vector2(-half_w, 0)
		]
	)
	draw_colored_polygon(front, wall_color.darkened(0.18))
	draw_colored_polygon(side, wall_color.darkened(0.32))
	draw_colored_polygon(roof, roof_color)


func _draw_label(at: Vector2, value: String, font_size: int) -> void:
	var font := get_theme_default_font()
	var width := font.get_string_size(value, 0, -1, font_size).x
	var where := at - Vector2(width * 0.5, 0)
	draw_string_outline(
		font, where, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 3, LABEL_OUTLINE
	)
	draw_string(font, where, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, UiStyle.INK)


func _tile_width() -> float:
	return minf(50.0, minf(size.x / 16.0, size.y / 10.0))


func _tile_center(x: float, y: float) -> Vector2:
	var unit := _tile_width()
	return Vector2(size.x * 0.5 + (x - y) * unit * 0.5, size.y * 0.20 + (x + y) * unit * 0.25)


func _city_variant(city_id: String) -> int:
	for i in _session.sim.data.cities.size():
		if _session.sim.data.cities[i].id == city_id:
			return i
	return 0


func _landmark_tiles(road_col: int, road_row: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for section: String in ["market", "tavern", "shipyard", "kontor", "town_hall"]:
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
	var variant := _city_variant(_session.selected_city)
	@warning_ignore("integer_division")
	var tile := _landmark_tile(section, 5 + variant % 3, 5 + variant / 3)
	return _tile_center(float(tile.x), float(tile.y))


func landmark_at(point: Vector2) -> String:
	var nearest := ""
	var distance := INF
	for section: String in ["market", "tavern", "shipyard", "kontor", "town_hall"]:
		var at := landmark_center(section)
		var reach := _tile_width() * 0.55
		var rect := Rect2(at + Vector2(-reach, -36), Vector2(reach * 2.0, 48))
		if rect.has_point(point):
			var current := rect.get_center().distance_to(point)
			if current < distance:
				distance = current
				nearest = section
	return nearest


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT and not button.pressed:
		var section := landmark_at(button.position)
		if not section.is_empty():
			landmark_selected.emit(section)
			accept_event()
	var motion := event as InputEventMouseMotion
	if motion != null:
		var section := landmark_at(motion.position)
		tooltip_text = _landmark_name(section) if not section.is_empty() else ""
