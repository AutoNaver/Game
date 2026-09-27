class_name MapView
extends Control
## The Baltic map with cities, the player's ships and the rival houses' ships at sea (in their
## house colours, smaller and unlabelled). Mouse wheel zooms around the cursor, dragging pans,
## clicking a city selects it. Positions are map units (km, see MapDef).

## Zoom is relative to the whole map fitting the view, so this is about 3 px per km on a
## laptop-sized window.
const MAX_ZOOM: float = 9.0
const ZOOM_STEP: float = 1.15
const CITY_RADIUS: float = 6.0
const CITY_FONT_SIZE: int = 16
const CLICK_RADIUS: float = 22.0
## Mouse travel before a press counts as a drag rather than a click.
const DRAG_THRESHOLD: float = 4.0
const BACKGROUND: Color = Color(0.106, 0.204, 0.290)
const CITY_FILL: Color = Color(0.96, 0.92, 0.80)
const CITY_OUTLINE: Color = Color(0.16, 0.12, 0.08)
const LABEL_COLOR: Color = Color(1.0, 0.97, 0.88)
const LABEL_OUTLINE: Color = Color(0.1, 0.08, 0.05, 0.9)
const SELECTED_COLOR: Color = Color(1.0, 0.8, 0.25)
const SHIP_COLOR: Color = Color(0.85, 0.2, 0.15)
const ROUTE_COLOR: Color = Color(1.0, 1.0, 1.0, 0.55)
## Rival ships are drawn at this fraction of the player's ship size.
const RIVAL_SHIP_SCALE: float = 0.75

var _session: GameSession
var _texture: Texture2D
## 1 = the map just covers the control (cropping a little along one axis).
var _zoom: float = 1.0
## Screen position of the map's north-west corner.
var _origin: Vector2 = Vector2.ZERO
var _press_position: Vector2 = Vector2.ZERO
var _dragging: bool = false


func setup(session: GameSession) -> void:
	_session = session
	_texture = load(session.sim.data.map.image)
	_session.changed.connect(queue_redraw)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	resized.connect(_clamp_view)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND)
	if _session == null or _session.sim == null:
		return
	var map_size := _session.sim.data.map.size_km()
	draw_texture_rect(_texture, Rect2(_origin, map_size * _scale()), false)
	for ship in _session.player().ships:
		if not ship.is_docked():
			_draw_route(ship)
	for trader in _session.sim.world.traders:
		if trader.id == WorldState.PLAYER_ID:
			continue
		var color := house_color(_session.sim.data, trader.id)
		for ship in trader.ships:
			if not ship.is_docked():
				_draw_rival_ship(ship, color)
	for city in _session.sim.data.cities:
		_draw_city(city)
	for ship in _session.player().ships:
		_draw_ship(ship)


func _draw_city(city: CityDef) -> void:
	var at := to_screen(city.map_position)
	if city.id == _session.selected_city:
		draw_arc(at, CITY_RADIUS + 5.0, 0.0, TAU, 32, SELECTED_COLOR, 2.5, true)
	draw_circle(at, CITY_RADIUS + 1.5, CITY_OUTLINE)
	draw_circle(at, CITY_RADIUS, CITY_FILL)
	# Right of the city, unless that runs off the view (Novgorod at the map's eastern edge).
	var width := get_theme_default_font().get_string_size(city.name, 0, -1, CITY_FONT_SIZE).x
	var offset := Vector2(CITY_RADIUS + 5.0, 5.0)
	if at.x + offset.x + width > size.x:
		offset.x = -CITY_RADIUS - 5.0 - width
	_draw_label(at + offset, city.name, CITY_FONT_SIZE)


## The rest of the ship's voyage along the sea lanes.
func _draw_route(ship: ShipState) -> void:
	var points := Navigation.remaining_route(_session.sim.data, ship)
	for i in range(1, points.size()):
		draw_dashed_line(to_screen(points[i - 1]), to_screen(points[i]), ROUTE_COLOR, 2.0, 6.0)


func _draw_ship(ship: ShipState) -> void:
	var at := to_screen(Navigation.position(_session.sim.data, ship))
	if ship.is_docked():
		at += Vector2(-CITY_RADIUS - 10.0, -CITY_RADIUS - 6.0)
	var selected := ship.id == _session.selected_ship
	var hull := PackedVector2Array(
		[at + Vector2(-9, 0), at + Vector2(9, 0), at + Vector2(6, 5), at + Vector2(-6, 5)]
	)
	var sail := PackedVector2Array([at + Vector2(0, -12), at + Vector2(7, -2), at + Vector2(0, -2)])
	draw_colored_polygon(hull, CITY_OUTLINE)
	draw_colored_polygon(sail, SELECTED_COLOR if selected else SHIP_COLOR)
	if not ship.is_docked():
		_draw_label(at + Vector2(10.0, -4.0), ship.name, 13)


## A rival house's colour from data/rivals.json; the player's ships use SHIP_COLOR.
static func house_color(data: GameData, trader_id: String) -> Color:
	var rival := data.get_rival(trader_id)
	return rival.color if rival != null else SHIP_COLOR


func _draw_rival_ship(ship: ShipState, color: Color) -> void:
	var at := to_screen(Navigation.position(_session.sim.data, ship))
	var k := RIVAL_SHIP_SCALE
	var hull := PackedVector2Array(
		[
			at + Vector2(-9, 0) * k,
			at + Vector2(9, 0) * k,
			at + Vector2(6, 5) * k,
			at + Vector2(-6, 5) * k
		]
	)
	var sail := PackedVector2Array(
		[at + Vector2(0, -12) * k, at + Vector2(7, -2) * k, at + Vector2(0, -2) * k]
	)
	draw_colored_polygon(hull, CITY_OUTLINE)
	draw_colored_polygon(sail, color)


func _draw_label(at: Vector2, text: String, font_size: int) -> void:
	var font := get_theme_default_font()
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, LABEL_OUTLINE)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, LABEL_COLOR)


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null:
		_handle_button(button)
		return
	var motion := event as InputEventMouseMotion
	if motion != null and motion.button_mask & MOUSE_BUTTON_MASK_LEFT:
		if motion.position.distance_to(_press_position) > DRAG_THRESHOLD:
			_dragging = true
		if _dragging:
			pan(motion.relative)
			accept_event()


func _handle_button(button: InputEventMouseButton) -> void:
	match button.button_index:
		MOUSE_BUTTON_WHEEL_UP when button.pressed:
			zoom_at(button.position, ZOOM_STEP)
		MOUSE_BUTTON_WHEEL_DOWN when button.pressed:
			zoom_at(button.position, 1.0 / ZOOM_STEP)
		MOUSE_BUTTON_LEFT when button.pressed:
			_press_position = button.position
			_dragging = false
		MOUSE_BUTTON_LEFT:
			if not _dragging:
				var city_id := city_at(button.position)
				if not city_id.is_empty():
					_session.select_city(city_id)
			_dragging = false
		_:
			return
	accept_event()


## Id of the city drawn nearest to `point` within CLICK_RADIUS, or "".
func city_at(point: Vector2) -> String:
	var best_id := ""
	var best_distance := CLICK_RADIUS
	for city in _session.sim.data.cities:
		var distance := to_screen(city.map_position).distance_to(point)
		if distance <= best_distance:
			best_id = city.id
			best_distance = distance
	return best_id


## Maps map units (km) to control pixels under the current zoom and pan.
func to_screen(map_point: Vector2) -> Vector2:
	return _origin + map_point * _scale()


## Zooms by `factor`, keeping the map point under `screen_point` where it is.
func zoom_at(screen_point: Vector2, factor: float) -> void:
	var map_point := (screen_point - _origin) / _scale()
	_zoom = clampf(_zoom * factor, 1.0, MAX_ZOOM)
	_origin = screen_point - map_point * _scale()
	_clamp_view()


func pan(screen_delta: Vector2) -> void:
	_origin += screen_delta
	_clamp_view()


func zoom() -> float:
	return _zoom


## Pixels per km: at zoom 1 the whole map fits the control, from Bergen to Novgorod, with open sea
## (BACKGROUND) along the sides it doesn't fill.
func _scale() -> float:
	var map_size := _session.sim.data.map.size_km()
	return minf(size.x / map_size.x, size.y / map_size.y) * _zoom


## Keeps the map covering the view where it can. Where it is smaller, it is centred across and
## kept at the top, so the spare sea is at the bottom, under the log panel (main.gd).
func _clamp_view() -> void:
	var drawn := _session.sim.data.map.size_km() * _scale()
	for axis: int in [Vector2.AXIS_X, Vector2.AXIS_Y]:
		if drawn[axis] <= size[axis]:
			var centred := (size[axis] - drawn[axis]) / 2.0
			_origin[axis] = centred if axis == Vector2.AXIS_X else 0.0
		else:
			_origin[axis] = clampf(_origin[axis], size[axis] - drawn[axis], 0.0)
	queue_redraw()
