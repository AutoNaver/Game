extends GutTest

const VALID_DIR: String = "res://tests/fixtures/valid_data"
const INVALID_DIR: String = "res://tests/fixtures/invalid_data"
const MALFORMED_DIR: String = "res://tests/fixtures/malformed_json"
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

	assert_eq(data.goods.map(func(g: GoodDef) -> String: return g.id), ["grain", "cloth"])
	var cloth := data.get_good("cloth")
	assert_eq(cloth.name, "Cloth")
	assert_eq(cloth.category, "processed")
	assert_eq(cloth.base_price, 140)

	assert_eq(data.cities.size(), 1)
	var lubeck := data.get_city("lubeck")
	assert_eq(lubeck.name, "Lübeck")
	assert_eq(lubeck.map_position, Vector2(136, 710))
	assert_eq(lubeck.population, 12000)


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
		"goods.json[1]: duplicate id 'grain'",
		"goods.json[2]: 'id' must be lower snake_case (got 'Fish')",
		"goods.json[3]: 'name' must be a non-empty string",
		"goods.json[3]: 'category' must be one of raw, processed, luxury (got 'mineral')",
		"goods.json[3]: 'base_price' must be a positive integer",
		"goods.json[4]: unknown field 'colour'",
		"goods.json[4]: 'base_price' must be a positive integer",
		"goods.json[5]: missing field 'base_price'",
		"goods.json[6]: entry must be an object",
		"cities.json[0]: 'map_position' must be an array of two numbers",
		"cities.json[1]: 'population' must be a positive integer",
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
	assert_eq(loader.errors.size(), 2)
	assert_string_starts_with(loader.errors[0], "goods.json: file not found")
	assert_string_starts_with(loader.errors[1], "cities.json: file not found")


func test_errors_reset_between_loads() -> void:
	var loader := GameDataLoader.new()
	loader.load_dir(INVALID_DIR)
	assert_not_null(loader.load_dir(VALID_DIR))
	assert_eq(Array(loader.errors), [])
