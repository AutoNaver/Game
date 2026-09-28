class_name DataReader
extends RefCounted
## Reading and checking JSON data files: the typed field getters and error collection that
## GameDataLoader builds on. Every problem is collected in `errors` as "<where>: <problem>".

## Upper bound for plain integers. JSON allows values like 1e100 that overflow int, so anything
## beyond this is rejected as a data error.
const MAX_INT_VALUE: int = 1_000_000_000

## Problems found by the last load_dir() call, formatted as "<file>[<index>]: <message>".
var errors: PackedStringArray = []

var _id_pattern: RegEx = RegEx.create_from_string("^[a-z][a-z0-9_]*$")


func _read_array(path: String) -> Array:
	var value: Variant = _read_json(path, TYPE_ARRAY)
	return value as Array if value != null else []


## Returns the parsed top-level value, or null after reporting why it is unusable.
func _read_json(path: String, expected_type: Variant.Type) -> Variant:
	var file_name := path.get_file()
	if not FileAccess.file_exists(path):
		_error(file_name, "file not found at %s" % path)
		return null
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		# get_error_line() is 0-based; editors count from 1.
		var line := json.get_error_line() + 1
		_error(file_name, "invalid JSON at line %d: %s" % [line, json.get_error_message()])
		return null
	if typeof(json.data) != expected_type:
		var expected := "an array" if expected_type == TYPE_ARRAY else "an object"
		_error(file_name, "top level must be %s" % expected)
		return null
	return json.data


## Returns the array in `field`, or an empty one after reporting that it is not an array.
func _get_array(entry: Dictionary, field: String, ctx: String) -> Array:
	if not entry.has(field):
		return []
	if not entry[field] is Array:
		_error(ctx, "'%s' must be an array" % field)
		return []
	return entry[field] as Array


## Reports missing and unknown fields. The typed getters below skip missing fields so each
## problem is reported once.
func _check_fields(
	entry: Dictionary,
	fields: PackedStringArray,
	ctx: String,
	optional: PackedStringArray = PackedStringArray(),
) -> void:
	for field in fields:
		if not entry.has(field):
			_error(ctx, "missing field '%s'" % field)
	for key: Variant in entry.keys():
		if not fields.has(str(key)) and not optional.has(str(key)):
			_error(ctx, "unknown field '%s'" % key)


func _get_string(entry: Dictionary, field: String, ctx: String) -> String:
	if not entry.has(field):
		return ""
	var value: Variant = entry[field]
	if not value is String or (value as String).strip_edges().is_empty():
		_error(ctx, "'%s' must be a non-empty string" % field)
		return ""
	return value as String


func _get_id(entry: Dictionary, ctx: String) -> String:
	var id := _get_string(entry, "id", ctx)
	if not id.is_empty() and _id_pattern.search(id) == null:
		_error(ctx, "'id' must be lower snake_case (got '%s')" % id)
	return id


func _get_positive_int(entry: Dictionary, field: String, ctx: String) -> int:
	if not entry.has(field):
		return 0
	var value: Variant = entry[field]
	# JSON numbers arrive as floats; accept only whole values.
	if not (value is int or value is float):
		_error(ctx, "'%s' must be a positive integer" % field)
		return 0
	var number := float(value)
	if number != floorf(number) or number <= 0.0:
		_error(ctx, "'%s' must be a positive integer" % field)
		return 0
	if number > MAX_INT_VALUE:
		_error(ctx, "'%s' must be at most %d" % [field, MAX_INT_VALUE])
		return 0
	return int(number)


## Like _get_positive_int, but 0 is allowed too.
func _get_non_negative_int(entry: Dictionary, field: String, ctx: String) -> int:
	if not entry.has(field):
		return 0
	var value: Variant = entry[field]
	if (value is int or value is float) and float(value) == 0.0:
		return 0
	if (value is int or value is float) and float(value) > 0.0:
		return _get_positive_int(entry, field, ctx)
	_error(ctx, "'%s' must be a whole number of at least 0" % field)
	return 0


## Accepts numbers strictly between low and high, or equal to low if low_inclusive.
func _get_float_between(
	entry: Dictionary,
	field: String,
	low: float,
	high: float,
	ctx: String,
	low_inclusive: bool = false,
	high_inclusive: bool = false,
) -> float:
	if not entry.has(field):
		return 0.0
	var value: Variant = entry[field]
	if value is int or value is float:
		var number := float(value)
		var above_low := number >= low if low_inclusive else number > low
		var below_high := number <= high if high_inclusive else number < high
		if above_low and below_high:
			return number
	var bound := "at least" if low_inclusive else "greater than"
	var upper := "at most" if high_inclusive else "less than"
	_error(ctx, "'%s' must be a number %s %s and %s %s" % [field, bound, low, upper, high])
	return 0.0


func _error(ctx: String, message: String) -> void:
	errors.append("%s: %s" % [ctx, message])
