class_name Sparkline
extends Control
## A small line chart of recent prices. The vertical range covers the values and the base price
## (marked by a faint line), and is at least MIN_SPAN of the base price tall, so small wobbles
## stay small while a real trend fills the chart.

const LINE_COLOR: Color = UiStyle.GOLD
const BASE_COLOR: Color = Color(UiStyle.INK_MUTED, 0.35)
const LINE_WIDTH: float = 1.5
## Smallest vertical range, as a fraction of the base price.
const MIN_SPAN: float = 0.2

var _values: PackedInt64Array = PackedInt64Array()
var _low: float = 0.0
var _high: float = 1.0
var _base: float = 0.5


func _init() -> void:
	custom_minimum_size = Vector2(48, 18)
	mouse_filter = Control.MOUSE_FILTER_PASS


## Shows `values` (and `base` as a reference line).
func set_values(values: PackedInt64Array, base: float) -> void:
	if values == _values and base == _base:
		return
	_values = values.duplicate()
	_base = base
	_low = base
	_high = base
	for value in values:
		if value < 0:
			continue
		_low = minf(_low, value)
		_high = maxf(_high, value)
	var missing := base * MIN_SPAN - (_high - _low)
	if missing > 0.0:
		_low -= missing / 2.0
		_high += missing / 2.0
	queue_redraw()


## The vertical range drawn, bottom to top.
func value_range() -> Vector2:
	return Vector2(_low, _high)


func point_count() -> int:
	return _values.size()


func _draw() -> void:
	var base_y := _y(_base)
	draw_line(Vector2(0, base_y), Vector2(size.x, base_y), BASE_COLOR, 1.0)
	if _values.size() < 2:
		return
	var points := PackedVector2Array()
	var step := size.x / float(_values.size() - 1)
	for i in _values.size():
		if _values[i] < 0:
			if points.size() >= 2:
				draw_polyline(points, LINE_COLOR, LINE_WIDTH, true)
			points.clear()
			continue
		points.append(Vector2(i * step, _y(float(_values[i]))))
	if points.size() >= 2:
		draw_polyline(points, LINE_COLOR, LINE_WIDTH, true)


func _y(value: float) -> float:
	var fraction := clampf((value - _low) / (_high - _low), 0.0, 1.0)
	return (1.0 - fraction) * (size.y - LINE_WIDTH) + LINE_WIDTH / 2.0
