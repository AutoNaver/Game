class_name GameDataLoader
extends DataReader
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
const POPULATION_FILE: String = "population.json"
const CITIES_FILE: String = "cities.json"
const SEA_LANES_FILE: String = "sea_lanes.json"
const SHIPS_FILE: String = "ships.json"
const BUILDINGS_FILE: String = "buildings.json"
const SCENARIO_FILE: String = "scenario.json"
const RIVALS_FILE: String = "rivals.json"
const EVENTS_FILE: String = "events.json"
const CAPTAINS_FILE: String = "captains.json"
const RANKS_FILE: String = "ranks.json"
const ACQUISITIONS_FILE: String = "acquisitions.json"
const RANKS_FIELDS: PackedStringArray = ["reputation", "ranks"]
const CAPTAIN_FIELDS: PackedStringArray = [
	"daily_wage",
	"tavern_pool_size",
	"hiring_fee",
	"seamanship_hours_per_level",
	"voyages_per_level",
	"max_skill",
	"bankruptcy_grace_days"
]

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
const POPULATION_FIELDS: PackedStringArray = [
	"satisfaction_weight",
	"neutral_satisfaction",
	"sensitivity",
	"growth_rate",
	"min_factor",
	"max_factor",
]
const GOOD_FIELDS: PackedStringArray = [
	"id", "name", "category", "base_price", "consumption_per_1000"
]
## Optional: goods without it keep forever.
const GOOD_OPTIONAL_FIELDS: PackedStringArray = ["spoilage_per_day", "since_save"]
const EVENT_FIELDS: PackedStringArray = [
	"id", "name", "kind", "chance_per_day", "min_days", "max_days"
]
## Longest an event may last, and the most a storm may slow ships.
const MAX_EVENT_DAYS: int = 3650
const MAX_STORM_SLOWDOWN: int = 24
## Saves hold the older cities and houses first, so newer ones must come after them.
const SINCE_ORDER: String = " (since_save must not decrease: add new ones at the end)"
const MAP_FIELDS: PackedStringArray = [
	"image", "west_lon", "east_lon", "south_lat", "north_lat", "reference_lat"
]
const CITY_FIELDS: PackedStringArray = ["id", "name", "coordinates", "population", "production"]
const CITY_OPTIONAL_FIELDS: PackedStringArray = ["import_factor", "since_save"]
## Highest import_factor a city may have.
const MAX_IMPORT_FACTOR: float = 10.0
const SHIP_FIELDS: PackedStringArray = ["id", "name", "capacity", "speed", "price"]
## Optional: a ship type without it needs no rank.
const SHIP_OPTIONAL_FIELDS: PackedStringArray = ["rank"]
const SCENARIO_FIELDS: PackedStringArray = ["start_city", "coins", "ships"]
const SEA_LANES_FIELDS: PackedStringArray = ["waypoints", "lanes"]
## Optional: lanes up rivers to inland cities, exempt from the coastline check.
const SEA_LANES_OPTIONAL_FIELDS: PackedStringArray = ["rivers"]
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
const RIVAL_AI_OPTIONAL_FIELDS: PackedStringArray = ["explore_chance"]
const RIVAL_FIELDS: PackedStringArray = ["id", "name", "color", "start_city", "coins", "ships"]
const RIVAL_OPTIONAL_FIELDS: PackedStringArray = ["since_save"]

## Sanity ceilings for per-day rates, to catch typos like an extra zero or two.
const MAX_CONSUMPTION_PER_1000: float = 1000.0
const MAX_PRODUCTION_PER_DAY: float = 10000.0
const MAX_SHIP_SPEED: float = 1000.0
## Slowest allowed speed. Map units are km and no route on Earth is near 100,000 km, so the longest
## voyage stays below a million hours: far inside int range.
const MIN_SHIP_SPEED: float = 0.1


## Returns the loaded data, or null if any file is missing or invalid (see errors).
func load_dir(dir: String) -> GameData:
	errors.clear()
	var data := GameData.new()

	var economy: Variant = _read_json(dir.path_join(ECONOMY_FILE), TYPE_DICTIONARY)
	if economy != null:
		data.economy = _parse_economy(economy as Dictionary, ECONOMY_FILE)
	var captains: Variant = _read_json(dir.path_join(CAPTAINS_FILE), TYPE_DICTIONARY)
	if captains != null:
		data.captains = _parse_captains(captains as Dictionary, CAPTAINS_FILE)

	var population: Variant = _read_json(dir.path_join(POPULATION_FILE), TYPE_DICTIONARY)
	if population != null:
		data.population = _parse_population(population as Dictionary, POPULATION_FILE)

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

	for i in range(1, data.cities.size()):
		if data.cities[i].since_save < data.cities[i - 1].since_save:
			_error(
				CITIES_FILE,
				"'%s' is older than the city before it" % data.cities[i].id + SINCE_ORDER
			)

	var sea_lanes: Variant = _read_json(dir.path_join(SEA_LANES_FILE), TYPE_DICTIONARY)
	if sea_lanes != null:
		data.sea_chart = _parse_sea_lanes(sea_lanes as Dictionary, SEA_LANES_FILE, data)

	var deals: Variant = _read_json(dir.path_join(ACQUISITIONS_FILE), TYPE_DICTIONARY)
	if deals != null:
		data.acquisitions = _parse_acquisitions(deals as Dictionary, ACQUISITIONS_FILE)

	var ranks: Variant = _read_json(dir.path_join(RANKS_FILE), TYPE_DICTIONARY)
	if ranks != null:
		_parse_ranks(ranks as Dictionary, RANKS_FILE, data)

	var ships := _read_array(dir.path_join(SHIPS_FILE))
	for i in ships.size():
		var ctx := "%s[%d]" % [SHIPS_FILE, i]
		var ship := _parse_ship(ships[i], ctx, data)
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

	for i in range(1, data.rivals.size()):
		if data.rivals[i].since_save < data.rivals[i - 1].since_save:
			_error(
				RIVALS_FILE,
				"'%s' is older than the house before it" % data.rivals[i].id + SINCE_ORDER
			)

	var events := _read_array(dir.path_join(EVENTS_FILE))
	for i in events.size():
		var ctx := "%s[%d]" % [EVENTS_FILE, i]
		var event := _parse_event(events[i], ctx, data)
		if event == null:
			continue
		if data.has_event(event.id):
			_error(ctx, "duplicate id '%s'" % event.id)
		else:
			data.add_event(event)

	if not errors.is_empty():
		return null
	return data


func _parse_captains(entry: Dictionary, ctx: String) -> CaptainDef:
	var before := errors.size()
	_check_fields(entry, CAPTAIN_FIELDS, ctx)
	var wage := _get_positive_int(entry, "daily_wage", ctx)
	var pool := _get_positive_int(entry, "tavern_pool_size", ctx)
	var fee := _get_positive_int(entry, "hiring_fee", ctx)
	var hours := _get_positive_int(entry, "seamanship_hours_per_level", ctx)
	var voyages := _get_positive_int(entry, "voyages_per_level", ctx)
	var skill := _get_positive_int(entry, "max_skill", ctx)
	var grace := _get_positive_int(entry, "bankruptcy_grace_days", ctx)
	if pool > 10 or skill > 10 or wage > 10000 or fee > 100000 or grace > 365:
		_error(ctx, "captain balance exceeds its supported range")
	if errors.size() > before:
		return null
	return CaptainDef.new(wage, pool, fee, hours, voyages, skill, grace)


## Reputation rules and the ranks in ascending order: the first needs nothing, and each later one
## needs at least the worth and standing of the one before.
func _parse_ranks(entry: Dictionary, ctx: String, data: GameData) -> void:
	_check_fields(entry, RANKS_FIELDS, ctx)
	var reputation: Variant = entry.get("reputation")
	if reputation is Dictionary:
		data.reputation = _parse_reputation(reputation as Dictionary, ctx + " reputation")
	elif entry.has("reputation"):
		_error(ctx, "'reputation' must be an object")
	var ranks := _get_array(entry, "ranks", ctx)
	if entry.has("ranks") and ranks.is_empty():
		_error(ctx, "'ranks' must list at least one rank")
	var unlocked: Dictionary[String, bool] = {}
	for i in ranks.size():
		var rank_ctx := "%s ranks[%d]" % [ctx, i]
		var rank := _parse_rank(ranks[i], rank_ctx)
		if rank == null:
			continue
		if data.rank_index(rank.id) >= 0:
			_error(rank_ctx, "duplicate id '%s'" % rank.id)
			continue
		for unlock in rank.unlocks:
			if unlocked.has(unlock):
				_error(rank_ctx, "'%s' is already unlocked by a lower rank" % unlock)
			unlocked[unlock] = true
		if data.ranks.is_empty():
			if rank.net_worth != 0 or rank.standing_cities != 0 or rank.richest:
				_error(rank_ctx, "the first rank must need nothing")
		else:
			var lower := data.ranks[-1]
			if rank.net_worth < lower.net_worth or rank.standing_cities < lower.standing_cities:
				_error(rank_ctx, "must need at least what the rank before it needs")
		data.ranks.append(rank)


func _parse_acquisitions(entry: Dictionary, ctx: String) -> AcquisitionDef:
	var before := errors.size()
	_check_fields(entry, AcquisitionDef.FIELDS, ctx)
	var asset := _get_float_between(entry, "asset_premium", 1.0, 10.0, ctx, true, true)
	var buy_out := _get_float_between(entry, "buy_out_premium", 1.0, 10.0, ctx, true, true)
	var factor := _get_float_between(entry, "buy_out_worth_factor", 1.0, 100.0, ctx, true, true)
	var discount := _get_float_between(entry, "bankruptcy_discount", 0.0, 1.0, ctx, false, true)
	var sale_days := _get_positive_int(entry, "bankruptcy_sale_days", ctx)
	var offer_days := _get_positive_int(entry, "offer_days", ctx)
	var chance := _get_float_between(entry, "offer_chance", 0.0, 1.0, ctx, true, true)
	if errors.size() > before:
		return null
	return AcquisitionDef.new(asset, buy_out, factor, discount, sale_days, offer_days, chance)


func _parse_reputation(entry: Dictionary, ctx: String) -> ReputationDef:
	var before := errors.size()
	_check_fields(entry, ReputationDef.FIELDS, ctx)
	var maximum := _get_positive_int(entry, "max", ctx)
	var standing := _get_positive_int(entry, "standing", ctx)
	var abroad := _get_non_negative_int(entry, "kontor_abroad", ctx)
	var shortage := _get_non_negative_int(entry, "per_shortage_unit", ctx)
	var kontor_day := _get_non_negative_int(entry, "per_kontor_day", ctx)
	var workshop_day := _get_non_negative_int(entry, "per_workshop_day", ctx)
	var idle_day := _get_non_negative_int(entry, "per_idle_workshop_day", ctx)
	if errors.size() == before and (standing > maximum or abroad > maximum):
		_error(ctx, "'standing' and 'kontor_abroad' must be at most 'max'")
	if errors.size() > before:
		return null
	return ReputationDef.new(
		maximum, standing, abroad, shortage, kontor_day, workshop_day, idle_day
	)


func _parse_rank(raw: Variant, ctx: String) -> RankDef:
	if not raw is Dictionary:
		_error(ctx, "entry must be an object")
		return null
	var entry: Dictionary = raw
	var before := errors.size()
	_check_fields(entry, RankDef.FIELDS, ctx)
	var id := _get_id(entry, ctx)
	var rank_name := _get_string(entry, "name", ctx)
	var worth := _get_non_negative_int(entry, "net_worth", ctx)
	var standing := _get_non_negative_int(entry, "standing_cities", ctx)
	var max_ships := _get_non_negative_int(entry, "max_ships", ctx)
	var max_kontors := _get_non_negative_int(entry, "max_kontors", ctx)
	var richest: Variant = entry.get("richest", false)
	if not richest is bool:
		_error(ctx, "'richest' must be true or false")
	var unlocks := PackedStringArray()
	for value: Variant in _get_array(entry, "unlocks", ctx):
		if not value is String or not RankDef.UNLOCKS.has(value as String):
			_error(ctx, "unknown unlock '%s' (known: %s)" % [value, ", ".join(RankDef.UNLOCKS)])
		elif unlocks.has(value as String):
			_error(ctx, "duplicate unlock '%s'" % value)
		else:
			unlocks.append(value as String)
	if errors.size() > before:
		return null
	return RankDef.new(
		id, rank_name, worth, standing, richest == true, max_ships, max_kontors, unlocks
	)


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


func _parse_population(entry: Dictionary, ctx: String) -> PopulationDef:
	var error_count := errors.size()
	_check_fields(entry, POPULATION_FIELDS, ctx)
	var weight := _get_float_between(entry, "satisfaction_weight", 0.0, 1.0, ctx, false, true)
	_check_rate_resolution(weight, "satisfaction_weight", ctx)
	var neutral := _get_float_between(entry, "neutral_satisfaction", 0.0, 1.0, ctx, true, true)
	_check_rate_resolution(neutral, "neutral_satisfaction", ctx)
	var sensitivity := _get_float_between(entry, "sensitivity", 0.0, 10.0, ctx, true)
	_check_rate_resolution(sensitivity, "sensitivity", ctx)
	var growth := _get_float_between(entry, "growth_rate", 0.0, 1.0, ctx, true, true)
	_check_rate_resolution(growth, "growth_rate", ctx)
	var min_factor := _get_float_between(entry, "min_factor", 0.0, 1.0, ctx, false, true)
	_check_rate_resolution(min_factor, "min_factor", ctx)
	var max_factor := _get_float_between(entry, "max_factor", 1.0, 100.0, ctx, true)
	_check_rate_resolution(max_factor, "max_factor", ctx)
	if errors.size() > error_count:
		return null
	return PopulationDef.new(weight, neutral, sensitivity, growth, min_factor, max_factor)


func _parse_good(raw: Variant, ctx: String) -> GoodDef:
	if not raw is Dictionary:
		_error(ctx, "entry must be an object")
		return null
	var entry: Dictionary = raw
	var error_count := errors.size()
	_check_fields(entry, GOOD_FIELDS, ctx, GOOD_OPTIONAL_FIELDS)
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
	var spoilage := _get_float_between(entry, "spoilage_per_day", 0.0, 1.0, ctx, true, true)
	_check_rate_resolution(spoilage, "spoilage_per_day", ctx)
	var since := _get_since_save(entry, ctx)
	if errors.size() > error_count:
		return null
	var good := GoodDef.new(id, good_name, category, base_price, consumption, spoilage)
	good.since_save = since
	return good


## The fields each event kind needs on top of EVENT_FIELDS.
static func _event_kind_fields(kind: String) -> PackedStringArray:
	match kind:
		EventDef.STORM:
			return ["slowdown"]
		EventDef.HARVEST_FAILURE:
			return ["goods", "factor"]
		EventDef.WAR:
			return ["factor"]
		EventDef.FIRE:
			return ["loss_share"]
	return []


## Goods and cities must already be loaded.
func _parse_event(raw: Variant, ctx: String, data: GameData) -> EventDef:
	if not raw is Dictionary:
		_error(ctx, "entry must be an object")
		return null
	var entry: Dictionary = raw
	var error_count := errors.size()
	var kind := _get_string(entry, "kind", ctx)
	var fields := EVENT_FIELDS.duplicate()
	if EventDef.KINDS.has(kind):
		fields.append_array(_event_kind_fields(kind))
	elif not kind.is_empty():
		_error(ctx, "'kind' must be one of %s (got '%s')" % [", ".join(EventDef.KINDS), kind])
	_check_fields(entry, fields, ctx)
	var id := _get_id(entry, ctx)
	if id == GoodsLoss.SPOILAGE:
		_error(ctx, "'id' '%s' is reserved for spoilage" % id)
	var event_name := _get_string(entry, "name", ctx)
	var chance := _get_float_between(entry, "chance_per_day", 0.0, 1.0, ctx, true, true)
	var min_days := _get_positive_int(entry, "min_days", ctx)
	var max_days := _get_positive_int(entry, "max_days", ctx)
	if max_days < min_days or max_days > MAX_EVENT_DAYS:
		_error(ctx, "'max_days' must be at least min_days and at most %d" % MAX_EVENT_DAYS)
	var event := EventDef.new(id, event_name, kind, chance, min_days, max_days)
	if entry.has("slowdown"):
		event.slowdown = _get_positive_int(entry, "slowdown", ctx)
		if event.slowdown < 2 or event.slowdown > MAX_STORM_SLOWDOWN:
			_error(ctx, "'slowdown' must be between 2 and %d" % MAX_STORM_SLOWDOWN)
	if entry.has("factor"):
		event.factor = _get_float_between(entry, "factor", 0.0, 1.0, ctx, true)
		_check_rate_resolution(event.factor, "factor", ctx)
	if entry.has("loss_share"):
		event.loss_share = _get_float_between(entry, "loss_share", 0.0, 1.0, ctx, false, true)
		_check_rate_resolution(event.loss_share, "loss_share", ctx)
	if entry.has("goods"):
		var goods: Variant = entry["goods"]
		if not goods is Array or (goods as Array).is_empty():
			_error(ctx, "'goods' must be a non-empty array of good ids")
		else:
			for good_id: Variant in goods as Array:
				if not good_id is String or not data.has_good(good_id as String):
					_error(ctx, "'goods' has unknown good '%s'" % str(good_id))
				elif event.goods.has(good_id as String):
					_error(ctx, "'goods' lists '%s' twice" % good_id)
				else:
					event.goods.append(good_id as String)
	if errors.size() > error_count:
		return null
	return event


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
	_check_fields(entry, CITY_FIELDS, ctx, CITY_OPTIONAL_FIELDS)
	var id := _get_id(entry, ctx)
	var city_name := _get_string(entry, "name", ctx)
	var map_position := _get_map_position(entry, ctx, data)
	var population := _get_positive_int(entry, "population", ctx)
	var production := _get_production(entry, ctx, data)
	var import_factor := 1.0
	if entry.has("import_factor"):
		import_factor = _get_float_between(
			entry, "import_factor", 0.0, MAX_IMPORT_FACTOR, ctx, true, true
		)
		_check_rate_resolution(import_factor, "import_factor", ctx)
	var since := _get_since_save(entry, ctx)
	if errors.size() > error_count:
		return null
	var city := CityDef.new(id, city_name, map_position, population, production)
	city.import_factor = import_factor
	city.since_save = since
	return city


## The optional "since_save": the save version whose world first has the entry (1 by default).
func _get_since_save(entry: Dictionary, ctx: String) -> int:
	if not entry.has("since_save"):
		return 1
	var since := _get_positive_int(entry, "since_save", ctx)
	if since > SaveGame.SAVE_VERSION:
		_error(ctx, "'since_save' must be at most the save version %d" % SaveGame.SAVE_VERSION)
	return since


## Fields that are fine on their own can multiply into a stock cap (population × consumption ×
## days of cover × cap factor) too large for int. Reject that here, not at the first production day.
func _check_stock_caps(city: CityDef, data: GameData, ctx: String) -> void:
	if data.economy == null or data.population == null:
		return
	# Cities can grow to max_factor × their home population, so check the largest they can be.
	var largest := city.population * data.population.max_factor
	for good in data.goods:
		var daily := largest / 1000.0 * good.consumption_per_1000
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
	_check_fields(entry, SEA_LANES_FIELDS, ctx, SEA_LANES_OPTIONAL_FIELDS)
	var chart := SeaChart.new()
	for city in data.cities:
		chart.add_node(city.id, city.map_position)
	for i in _get_array(entry, "waypoints", ctx).size():
		_parse_waypoint(entry["waypoints"][i], "%s waypoints[%d]" % [ctx, i], chart, data)
	for i in _get_array(entry, "lanes", ctx).size():
		_parse_lane(entry["lanes"][i], "%s lanes[%d]" % [ctx, i], chart)
	if entry.has("rivers"):
		for i in _get_array(entry, "rivers", ctx).size():
			_parse_lane(entry["rivers"][i], "%s rivers[%d]" % [ctx, i], chart, true)
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


func _parse_lane(raw: Variant, ctx: String, chart: SeaChart, river: bool = false) -> void:
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
		chart.add_lane(a, b, river)


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


## Ranks must already be loaded into `data`.
func _parse_ship(raw: Variant, ctx: String, data: GameData) -> ShipDef:
	if not raw is Dictionary:
		_error(ctx, "entry must be an object")
		return null
	var entry: Dictionary = raw
	var error_count := errors.size()
	_check_fields(entry, SHIP_FIELDS, ctx, SHIP_OPTIONAL_FIELDS)
	var id := _get_id(entry, ctx)
	var ship_name := _get_string(entry, "name", ctx)
	var capacity := _get_positive_int(entry, "capacity", ctx)
	var speed := _get_float_between(entry, "speed", MIN_SHIP_SPEED, MAX_SHIP_SPEED, ctx, true)
	var price := _get_positive_int(entry, "price", ctx)
	var rank_id := _get_string(entry, "rank", ctx)
	if not rank_id.is_empty() and data.rank_index(rank_id) < 0:
		_error(ctx, "unknown rank '%s'" % rank_id)
	if errors.size() > error_count:
		return null
	var ship := ShipDef.new(id, ship_name, capacity, speed, price)
	ship.rank_id = rank_id
	return ship


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
	_check_fields(entry, RIVAL_AI_FIELDS, ctx, RIVAL_AI_OPTIONAL_FIELDS)
	var top_choices := _get_positive_int(entry, "top_choices", ctx)
	var cash_reserve := _get_non_negative_int(entry, "cash_reserve", ctx)
	var max_ships := _get_positive_int(entry, "max_ships", ctx)
	var max_kontors := _get_non_negative_int(entry, "max_kontors", ctx)
	var expansion_days := _get_positive_int(entry, "expansion_days", ctx)
	var input_days := _get_positive_int(entry, "workshop_input_days", ctx)
	var price_limit := _get_float_between(entry, "input_price_limit", 0.0, 100.0, ctx)
	var keep_free := _get_float_between(entry, "keep_free_workers", 0.0, 1.0, ctx, true)
	var explore := _get_float_between(entry, "explore_chance", 0.0, 1.0, ctx, true, true)
	if errors.size() > error_count:
		return null
	var ai := RivalAiDef.new(
		top_choices,
		cash_reserve,
		max_ships,
		max_kontors,
		expansion_days,
		input_days,
		price_limit,
		keep_free
	)
	ai.explore_chance = explore
	return ai


func _parse_rival(raw: Variant, ctx: String, data: GameData) -> RivalDef:
	if not raw is Dictionary:
		_error(ctx, "entry must be an object")
		return null
	var entry: Dictionary = raw
	var error_count := errors.size()
	_check_fields(entry, RIVAL_FIELDS, ctx, RIVAL_OPTIONAL_FIELDS)
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
	var since := _get_since_save(entry, ctx)
	if errors.size() > error_count:
		return null
	var rival := RivalDef.new(id, rival_name, Color.html(color_text), start_city, coins, ships)
	rival.since_save = since
	return rival


## Rates must be multiples of 0.001 so daily flows stay exact (see CityEconomy); finer values would
## silently be rounded. Returns false after reporting a violation.
func _check_rate_resolution(rate: float, field: String, ctx: String) -> bool:
	if CityEconomy.is_valid_rate(rate):
		return true
	_error(ctx, "'%s' must be a multiple of 0.001 (got %s)" % [field, rate])
	return false


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
