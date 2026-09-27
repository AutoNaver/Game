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
const SEA_LANES_FILE: String = "sea_lanes.json"
const SHIPS_FILE: String = "ships.json"
const BUILDINGS_FILE: String = "buildings.json"
const SCENARIO_FILE: String = "scenario.json"
const RIVALS_FILE: String = "rivals.json"

const ECONOMY_FIELDS: PackedStringArray = [
	"days_of_cover",
	"stock_cap_factor",
	"price_max_multiplier",
	"price_min_multiplier",
	"spread",
	"ship_resale_factor",
	"workforce_share",
	"import_rate",
	"export_rate",
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
const SEA_LANES_FIELDS: PackedStringArray = ["waypoints", "lanes"]
const WAYPOINT_FIELDS: PackedStringArray = ["id", "coordinates"]
const BUILDINGS_FIELDS: PackedStringArray = ["kontor", "workshops"]
const KONTOR_FIELDS: PackedStringArray = ["price", "capacity"]
const WORKSHOP_FIELDS: PackedStringArray = [
	"id", "name", "output", "output_per_day", "inputs", "workers", "build_cost", "wages_per_day"
]
const STARTING_SHIP_FIELDS: PackedStringArray = ["type", "name"]
const RIVALS_FIELDS: PackedStringArray = ["ai", "houses"]
const RIVAL_AI_FIELDS: PackedStringArray = [
	"top_choices",
	"cash_reserve",
	"max_ships",
	"max_kontors",
	"expansion_days",
	"workshop_input_days",
	"input_price_limit",
	"keep_free_workers",
]
const RIVAL_FIELDS: PackedStringArray = ["id", "name", "color", "start_city", "coins", "ships"]

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

	var sea_lanes: Variant = _read_json(dir.path_join(SEA_LANES_FILE), TYPE_DICTIONARY)
	if sea_lanes != null:
		data.sea_chart = _parse_sea_lanes(sea_lanes as Dictionary, SEA_LANES_FILE, data)

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

	var buildings: Variant = _read_json(dir.path_join(BUILDINGS_FILE), TYPE_DICTIONARY)
	if buildings != null:
		_parse_buildings(buildings as Dictionary, BUILDINGS_FILE, data)

	var scenario: Variant = _read_json(dir.path_join(SCENARIO_FILE), TYPE_DICTIONARY)
	if scenario != null:
		data.scenario = _parse_scenario(scenario as Dictionary, SCENARIO_FILE, data)

	var rivals: Variant = _read_json(dir.path_join(RIVALS_FILE), TYPE_DICTIONARY)
	if rivals != null:
		_parse_rivals(rivals as Dictionary, RIVALS_FILE, data)

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
	_check_rate_resolution(stock_cap_factor, "stock_cap_factor", ctx)
	var max_multiplier := _get_float_between(entry, "price_max_multiplier", 1.0, 100.0, ctx)
	var min_multiplier := _get_float_between(entry, "price_min_multiplier", 0.0, 1.0, ctx)
	var spread := _get_float_between(entry, "spread", 0.0, 1.0, ctx)
	var resale := _get_float_between(entry, "ship_resale_factor", 0.0, 1.0, ctx, true)
	_check_rate_resolution(resale, "ship_resale_factor", ctx)
	var workforce := _get_float_between(entry, "workforce_share", 0.0, 1.0, ctx, true)
	_check_rate_resolution(workforce, "workforce_share", ctx)
	var import_rate := _get_float_between(entry, "import_rate", 0.0, 10.0, ctx, true)
	_check_rate_resolution(import_rate, "import_rate", ctx)
	var export_rate := _get_float_between(entry, "export_rate", 0.0, 10.0, ctx, true)
	_check_rate_resolution(export_rate, "export_rate", ctx)
	if errors.size() > error_count:
		return null
	return (
		EconomyDef
		. new(
			days_of_cover,
			stock_cap_factor,
			max_multiplier,
			min_multiplier,
			spread,
			resale,
			workforce,
			import_rate,
			export_rate,
		)
	)


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
	elif not image.is_empty() and not load(image) is Texture2D:
		_error(ctx, "'image' must be a texture: %s" % image)
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


## Cities and the map must already be loaded. Every pair of cities must be connected by lanes.
func _parse_sea_lanes(entry: Dictionary, ctx: String, data: GameData) -> SeaChart:
	var error_count := errors.size()
	_check_fields(entry, SEA_LANES_FIELDS, ctx)
	var chart := SeaChart.new()
	for city in data.cities:
		chart.add_node(city.id, city.map_position)
	for i in _get_array(entry, "waypoints", ctx).size():
		_parse_waypoint(entry["waypoints"][i], "%s waypoints[%d]" % [ctx, i], chart, data)
	for i in _get_array(entry, "lanes", ctx).size():
		_parse_lane(entry["lanes"][i], "%s lanes[%d]" % [ctx, i], chart)
	for a in data.cities.size():
		for b in range(a + 1, data.cities.size()):
			var from_id := data.cities[a].id
			var to_id := data.cities[b].id
			if chart.route(from_id, to_id).is_empty():
				_error(ctx, "no sea route from %s to %s" % [from_id, to_id])
	if errors.size() > error_count:
		return null
	return chart


func _parse_waypoint(raw: Variant, ctx: String, chart: SeaChart, data: GameData) -> void:
	if not raw is Dictionary:
		_error(ctx, "entry must be an object")
		return
	var entry: Dictionary = raw
	var error_count := errors.size()
	_check_fields(entry, WAYPOINT_FIELDS, ctx)
	var id := _get_id(entry, ctx)
	var position := _get_map_position(entry, ctx, data)
	if errors.size() > error_count:
		return
	if chart.has_node(id):
		_error(ctx, "duplicate id '%s' (ids are shared with cities)" % id)
		return
	chart.add_node(id, position)


func _parse_lane(raw: Variant, ctx: String, chart: SeaChart) -> void:
	if not raw is Array or (raw as Array).size() != 2:
		_error(ctx, "a lane must be an array of two node ids")
		return
	var ends: Array = raw
	var a := str(ends[0])
	var b := str(ends[1])
	for id: String in [a, b]:
		if not chart.has_node(id):
			_error(ctx, "unknown node '%s'" % id)
			return
	if a == b:
		_error(ctx, "a lane must join two different nodes")
	elif chart.has_lane(a, b):
		_error(ctx, "duplicate lane %s-%s" % [a, b])
	else:
		chart.add_lane(a, b)


## Returns the array in `field`, or an empty one after reporting that it is not an array.
func _get_array(entry: Dictionary, field: String, ctx: String) -> Array:
	if not entry.has(field):
		return []
	if not entry[field] is Array:
		_error(ctx, "'%s' must be an array" % field)
		return []
	return entry[field] as Array


## Goods must already be loaded. Sets data.kontor and adds the workshop types.
func _parse_buildings(entry: Dictionary, ctx: String, data: GameData) -> void:
	_check_fields(entry, BUILDINGS_FIELDS, ctx)
	if entry.has("kontor"):
		if entry["kontor"] is Dictionary:
			var kontor: Dictionary = entry["kontor"]
			var kontor_ctx := "%s kontor" % ctx
			var error_count := errors.size()
			_check_fields(kontor, KONTOR_FIELDS, kontor_ctx)
			var price := _get_positive_int(kontor, "price", kontor_ctx)
			var capacity := _get_positive_int(kontor, "capacity", kontor_ctx)
			if errors.size() == error_count:
				data.kontor = KontorDef.new(price, capacity)
		else:
			_error(ctx, "'kontor' must be an object")
	var workshops := _get_array(entry, "workshops", ctx)
	for i in workshops.size():
		var workshop_ctx := "%s workshops[%d]" % [ctx, i]
		var workshop := _parse_workshop(workshops[i], workshop_ctx, data)
		if workshop == null:
			continue
		if data.has_workshop(workshop.id):
			_error(workshop_ctx, "duplicate id '%s'" % workshop.id)
		else:
			data.add_workshop(workshop)


func _parse_workshop(raw: Variant, ctx: String, data: GameData) -> WorkshopDef:
	if not raw is Dictionary:
		_error(ctx, "entry must be an object")
		return null
	var entry: Dictionary = raw
	var error_count := errors.size()
	_check_fields(entry, WORKSHOP_FIELDS, ctx)
	var id := _get_id(entry, ctx)
	var workshop_name := _get_string(entry, "name", ctx)
	var output := _get_string(entry, "output", ctx)
	if not output.is_empty() and not data.has_good(output):
		_error(ctx, "'output' is not a known good: '%s'" % output)
	var output_per_day := _get_positive_int(entry, "output_per_day", ctx)
	var inputs: Dictionary[String, int] = {}
	if entry.has("inputs"):
		if entry["inputs"] is Dictionary:
			var raw_inputs: Dictionary = entry["inputs"]
			for key: Variant in raw_inputs.keys():
				var good_id := str(key)
				if not data.has_good(good_id):
					_error(ctx, "'inputs' has unknown good '%s'" % good_id)
					continue
				var field := "inputs.%s" % good_id
				inputs[good_id] = _get_positive_int({field: raw_inputs[key]}, field, ctx)
		else:
			_error(ctx, "'inputs' must be an object")
	var workers := _get_positive_int(entry, "workers", ctx)
	var build_cost := _get_positive_int(entry, "build_cost", ctx)
	var wages := _get_positive_int(entry, "wages_per_day", ctx)
	if errors.size() > error_count:
		return null
	return WorkshopDef.new(
		id, workshop_name, output, output_per_day, inputs, workers, build_cost, wages
	)


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


## Cities and ships must already be loaded. Sets data.rival_ai and adds the rival houses.
func _parse_rivals(entry: Dictionary, ctx: String, data: GameData) -> void:
	_check_fields(entry, RIVALS_FIELDS, ctx)
	if entry.has("ai"):
		if entry["ai"] is Dictionary:
			data.rival_ai = _parse_rival_ai(entry["ai"] as Dictionary, "%s ai" % ctx)
		else:
			_error(ctx, "'ai' must be an object")
	var houses := _get_array(entry, "houses", ctx)
	for i in houses.size():
		var house_ctx := "%s houses[%d]" % [ctx, i]
		var rival := _parse_rival(houses[i], house_ctx, data)
		if rival == null:
			continue
		if data.has_rival(rival.id):
			_error(house_ctx, "duplicate id '%s'" % rival.id)
		else:
			data.add_rival(rival)


func _parse_rival_ai(entry: Dictionary, ctx: String) -> RivalAiDef:
	var error_count := errors.size()
	_check_fields(entry, RIVAL_AI_FIELDS, ctx)
	var top_choices := _get_positive_int(entry, "top_choices", ctx)
	var cash_reserve := _get_non_negative_int(entry, "cash_reserve", ctx)
	var max_ships := _get_positive_int(entry, "max_ships", ctx)
	var max_kontors := _get_non_negative_int(entry, "max_kontors", ctx)
	var expansion_days := _get_positive_int(entry, "expansion_days", ctx)
	var input_days := _get_positive_int(entry, "workshop_input_days", ctx)
	var price_limit := _get_float_between(entry, "input_price_limit", 0.0, 100.0, ctx)
	var keep_free := _get_float_between(entry, "keep_free_workers", 0.0, 1.0, ctx, true)
	if errors.size() > error_count:
		return null
	return RivalAiDef.new(
		top_choices,
		cash_reserve,
		max_ships,
		max_kontors,
		expansion_days,
		input_days,
		price_limit,
		keep_free
	)


func _parse_rival(raw: Variant, ctx: String, data: GameData) -> RivalDef:
	if not raw is Dictionary:
		_error(ctx, "entry must be an object")
		return null
	var entry: Dictionary = raw
	var error_count := errors.size()
	_check_fields(entry, RIVAL_FIELDS, ctx)
	var id := _get_id(entry, ctx)
	if id == WorldState.PLAYER_ID:
		_error(ctx, "'id' '%s' is reserved for the player" % id)
	var rival_name := _get_string(entry, "name", ctx)
	var color_text := _get_string(entry, "color", ctx)
	if not color_text.is_empty() and not Color.html_is_valid(color_text):
		_error(ctx, "'color' must be an HTML colour such as \"#3a6ea5\" (got '%s')" % color_text)
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
	return RivalDef.new(id, rival_name, Color.html(color_text), start_city, coins, ships)


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
