extends GutTest
## Sea chart routing, and the shipped lanes checked against the rendered coastline.

## Harbours sit up rivers or inside archipelagos, so lanes may cross land this close to a city.
const HARBOUR_KM: float = 30.0


func _square_chart() -> SeaChart:
	# a(0,0) - b(100,0) - c(100,100), plus a long detour a - d(0,300) - c.
	var chart := SeaChart.new()
	chart.add_node("a", Vector2(0, 0))
	chart.add_node("b", Vector2(100, 0))
	chart.add_node("c", Vector2(100, 100))
	chart.add_node("d", Vector2(0, 300))
	chart.add_node("island", Vector2(500, 500))
	for lane: Array in [["a", "b"], ["b", "c"], ["a", "d"], ["d", "c"]]:
		chart.add_lane(lane[0], lane[1])
	return chart


func test_route_takes_the_shortest_path() -> void:
	var route := _square_chart().route("a", "c")
	assert_eq(route, PackedVector2Array([Vector2(0, 0), Vector2(100, 0), Vector2(100, 100)]))
	assert_eq(SeaChart.length_of(route), 200.0)


func test_route_to_an_unconnected_node_is_empty() -> void:
	assert_true(_square_chart().route("a", "island").is_empty())
	assert_true(_square_chart().route("a", "nowhere").is_empty())


func test_point_along_walks_the_polyline() -> void:
	var route := _square_chart().route("a", "c")
	assert_eq(SeaChart.point_along(route, 0.0), Vector2(0, 0))
	assert_eq(SeaChart.point_along(route, 150.0), Vector2(100, 50))
	assert_eq(SeaChart.point_along(route, 999.0), Vector2(100, 100), "clamped to the end")


func test_remainder_starts_at_the_current_point() -> void:
	var route := _square_chart().route("a", "c")
	assert_eq(
		SeaChart.remainder_from(route, 50.0),
		PackedVector2Array([Vector2(50, 0), Vector2(100, 0), Vector2(100, 100)])
	)
	assert_eq(
		SeaChart.remainder_from(route, 150.0),
		PackedVector2Array([Vector2(100, 50), Vector2(100, 100)])
	)


func test_ship_moves_along_the_lanes_not_straight() -> void:
	var sim := Simulation.new_game(GameDataLoader.new().load_dir(GameDataLoader.DEFAULT_DIR), 1)
	var ship := sim.world.player().ships[0]
	sim.execute(SailCommand.new(WorldState.PLAYER_ID, ship.id, "danzig"))
	var route := sim.data.sea_chart.route("lubeck", "danzig")
	assert_eq(ship.voyage_hours, ceili(SeaChart.length_of(route) / 8.0))
	for i in ship.voyage_hours / 2:
		sim.tick()
	var at := Navigation.position(sim.data, ship)
	var sailed := SeaChart.length_of(route) * float(ship.hours_sailed) / ship.voyage_hours
	assert_almost_eq(at.distance_to(SeaChart.point_along(route, sailed)), 0.0, 0.001)


func test_shipped_lanes_stay_on_water() -> void:
	var data := GameDataLoader.new().load_dir(GameDataLoader.DEFAULT_DIR)
	var image := (load(data.map.image) as Texture2D).get_image()
	var pixels_per_km := image.get_width() / data.map.size_km().x
	for from_city in data.cities:
		for to_city in data.cities:
			if from_city.id >= to_city.id:
				continue
			var route := data.sea_chart.route(from_city.id, to_city.id)
			var land_km := 0
			for km in int(SeaChart.length_of(route)):
				var at := SeaChart.point_along(route, km)
				if _near_city(data, at):
					continue
				var colour := image.get_pixelv(Vector2i(at * pixels_per_km))
				if colour.r > colour.b:
					land_km += 1
			assert_eq(land_km, 0, "%s-%s crosses land" % [from_city.id, to_city.id])


func _near_city(data: GameData, at: Vector2) -> bool:
	for city in data.cities:
		if city.map_position.distance_to(at) <= HARBOUR_KM:
			return true
	return false
