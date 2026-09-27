extends GutTest

const VALID_DIR: String = "res://tests/fixtures/valid_data"
const INVALID_DIR: String = "res://tests/fixtures/invalid_data"
const MALFORMED_DIR: String = "res://tests/fixtures/malformed_json"
const WRONG_TYPE_DIR: String = "res://tests/fixtures/wrong_top_level"
const MISSING_DIR: String = "res://tests/fixtures/does_not_exist"


func test_shipped_data_is_valid() -> void:
	var loader := GameDataLoader.new()
	var data := loader.load_dir(GameDataLoader.DEFAULT_DIR)
	assert_eq(Array(loader.errors), [], "data/*.json must validate")
	assert_not_null(data)


func test_valid_fixture_is_parsed_in_file_order() -> void:
	var loader := GameDataLoader.new()
	var data := loader.load_dir(VALID_DIR)
	assert_eq(Array(loader.errors), [])
	assert_not_null(data)
	if data == null:
		return

	assert_eq(data.economy.days_of_cover, 20)
	assert_almost_eq(data.economy.stock_cap_factor, 3.0, 0.0001)
	assert_almost_eq(data.economy.price_max_multiplier, 2.5, 0.0001)
	assert_almost_eq(data.economy.price_min_multiplier, 0.35, 0.0001)
	assert_almost_eq(data.economy.spread, 0.1, 0.0001)

	assert_eq(data.goods.map(func(g: GoodDef) -> String: return g.id), ["grain", "cloth"])
	var cloth := data.get_good("cloth")
	assert_eq(cloth.name, "Cloth")
	assert_eq(cloth.category, "processed")
	assert_eq(cloth.base_price, 140)
	assert_eq(cloth.consumption_per_1000, 0.0)
	assert_almost_eq(data.get_good("grain").consumption_per_1000, 3.0, 0.0001)

	assert_eq(data.cities.size(), 1)
	var lubeck := data.get_city("lubeck")
	assert_eq(lubeck.name, "Lübeck")
	assert_eq(lubeck.map_position, Vector2(136, 710))
	assert_eq(lubeck.population, 12000)
	assert_eq(lubeck.production_of("cloth"), 18.0)
	assert_eq(lubeck.production_of("grain"), 0.5)
	assert_eq(lubeck.production_of("wine"), 0.0)


func test_unknown_ids_return_null() -> void:
	var data := GameDataLoader.new().load_dir(VALID_DIR)
	assert_false(data.has_good("amber"))
	assert_null(data.get_good("amber"))
	assert_null(data.get_city("riga"))


func test_invalid_data_reports_every_problem() -> void:
	var loader := GameDataLoader.new()
	var data := loader.load_dir(INVALID_DIR)
	assert_null(data)
	var expected: Array[String] = [
		"economy.json: missing field 'price_min_multiplier'",
		"economy.json: unknown field 'tax'",
		"economy.json: 'days_of_cover' must be a positive integer",
		"economy.json: 'stock_cap_factor' must be a number greater than 1.0 and less than 100.0",
		"economy.json: 'price_max_multiplier' must be a number greater than 1.0 and less than 100.0",
		"goods.json[1]: duplicate id 'grain'",
		"goods.json[2]: 'id' must be lower snake_case (got 'Fish')",
		"goods.json[3]: 'name' must be a non-empty string",
		"goods.json[3]: 'category' must be one of raw, processed, luxury (got 'mineral')",
		"goods.json[3]: 'base_price' must be a positive integer",
		"goods.json[3]: 'consumption_per_1000' must be a number at least 0.0 and less than 1000.0",
		"goods.json[4]: unknown field 'colour'",
		"goods.json[4]: 'base_price' must be a positive integer",
		"goods.json[5]: missing field 'base_price'",
		"goods.json[6]: entry must be an object",
		"cities.json[0]: 'map_position' must be an array of two numbers",
		"cities.json[1]: 'population' must be a positive integer",
		"cities.json[1]: 'production' has unknown good 'amber'",
		"cities.json[1]: 'production.grain' must be a number greater than 0.0 and less than 10000.0",
		"cities.json[2]: 'production' must be an object",
		"cities.json[3]: 'map_position' coordinates must be within ±100000",
		"cities.json[3]: 'population' must be at most 1000000000",
	]
	assert_eq(Array(loader.errors), expected)


func test_malformed_json_reports_line() -> void:
	var loader := GameDataLoader.new()
	assert_null(loader.load_dir(MALFORMED_DIR))
	assert_eq(loader.errors.size(), 1)
	assert_string_starts_with(loader.errors[0], "goods.json: invalid JSON at line 3")


func test_missing_directory_reports_each_file() -> void:
	var loader := GameDataLoader.new()
	assert_null(loader.load_dir(MISSING_DIR))
	assert_eq(loader.errors.size(), 3)
	assert_string_starts_with(loader.errors[0], "economy.json: file not found")
	assert_string_starts_with(loader.errors[1], "goods.json: file not found")
	assert_string_starts_with(loader.errors[2], "cities.json: file not found")


func test_wrong_top_level_type_is_reported() -> void:
	var loader := GameDataLoader.new()
	assert_null(loader.load_dir(WRONG_TYPE_DIR))
	assert_eq(
		Array(loader.errors),
		[
			"economy.json: top level must be an object",
			"goods.json: top level must be an array",
		]
	)


func test_errors_reset_between_loads() -> void:
	var loader := GameDataLoader.new()
	loader.load_dir(INVALID_DIR)
	assert_not_null(loader.load_dir(VALID_DIR))
	assert_eq(Array(loader.errors), [])
