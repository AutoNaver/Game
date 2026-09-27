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
const ECONOMY_FILE: String = "economy.json"
const GOODS_FILE: String = "goods.json"
const MAP_FILE: String = "map.json"
const CITIES_FILE: String = "cities.json"
const SHIPS_FILE: String = "ships.json"
const SCENARIO_FILE: String = "scenario.json"

const ECONOMY_FIELDS: PackedStringArray = [
	"days_of_cover",
	"stock_cap_factor",
	"price_max_multiplier",
	"price_min_multiplier",
	"spread",
]
const GOOD_FIELDS: PackedStringArray = [
	"id", "name", "category", "base_price", "consumption_per_1000"
]
const MAP_FIELDS: PackedStringArray = [
	"image", "west_lon", "east_lon", "south_lat", "north_lat", "reference_lat"
]
const CITY_FIELDS: PackedStringArray = ["id", "name", "coordinates", "population", "production"]
const SHIP_FIELDS: PackedStringArray = ["id", "name", "capacity", "speed", "price"]
const SCENARIO_FIELDS: PackedStringArray = ["start_city", "coins", "ships"]
const STARTING_SHIP_FIELDS: PackedStringArray = ["type", "name"]

## Sanity ceilings for per-day rates, to catch typos like an extra zero or two.
const MAX_CONSUMPTION_PER_1000: float = 1000.0
const MAX_PRODUCTION_PER_DAY: float = 10000.0
const MAX_SHIP_SPEED: float = 1000.0
## Slowest allowed speed. Map units are km and no route on Earth is near 100,000 km, so the longest
## voyage stays below a million hours: far inside int range.
const MIN_SHIP_SPEED: float = 0.1

## Upper bound for plain integers. JSON allows values like 1e100 that overflow int, so anything
## beyond this is rejected as a data error.
const MAX_INT_VALUE: int = 1_000_000_000

## Problems found by the last load_dir() call, formatted as "<file>[<index>]: <message>".
var errors: PackedStringArray = []

var _id_pattern: RegEx = RegEx.create_from_string("^[a-z][a-z0-9_]*$")


## Returns the loaded data, or null if any file is missing or invalid (see errors).
func load_dir(dir: String) -> GameData:
	errors.clear()
	var data := GameData.new()

	var economy: Variant = _read_json(dir.path_join(ECONOMY_FILE), TYPE_DICTIONARY)
	if economy != null:
		data.economy = _parse_economy(economy as Dictionary, ECONOMY_FILE)

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

	var map_config: Variant = _read_json(dir.path_join(MAP_FILE), TYPE_DICTIONARY)
	if map_config != null:
		data.map = _parse_map(map_config as Dictionary, MAP_FILE)

	var cities := _read_array(dir.path_join(CITIES_FILE))
	for i in cities.size():
		var ctx := "%s[%d]" % [CITIES_FILE, i]
		var city := _parse_city(cities[i], ctx, data)
		if city == null:
			continue
		if data.has_city(city.id):
			_error(ctx, "duplicate id '%s'" % city.id)
		else:
			data.add_city(city)
			_check_stock_caps(city, data, ctx)

	var ships := _read_array(dir.path_join(SHIPS_FILE))
	for i in ships.size():
		var ctx := "%s[%d]" % [SHIPS_FILE, i]
		var ship := _parse_ship(ships[i], ctx)
		if ship == null:
			continue
		if data.has_ship(ship.id):
			_error(ctx, "duplicate id '%s'" % ship.id)
		else:
			data.add_ship(ship)

	var scenario: Variant = _read_json(dir.path_join(SCENARIO_FILE), TYPE_DICTIONARY)
	if scenario != null:
		data.scenario = _parse_scenario(scenario as Dictionary, SCENARIO_FILE, data)

	if not errors.is_empty():
		return null
	return data


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


func _parse_economy(entry: Dictionary, ctx: String) -> EconomyDef:
	var error_count := errors.size()
	_check_fields(entry, ECONOMY_FIELDS, ctx)
	var days_of_cover := _get_positive_int(entry, "days_of_cover", ctx)
	var stock_cap_factor := _get_float_between(entry, "stock_cap_factor", 1.0, 100.0, ctx)
	var max_multiplier := _get_float_between(entry, "price_max_multiplier", 1.0, 100.0, ctx)
	var min_multiplier := _get_float_between(entry, "price_min_multiplier", 0.0, 1.0, ctx)
	var spread := _get_float_between(entry, "spread", 0.0, 1.0, ctx)
	if errors.size() > error_count:
		return null
	return EconomyDef.new(days_of_cover, stock_cap_factor, max_multiplier, min_multiplier, spread)


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
	var consumption := _get_float_between(
		entry, "consumption_per_1000", 0.0, MAX_CONSUMPTION_PER_1000, ctx, true
	)
	_check_rate_resolution(consumption, "consumption_per_1000", ctx)
	if errors.size() > error_count:
		return null
	return GoodDef.new(id, good_name, category, base_price, consumption)


func _parse_map(entry: Dictionary, ctx: String) -> MapDef:
	var error_count := errors.size()
	_check_fields(entry, MAP_FIELDS, ctx)
	var image := _get_string(entry, "image", ctx)
	if not image.is_empty() and not ResourceLoader.exists(image):
		_error(ctx, "'image' not found: %s" % image)
	var west := _get_float_between(entry, "west_lon", -180.0, 180.0, ctx, true)
	var east := _get_float_between(entry, "east_lon", -180.0, 180.0, ctx, true)
	var south := _get_float_between(entry, "south_lat", -85.0, 85.0, ctx, true)
	var north := _get_float_between(entry, "north_lat", -85.0, 85.0, ctx, true)
	var reference := _get_float_between(entry, "reference_lat", -85.0, 85.0, ctx, true)
	if errors.size() > error_count:
		return null
	if west >= east or south >= north:
		_error(ctx, "the frame must have west_lon < east_lon and south_lat < north_lat")
		return null
	return MapDef.new(image, west, east, south, north, reference)


## Goods (and the map) must already be loaded into `data`.
func _parse_city(raw: Variant, ctx: String, data: GameData) -> CityDef:
	if not raw is Dictionary:
		_error(ctx, "entry must be an object")
		return null
	var entry: Dictionary = raw
	var error_count := errors.size()
	_check_fields(entry, CITY_FIELDS, ctx)
	var id := _get_id(entry, ctx)
	var city_name := _get_string(entry, "name", ctx)
	var map_position := _get_map_position(entry, ctx, data)
	var population := _get_positive_int(entry, "population", ctx)
	var production := _get_production(entry, ctx, data)
	if errors.size() > error_count:
		return null
	return CityDef.new(id, city_name, map_position, population, production)


## Fields that are fine on their own can multiply into a stock cap (population × consumption ×
## days of cover × cap factor) too large for int. Reject that here, not at the first production day.
func _check_stock_caps(city: CityDef, data: GameData, ctx: String) -> void:
	if data.economy == null:
		return
	for good in data.goods:
		var daily := city.population / 1000.0 * good.consumption_per_1000
		var cap := daily * data.economy.days_of_cover * data.economy.stock_cap_factor
		if cap > MAX_INT_VALUE:
			var message := "stock cap for '%s' exceeds %d units; lower population or consumption"
			_error(ctx, message % [good.id, MAX_INT_VALUE])


func _get_production(entry: Dictionary, ctx: String, data: GameData) -> Dictionary[String, float]:
	var production: Dictionary[String, float] = {}
	if not entry.has("production"):
		return production
	if not entry["production"] is Dictionary:
		_error(ctx, "'production' must be an object")
		return production
	var rates: Dictionary = entry["production"]
	for key: Variant in rates.keys():
		var good_id := str(key)
		if not data.has_good(good_id):
			_error(ctx, "'production' has unknown good '%s'" % good_id)
			continue
		var field := "production.%s" % good_id
		var rate := _get_float_between({field: rates[key]}, field, 0.0, MAX_PRODUCTION_PER_DAY, ctx)
		if rate <= 0.0:
			continue
		if _check_rate_resolution(rate, field, ctx):
			production[good_id] = rate
	return production


func _parse_ship(raw: Variant, ctx: String) -> ShipDef:
	if not raw is Dictionary:
		_error(ctx, "entry must be an object")
		return null
	var entry: Dictionary = raw
	var error_count := errors.size()
	_check_fields(entry, SHIP_FIELDS, ctx)
	var id := _get_id(entry, ctx)
	var ship_name := _get_string(entry, "name", ctx)
	var capacity := _get_positive_int(entry, "capacity", ctx)
	var speed := _get_float_between(entry, "speed", MIN_SHIP_SPEED, MAX_SHIP_SPEED, ctx, true)
	var price := _get_positive_int(entry, "price", ctx)
	if errors.size() > error_count:
		return null
	return ShipDef.new(id, ship_name, capacity, speed, price)


## Cities and ships must already be loaded into `data`.
func _parse_scenario(entry: Dictionary, ctx: String, data: GameData) -> ScenarioDef:
	var error_count := errors.size()
	_check_fields(entry, SCENARIO_FIELDS, ctx)
	var start_city := _get_string(entry, "start_city", ctx)
	if not start_city.is_empty() and not data.has_city(start_city):
		_error(ctx, "'start_city' is not a known city: '%s'" % start_city)
	var coins := _get_positive_int(entry, "coins", ctx)
	var ships: Array[ScenarioDef.StartingShip] = []
	if entry.has("ships"):
		if not entry["ships"] is Array or (entry["ships"] as Array).is_empty():
			_error(ctx, "'ships' must be a non-empty array")
		else:
			var raw_ships: Array = entry["ships"]
			for i in raw_ships.size():
				var ship := _parse_starting_ship(raw_ships[i], "%s ships[%d]" % [ctx, i], data)
				if ship != null:
					ships.append(ship)
	if errors.size() > error_count:
		return null
	return ScenarioDef.new(start_city, coins, ships)


func _parse_starting_ship(raw: Variant, ctx: String, data: GameData) -> ScenarioDef.StartingShip:
	if not raw is Dictionary:
		_error(ctx, "entry must be an object")
		return null
	var entry: Dictionary = raw
	var error_count := errors.size()
	_check_fields(entry, STARTING_SHIP_FIELDS, ctx)
	var type_id := _get_string(entry, "type", ctx)
	if not type_id.is_empty() and not data.has_ship(type_id):
		_error(ctx, "'type' is not a known ship type: '%s'" % type_id)
	var ship_name := _get_string(entry, "name", ctx)
	if errors.size() > error_count:
		return null
	return ScenarioDef.StartingShip.new(type_id, ship_name)


## Rates must be multiples of 0.001 so daily flows stay exact (see CityEconomy); finer values would
## silently be rounded. Returns false after reporting a violation.
func _check_rate_resolution(rate: float, field: String, ctx: String) -> bool:
	if CityEconomy.is_valid_rate(rate):
		return true
	_error(ctx, "'%s' must be a multiple of 0.001 (got %s)" % [field, rate])
	return false


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
	if number > MAX_INT_VALUE:
		_error(ctx, "'%s' must be at most %d" % [field, MAX_INT_VALUE])
		return 0
	return int(number)


## Accepts numbers strictly between low and high, or equal to low if low_inclusive.
func _get_float_between(
	entry: Dictionary,
	field: String,
	low: float,
	high: float,
	ctx: String,
	low_inclusive: bool = false,
) -> float:
	if not entry.has(field):
		return 0.0
	var value: Variant = entry[field]
	if value is int or value is float:
		var number := float(value)
		var above_low := number >= low if low_inclusive else number > low
		if above_low and number < high:
			return number
	var bound := "at least" if low_inclusive else "greater than"
	_error(ctx, "'%s' must be a number %s %s and less than %s" % [field, bound, low, high])
	return 0.0


## Reads "coordinates": [lon, lat], checks they lie inside the map frame and projects them to km.
func _get_map_position(entry: Dictionary, ctx: String, data: GameData) -> Vector2:
	if not entry.has("coordinates"):
		return Vector2.ZERO
	var value: Variant = entry["coordinates"]
	if value is Array and (value as Array).size() == 2:
		var pair: Array = value
		var lon: Variant = pair[0]
		var lat: Variant = pair[1]
		if (lon is int or lon is float) and (lat is int or lat is float):
			if data.map == null:
				return Vector2.ZERO  # map.json is broken; that error is already reported
			if not data.map.contains(float(lon), float(lat)):
				var frame := (
					"lon %s..%s, lat %s..%s"
					% [data.map.west_lon, data.map.east_lon, data.map.south_lat, data.map.north_lat]
				)
				_error(ctx, "'coordinates' must lie within the map (%s)" % frame)
				return Vector2.ZERO
			return data.map.project(float(lon), float(lat))
	_error(ctx, "'coordinates' must be an array of two numbers [lon, lat]")
	return Vector2.ZERO


func _error(ctx: String, message: String) -> void:
	errors.append("%s: %s" % [ctx, message])
