class_name MapView
extends Control
## Schematic Baltic map: cities as dots, the player's ships as markers with their route.
## Click a city to select it. Placeholder art until real map assets exist.

const MARGIN: float = 60.0
const CITY_RADIUS: float = 9.0
const CLICK_RADIUS: float = 24.0
const SEA_COLOR: Color = Color(0.13, 0.25, 0.38)
const CITY_COLOR: Color = Color(0.93, 0.86, 0.68)
const SELECTED_COLOR: Color = Color(1.0, 0.82, 0.2)
const SHIP_COLOR: Color = Color(0.95, 0.35, 0.3)
const ROUTE_COLOR: Color = Color(1.0, 1.0, 1.0, 0.35)

var _session: GameSession


func setup(session: GameSession) -> void:
	_session = session
	_session.changed.connect(queue_redraw)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), SEA_COLOR)
	if _session == null or _session.sim == null:
		return
	var data := _session.sim.data
	var font := get_theme_default_font()
	for city in data.cities:
		var at := to_screen(city.map_position)
		if city.id == _session.selected_city:
			draw_arc(at, CITY_RADIUS + 5.0, 0.0, TAU, 32, SELECTED_COLOR, 2.0)
		draw_circle(at, CITY_RADIUS, CITY_COLOR)
		draw_string(font, at + Vector2(CITY_RADIUS + 4.0, 5.0), city.name)
	for ship in _session.player().ships:
		_draw_ship(ship)


func _draw_ship(ship: ShipState) -> void:
	var data := _session.sim.data
	var at := to_screen(Navigation.position(data, ship))
	if not ship.is_docked():
		draw_dashed_line(at, to_screen(data.get_city(ship.destination).map_position), ROUTE_COLOR)
	if ship.is_docked():
		at += Vector2(-CITY_RADIUS - 8.0, -CITY_RADIUS - 4.0)
	var color := SELECTED_COLOR if ship.id == _session.selected_ship else SHIP_COLOR
	var marker := PackedVector2Array([at + Vector2(0, -9), at + Vector2(8, 7), at + Vector2(-8, 7)])
	draw_colored_polygon(marker, color)


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	var city_id := city_at(click.position)
	if not city_id.is_empty():
		_session.select_city(city_id)
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


## Maps map units to control pixels, fitting all cities with a margin and keeping the aspect ratio.
func to_screen(map_point: Vector2) -> Vector2:
	var bounds := _map_bounds()
	var usable := (size - Vector2.ONE * MARGIN * 2.0).max(Vector2.ONE)
	var scale_factor := minf(usable.x / bounds.size.x, usable.y / bounds.size.y)
	var offset := (size - bounds.size * scale_factor) / 2.0
	return offset + (map_point - bounds.position) * scale_factor


func _map_bounds() -> Rect2:
	var cities := _session.sim.data.cities
	var bounds := Rect2(cities[0].map_position, Vector2.ZERO)
	for city in cities:
		bounds = bounds.expand(city.map_position)
	return Rect2(bounds.position, bounds.size.max(Vector2.ONE))
