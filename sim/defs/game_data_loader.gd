class_name GameDataLoader
extends RefCounted
## Loads and validates the JSON definitions in a data directory.
##
## Validation collects every problem instead of stopping at the first, so one run shows all
## mistakes in a data change:
##     var loader := GameDataLoader.new()
##     var data := loader.load_dir(GameDataLoader.DEFAULT_DIR)
##     if data == null:
##         print(loader.errors)

const DEFAULT_DIR: String = "res://data"
const GOODS_FILE: String = "goods.json"
const CITIES_FILE: String = "cities.json"

const GOOD_FIELDS: PackedStringArray = ["id", "name", "category", "base_price"]
const CITY_FIELDS: PackedStringArray = ["id", "name", "map_position", "population"]

## Problems found by the last load_dir() call, formatted as "<file>[<index>]: <message>".
var errors: PackedStringArray = []

var _id_pattern: RegEx = RegEx.create_from_string("^[a-z][a-z0-9_]*$")


## Returns the loaded data, or null if any file is missing or invalid (see errors).
func load_dir(dir: String) -> GameData:
	errors.clear()
	var data := GameData.new()

	var goods := _read_array(dir.path_join(GOODS_FILE))
	for i in goods.size():
		var ctx := "%s[%d]" % [GOODS_FILE, i]
		var good := _parse_good(goods[i], ctx)
		if good == null:
			continue
		if data.has_good(good.id):
			_error(ctx, "duplicate id '%s'" % good.id)
		else:
			data.add_good(good)

	var cities := _read_array(dir.path_join(CITIES_FILE))
	for i in cities.size():
		var ctx := "%s[%d]" % [CITIES_FILE, i]
		var city := _parse_city(cities[i], ctx)
		if city == null:
			continue
		if data.has_city(city.id):
			_error(ctx, "duplicate id '%s'" % city.id)
		else:
			data.add_city(city)

	if not errors.is_empty():
		return null
	return data


func _read_array(path: String) -> Array:
	var file_name := path.get_file()
	if not FileAccess.file_exists(path):
		_error(file_name, "file not found at %s" % path)
		return []
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		# get_error_line() is 0-based; editors count from 1.
		var line := json.get_error_line() + 1
		_error(file_name, "invalid JSON at line %d: %s" % [line, json.get_error_message()])
		return []
	if not json.data is Array:
		_error(file_name, "top level must be an array")
		return []
	return json.data as Array


func _parse_good(raw: Variant, ctx: String) -> GoodDef:
	if not raw is Dictionary:
		_error(ctx, "entry must be an object")
		return null
	var entry: Dictionary = raw
	var error_count := errors.size()
	_check_fields(entry, GOOD_FIELDS, ctx)
	var id := _get_id(entry, ctx)
	var good_name := _get_string(entry, "name", ctx)
	var category := _get_string(entry, "category", ctx)
	if not category.is_empty() and not GoodDef.CATEGORIES.has(category):
		var allowed := ", ".join(GoodDef.CATEGORIES)
		_error(ctx, "'category' must be one of %s (got '%s')" % [allowed, category])
	var base_price := _get_positive_int(entry, "base_price", ctx)
	if errors.size() > error_count:
		return null
	return GoodDef.new(id, good_name, category, base_price)


func _parse_city(raw: Variant, ctx: String) -> CityDef:
	if not raw is Dictionary:
		_error(ctx, "entry must be an object")
		return null
	var entry: Dictionary = raw
	var error_count := errors.size()
	_check_fields(entry, CITY_FIELDS, ctx)
	var id := _get_id(entry, ctx)
	var city_name := _get_string(entry, "name", ctx)
	var map_position := _get_vector2(entry, "map_position", ctx)
	var population := _get_positive_int(entry, "population", ctx)
	if errors.size() > error_count:
		return null
	return CityDef.new(id, city_name, map_position, population)


## Reports missing and unknown fields. The typed getters below skip missing fields so each
## problem is reported once.
func _check_fields(entry: Dictionary, fields: PackedStringArray, ctx: String) -> void:
	for field in fields:
		if not entry.has(field):
			_error(ctx, "missing field '%s'" % field)
	for key: Variant in entry.keys():
		if not fields.has(str(key)):
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
	return int(number)


func _get_vector2(entry: Dictionary, field: String, ctx: String) -> Vector2:
	if not entry.has(field):
		return Vector2.ZERO
	var value: Variant = entry[field]
	if value is Array and (value as Array).size() == 2:
		var pair: Array = value
		var x: Variant = pair[0]
		var y: Variant = pair[1]
		if (x is int or x is float) and (y is int or y is float):
			return Vector2(float(x), float(y))
	_error(ctx, "'%s' must be an array of two numbers" % field)
	return Vector2.ZERO


func _error(ctx: String, message: String) -> void:
	errors.append("%s: %s" % [ctx, message])
