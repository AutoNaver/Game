class_name CityArt
extends RefCounted
## Original procedural isometric artwork. Coordinates are local to a 64-pixel ground tile.
## All variation is derived from plot coordinates, leaving simulation randomness untouched.

var canvas: Control


func _poly(points: Array[Vector2], color: Color) -> void:
	canvas.draw_colored_polygon(PackedVector2Array(points), color)


func house(at: Vector2, scale_factor: float, seed_value: int, accent: Color, civic: bool) -> void:
	canvas.draw_set_transform(at, 0, Vector2.ONE * scale_factor)
	var w := 23.0 if civic else 19.0
	var d := w * 0.5
	var floors := 2 + seed_value % 2
	var h := float(floors) * 15.0 + (9.0 if civic else 0.0)
	var peak := 18.0
	var plaster := Color("#c6b58e") if seed_value % 2 == 0 else Color("#a87557")
	var timber := Color("#514638") if seed_value % 3 != 0 else Color("#baa58a")
	var roof := Color("#9b4f36").lightened(float(seed_value % 4) * 0.035)
	_poly(
		[Vector2(-w, 0), Vector2(0, d), Vector2(w + 27, -4), Vector2(13, -d - 12)],
		Color(0.12, 0.17, 0.12, 0.28)
	)
	_poly([Vector2(-w, 0), Vector2(0, d), Vector2(0, d - h), Vector2(-w, -h)], plaster)
	_poly([Vector2(0, d), Vector2(w, 0), Vector2(w, -h), Vector2(0, d - h)], plaster.darkened(0.25))
	# Front gable faces the street; ridge runs back along the long roof plane.
	_poly(
		[Vector2(-w, -h), Vector2(0, d - h), Vector2(-w * 0.5, d * 0.5 - h - peak)],
		plaster.lightened(0.1)
	)
	_poly(
		[
			Vector2(-w * 0.5, d * 0.5 - h - peak),
			Vector2(w * 0.5, -d * 0.5 - h - peak),
			Vector2(w + 3, -h),
			Vector2(0, d - h)
		],
		roof
	)
	canvas.draw_line(
		Vector2(-w - 2, -h), Vector2(-w * 0.5, d * 0.5 - h - peak), Color("#dbc39a"), 2
	)
	canvas.draw_line(Vector2(-w * 0.5, d * 0.5 - h - peak), Vector2(1, d - h), Color("#dbc39a"), 2)
	if seed_value % 3 == 0 or civic:
		for step in 5:
			var t := float(step) / 5
			var left := Vector2(-w, -h).lerp(Vector2(-w * 0.5, d * 0.5 - h - peak), t)
			var right := Vector2(0, d - h).lerp(Vector2(-w * 0.5, d * 0.5 - h - peak), t)
			canvas.draw_rect(Rect2(left - Vector2(1, 4), Vector2(5, 5)), Color("#cbbd9b"))
			canvas.draw_rect(Rect2(right - Vector2(4, 4), Vector2(5, 5)), Color("#cbbd9b"))
	for row in range(1, 7):
		var t := float(row) / 7.0
		var start := Vector2(-w * 0.5, d * 0.5 - h - peak).lerp(Vector2(0, d - h), t)
		var end := Vector2(w * 0.5, -d * 0.5 - h - peak).lerp(Vector2(w + 3, -h), t)
		canvas.draw_line(start, end, roof.darkened(0.17), 0.8)
		for col in range(1, 6):
			var p := start.lerp(end, float(col) / 6.0)
			canvas.draw_line(p, p + Vector2(1.6, 2.5), roof.lightened(0.13), 0.6)
	for floor_index in floors:
		var level := -float(floor_index) * h / float(floors)
		canvas.draw_line(Vector2(-w, level), Vector2(0, d + level), timber, 1.8)
		canvas.draw_line(Vector2(0, d + level), Vector2(w, level), timber, 1.8)
		for col in 2:
			var x := -w + 5 + float(col) * w * 0.48
			var y := (x + w) * 0.5 + level - 10
			_poly(
				[
					Vector2(x, y),
					Vector2(x + 5, y + 2.5),
					Vector2(x + 5, y + 9),
					Vector2(x, y + 6.5)
				],
				Color("#354044")
			)
			canvas.draw_line(
				Vector2(x + 2.5, y + 1), Vector2(x + 2.5, y + 8), Color("#c6b48b"), 0.8
			)
			_poly(
				[
					Vector2(-x, y),
					Vector2(-x - 5, y + 2.5),
					Vector2(-x - 5, y + 9),
					Vector2(-x, y + 6.5)
				],
				Color("#283538")
			)
	for x: float in [-w, -w * 0.5, 0.0]:
		var y := (x + w) * 0.5
		canvas.draw_line(Vector2(x, y), Vector2(x, y - h), timber, 2)
	canvas.draw_line(Vector2(w, 0), Vector2(w, -h), timber, 2)
	canvas.draw_line(
		Vector2(-w * 0.5, d * 0.5 - h), Vector2(-w * 0.5, d * 0.5 - h - peak + 3), timber, 2
	)
	_poly(
		[Vector2(-13, 3), Vector2(-6, 6.5), Vector2(-6, -5), Vector2(-13, -8.5)], Color("#4b382b")
	)
	canvas.draw_circle(Vector2(-8, 0), 0.8, Color("#d0ac66"))
	canvas.draw_rect(Rect2(8, -h - 17, 5, 17), Color("#785744"))
	canvas.draw_rect(Rect2(7, -h - 18, 7, 3), Color("#c0a284"))
	# Ownership is a hanging banner, so masonry remains natural across trading houses.
	if accent.a > 0:
		canvas.draw_line(Vector2(w, -h + 4), Vector2(w + 10, -h), timber, 1.5)
		_poly(
			[
				Vector2(w + 4, -h + 1),
				Vector2(w + 10, -h - 2),
				Vector2(w + 10, -h + 13),
				Vector2(w + 7, -h + 11),
				Vector2(w + 4, -h + 16)
			],
			accent
		)
	canvas.draw_set_transform(Vector2.ZERO)


func tree(at: Vector2, scale_factor: float, seed_value: int) -> void:
	canvas.draw_set_transform(at, 0, Vector2.ONE * scale_factor)
	canvas.draw_circle(Vector2(6, 0), 10, Color(0.1, 0.17, 0.1, 0.25))
	canvas.draw_line(Vector2.ZERO, Vector2(0, -27), Color("#66503a"), 4)
	for i in 5:
		var p := Vector2(float((i * 7) % 13) - 6, -19 - float(i * 5))
		canvas.draw_circle(
			p, 10 - float(i), Color("#345638").lightened(float((i + seed_value) % 4) * 0.045)
		)
	canvas.draw_set_transform(Vector2.ZERO)


func stall(at: Vector2, scale_factor: float, color: Color) -> void:
	canvas.draw_set_transform(at, 0, Vector2.ONE * scale_factor)
	for x: float in [-17.0, 17.0]:
		canvas.draw_line(Vector2(x, 1), Vector2(x, -23), Color("#725136"), 2)
	_poly([Vector2(-19, -20), Vector2(0, -31), Vector2(19, -21), Vector2(0, -11)], color)
	for i in range(-2, 3):
		canvas.draw_line(
			Vector2(i * 6, -23 + abs(i) * 2),
			Vector2(i * 6 + 9, -18 + abs(i) * 2),
			Color("#e6d8b8"),
			3
		)
	_poly([Vector2(-17, -3), Vector2(0, 5), Vector2(17, -3), Vector2(0, -11)], Color("#a88957"))
	for i in 7:
		canvas.draw_circle(Vector2(float(i * 11 % 25) - 12, -3 - float(i % 3)), 2, Color("#b6ac5b"))
	canvas.draw_set_transform(Vector2.ZERO)


func cargo(at: Vector2, scale_factor: float) -> void:
	canvas.draw_set_transform(at, 0, Vector2.ONE * scale_factor)
	for i in 3:
		var p := Vector2(float(i) * 7 - 8, -float(i % 2) * 5)
		canvas.draw_rect(Rect2(p - Vector2(4, 7), Vector2(8, 9)), Color("#987249"))
		canvas.draw_circle(p + Vector2(0, -7), 4, Color("#bb9869"))
		canvas.draw_line(p + Vector2(-4, -4), p + Vector2(4, -4), Color("#4e493c"), 1)
		canvas.draw_line(p + Vector2(-4, 0), p + Vector2(4, 0), Color("#4e493c"), 1)
	canvas.draw_set_transform(Vector2.ZERO)


func ship(at: Vector2, scale_factor: float, color: Color) -> void:
	canvas.draw_set_transform(at, 0, Vector2.ONE * scale_factor)
	_poly(
		[Vector2(-30, -3), Vector2(-12, -16), Vector2(32, 5), Vector2(23, 19), Vector2(2, 18)],
		Color("#48372b")
	)
	_poly(
		[Vector2(-28, -8), Vector2(-12, -20), Vector2(32, 0), Vector2(22, 12), Vector2(1, 12)],
		Color("#b09260")
	)
	for i in 6:
		canvas.draw_line(
			Vector2(-21 + i * 7, -11 + i * 3),
			Vector2(-15 + i * 7, -16 + i * 3),
			Color("#715539"),
			1
		)
	canvas.draw_line(Vector2(0, 1), Vector2(0, -65), Color("#584232"), 2.5)
	canvas.draw_line(Vector2(-27, -8), Vector2(0, -61), Color("#c2b58e"), 0.8)
	canvas.draw_line(Vector2(29, 0), Vector2(0, -61), Color("#c2b58e"), 0.8)
	_poly([Vector2(2, -57), Vector2(22, -22), Vector2(3, -27)], Color("#ddd4b5"))
	_poly([Vector2(-2, -52), Vector2(-19, -31), Vector2(-2, -26)], Color("#bdb697"))
	_poly([Vector2(0, -65), Vector2(17, -62), Vector2(12, -55), Vector2(0, -58)], color)
	canvas.draw_set_transform(Vector2.ZERO)


func person(at: Vector2, scale_factor: float, index: int, phase: float) -> void:
	canvas.draw_set_transform(at, 0, Vector2.ONE * scale_factor)
	var colors: Array[Color] = [
		Color("#6b4473"), Color("#345d87"), Color("#aa4d39"), Color("#b39c66")
	]
	var stride := sin(phase * 7 + index) * 2
	canvas.draw_circle(Vector2(2, 0), 3, Color(0.1, 0.13, 0.1, 0.25))
	canvas.draw_line(Vector2(0, -3), Vector2(-2, 1 + stride), Color("#403c32"), 1.4)
	canvas.draw_line(Vector2(0, -3), Vector2(2, 1 - stride), Color("#403c32"), 1.4)
	_poly(
		[Vector2(-2, -10), Vector2(2, -10), Vector2(3, -2), Vector2(-3, -2)],
		colors[index % colors.size()]
	)
	canvas.draw_circle(Vector2(0, -12), 2, Color("#d1b189"))
	canvas.draw_set_transform(Vector2.ZERO)
