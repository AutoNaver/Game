class_name SeaChart
extends RefCounted
## The network ships sail on, loaded from data/sea_lanes.json: cities and open-sea waypoints
## (nodes) joined by straight lanes. A voyage follows the shortest path through the network, so
## ships go around coasts instead of across them. Positions are map units (km, see MapDef).

## Node positions by id, cities and waypoints alike.
var _positions: Dictionary[String, Vector2] = {}
## Node ids in the order they were added; used to break ties deterministically.
var _order: Array[String] = []
var _neighbours: Dictionary[String, PackedStringArray] = {}
## Every lane as [a, b] in the order added.
var _lanes: Array[PackedStringArray] = []
## Shortest routes already computed, keyed "from>to".
var _routes: Dictionary[String, PackedVector2Array] = {}


func add_node(id: String, position: Vector2) -> void:
	assert(not has_node(id), "duplicate sea chart node '%s'" % id)
	_positions[id] = position
	_order.append(id)
	_neighbours[id] = PackedStringArray()


func has_node(id: String) -> bool:
	return _positions.has(id)


func has_lane(a: String, b: String) -> bool:
	return has_node(a) and _neighbours[a].has(b)


func add_lane(a: String, b: String) -> void:
	assert(has_node(a) and has_node(b) and a != b, "invalid lane %s-%s" % [a, b])
	_neighbours[a].append(b)
	_neighbours[b].append(a)
	_lanes.append(PackedStringArray([a, b]))
	_routes.clear()


## Every configured lane as its two end points, in the order added (used / unused by routes alike).
func lane_segments() -> Array[PackedVector2Array]:
	var segments: Array[PackedVector2Array] = []
	for lane in _lanes:
		segments.append(PackedVector2Array([_positions[lane[0]], _positions[lane[1]]]))
	return segments


## Waypoints of the shortest route from one node to another, both ends included.
## Empty if the network does not connect them.
func route(from_id: String, to_id: String) -> PackedVector2Array:
	var key := "%s>%s" % [from_id, to_id]
	if not _routes.has(key):
		_routes[key] = _shortest_route(from_id, to_id)
	return _routes[key]


## Total length of a polyline in km.
static func length_of(points: PackedVector2Array) -> float:
	var total := 0.0
	for i in range(1, points.size()):
		total += points[i - 1].distance_to(points[i])
	return total


## The point `distance` km along a polyline, clamped to its ends.
static func point_along(points: PackedVector2Array, distance: float) -> Vector2:
	var left := maxf(distance, 0.0)
	for i in range(1, points.size()):
		var segment := points[i - 1].distance_to(points[i])
		if left <= segment:
			return points[i - 1].lerp(points[i], left / segment if segment > 0.0 else 0.0)
		left -= segment
	return points[points.size() - 1]


## The rest of a polyline from `distance` km along it: the current point, then every later vertex.
static func remainder_from(points: PackedVector2Array, distance: float) -> PackedVector2Array:
	var rest := PackedVector2Array([point_along(points, distance)])
	var travelled := 0.0
	for i in range(1, points.size()):
		travelled += points[i - 1].distance_to(points[i])
		if travelled > distance:
			rest.append(points[i])
	return rest


## Dijkstra over the (small) network. Ties go to the node added first, so results never depend
## on dictionary ordering.
func _shortest_route(from_id: String, to_id: String) -> PackedVector2Array:
	if not has_node(from_id) or not has_node(to_id):
		return PackedVector2Array()
	var best: Dictionary[String, float] = {from_id: 0.0}
	var previous: Dictionary[String, String] = {}
	var done: Dictionary[String, bool] = {}
	while true:
		var current := ""
		for id in _order:
			if best.has(id) and not done.has(id) and (current == "" or best[id] < best[current]):
				current = id
		if current == "" or current == to_id:
			break
		done[current] = true
		for next in _neighbours[current]:
			var through := best[current] + _positions[current].distance_to(_positions[next])
			if not best.has(next) or through < best[next]:
				best[next] = through
				previous[next] = current
	if not best.has(to_id):
		return PackedVector2Array()
	var points := PackedVector2Array([_positions[to_id]])
	var id := to_id
	while previous.has(id):
		id = previous[id]
		points.append(_positions[id])
	points.reverse()
	return points
