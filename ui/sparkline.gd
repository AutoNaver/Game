class_name Sparkline
extends Control
## A small line chart of recent prices, drawn against a fixed range (the good's clamped price
## range) so lines in different rows compare at a glance. A faint line marks the base price.

const LINE_COLOR: Color = UiStyle.GOLD
const BASE_COLOR: Color = Color(UiStyle.INK_MUTED, 0.35)
const LINE_WIDTH: float = 1.5

var _values: PackedInt64Array = PackedInt64Array()
var _low: float = 0.0
var _high: float = 1.0
var _base: float = 0.5


func _init() -> void:
	custom_minimum_size = Vector2(72, 18)
	mouse_filter = Control.MOUSE_FILTER_PASS


## Shows `values` scaled so that `low` is the bottom edge and `high` the top.
func set_values(values: PackedInt64Array, low: float, high: float, base: float) -> void:
	if values == _values and low == _low and high == _high and base == _base:
		return
	_values = values.duplicate()
	_low = low
	_high = maxf(high, low + 1.0)
	_base = base
	queue_redraw()


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
		points.append(Vector2(i * step, _y(float(_values[i]))))
	draw_polyline(points, LINE_COLOR, LINE_WIDTH, true)


func _y(value: float) -> float:
	var fraction := clampf((value - _low) / (_high - _low), 0.0, 1.0)
	return (1.0 - fraction) * (size.y - LINE_WIDTH) + LINE_WIDTH / 2.0
