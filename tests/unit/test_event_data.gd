extends GutTest
## Loading events (data/events.json) and spoilage rates (data/goods.json), ADR 0011.

const VALID_DIR: String = "res://tests/fixtures/valid_data"


func test_valid_fixture_has_events_and_spoilage() -> void:
	var data := GameDataLoader.new().load_dir(VALID_DIR)
	assert_almost_eq(data.get_good("grain").spoilage_per_day, 0.01, 0.0001)
	assert_eq(data.get_good("cloth").spoilage_per_day, 0.0, "optional: keeps when missing")
	assert_eq(data.events.size(), 3)
	var gale := data.get_event("gale")
	assert_eq([gale.kind, gale.min_days, gale.max_days, gale.slowdown], ["storm", 1, 3, 3])
	var blight := data.get_event("blight")
	assert_eq(Array(blight.goods), ["grain"])
	assert_almost_eq(blight.factor, 0.5, 0.0001)
	assert_almost_eq(data.get_event("fire").loss_share, 0.1, 0.0001)


func test_events_and_spoilage_are_validated() -> void:
	var loader := GameDataLoader.new()
	assert_null(loader.load_dir("res://tests/fixtures/bad_events"))
	var expected: Array[String] = [
		"goods.json[2]: 'spoilage_per_day' must be a multiple of 0.001 (got 0.0005)",
		"events.json[0]: 'chance_per_day' must be a number at least 0.0 and at most 1.0",
		"events.json[0]: 'max_days' must be at least min_days and at most 3650",
		"events.json[0]: 'slowdown' must be between 2 and 24",
		"events.json[1]: 'kind' must be one of storm, harvest_failure, war, fire (got 'plague')",
		"events.json[2]: 'factor' must be a number at least 0.0 and less than 1.0",
		"events.json[2]: 'goods' has unknown good 'amber'",
		"events.json[3]: unknown field 'colour'",
		"events.json[3]: 'id' 'spoilage' is reserved for spoilage",
		"events.json[4]: missing field 'factor'",
		"events.json[5]: entry must be an object",
	]
	assert_eq(Array(loader.errors), expected)
