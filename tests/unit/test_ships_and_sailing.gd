extends GutTest

const SmallWorld := preload("res://tests/support/small_world.gd")
const SHIP := SmallWorld.SHIP_ID


func test_new_game_gives_the_player_the_scenario_fleet() -> void:
	var sim := SmallWorld.simulation()
	var player := sim.world.player()
	assert_eq(player.coins, SmallWorld.START_COINS)
	assert_eq(player.ships.size(), 1)
	var ship := player.ships[0]
	assert_eq([ship.id, ship.type_id, ship.name, ship.docked_at], [SHIP, "boat", "Test", "port"])
	assert_eq(ship.cargo, {})
	assert_eq(sim.world.next_ship_number, 2)


func test_travel_hours_round_up_and_are_at_least_one() -> void:
	var data := SmallWorld.data()
	var boat := data.get_ship("boat")
	assert_eq(Navigation.travel_hours(data, boat, "port", "town"), 10)
	var fast := ShipDef.new("fast", "Fast", 1, 30.0, 1)
	assert_eq(Navigation.travel_hours(data, fast, "port", "town"), 4, "100 / 30 rounds up")
	var rocket := ShipDef.new("rocket", "Rocket", 1, 999.0, 1)
	assert_eq(Navigation.travel_hours(data, rocket, "port", "town"), 1)


func test_slowest_allowed_ship_on_the_longest_possible_route_fits_in_int() -> void:
	# Map units are km; half the Earth's circumference is the longest straight route possible.
	var data := GameData.new()
	var none: Dictionary[String, float] = {}
	data.add_city(CityDef.new("a", "A", Vector2.ZERO, 1, none))
	data.add_city(CityDef.new("b", "B", Vector2(20_000, 0), 1, none))
	var slowest := ShipDef.new("slow", "Slow", 1, GameDataLoader.MIN_SHIP_SPEED, 1)
	assert_eq(Navigation.travel_hours(data, slowest, "a", "b"), 200_000)


func test_sail_command_starts_a_voyage() -> void:
	var sim := SmallWorld.simulation()
	assert_eq(sim.execute(SailCommand.new(WorldState.PLAYER_ID, SHIP, "town")), "")
	var ship := sim.world.player().get_ship(SHIP)
	assert_false(ship.is_docked())
	assert_eq([ship.origin, ship.destination, ship.voyage_hours], ["port", "town", 10])
	assert_eq(Navigation.position(sim.data, ship), Vector2.ZERO)


func test_ship_arrives_after_exactly_its_voyage_hours() -> void:
	var sim := SmallWorld.simulation()
	sim.execute(SailCommand.new(WorldState.PLAYER_ID, SHIP, "town"))
	var ship := sim.world.player().get_ship(SHIP)
	for i in 5:
		sim.tick()
	assert_eq(Navigation.position(sim.data, ship), Vector2(50, 0), "halfway after 5 of 10 hours")
	for i in 4:
		sim.tick()
	assert_false(ship.is_docked(), "still at sea after 9 hours")
	sim.tick()
	assert_eq(ship.docked_at, "town")
	assert_eq([ship.origin, ship.destination, ship.voyage_hours], ["", "", 0])
	assert_eq(Navigation.position(sim.data, ship), Vector2(100, 0))


func test_invalid_sail_commands_change_nothing() -> void:
	var sim := SmallWorld.simulation()
	var player := WorldState.PLAYER_ID
	var cases := {
		"unknown ship 'ship_9'": SailCommand.new(player, "ship_9", "town"),
		"unknown ship 'ship_1'": SailCommand.new("nobody", SHIP, "town"),
		"unknown city 'atlantis'": SailCommand.new(player, SHIP, "atlantis"),
		"Test is already in Port": SailCommand.new(player, SHIP, "port"),
	}
	for expected: String in cases:
		assert_eq(sim.execute(cases[expected] as Command), expected)
	assert_eq(sim.world.player().get_ship(SHIP).docked_at, "port")


func test_cannot_redirect_a_ship_at_sea() -> void:
	var sim := SmallWorld.simulation()
	sim.execute(SailCommand.new(WorldState.PLAYER_ID, SHIP, "town"))
	var error := sim.execute(SailCommand.new(WorldState.PLAYER_ID, SHIP, "port"))
	assert_eq(error, "Test is already at sea")
	assert_eq(sim.world.player().get_ship(SHIP).destination, "town")


func test_invariants_report_unknown_ship_types_instead_of_crashing() -> void:
	var sim := SmallWorld.simulation()
	sim.world.player().get_ship(SHIP).type_id = "galleon"
	var violations := EconomyInvariants.check(sim.data, sim.world)
	assert_eq(violations.size(), 1)
	assert_string_contains(violations[0], "ship_1: unknown ship type 'galleon'")


func test_invariants_catch_broken_ships_and_coins() -> void:
	var sim := SmallWorld.simulation()
	var player := sim.world.player()
	var ship := player.get_ship(SHIP)
	player.coins = -1
	ship.cargo["grain"] = 11
	var violations := EconomyInvariants.check(sim.data, sim.world)
	assert_eq(violations.size(), 3)
	assert_string_contains(violations[0], "player: negative coins -1")
	assert_string_contains(violations[1], "ship_1: cargo 11 over capacity 10")
	assert_string_contains(violations[2], "grain: 51 units exist", "cargo counts toward the ledger")


func test_change_cargo_adds_and_removes_units() -> void:
	var ship := ShipState.new("ship_9", "boat", "Probe", "port")
	assert_true(ship.change_cargo("grain", 4))
	ship.change_cargo("wine", 1)
	ship.change_cargo("grain", 3)
	assert_eq(ship.cargo, {"grain": 7, "wine": 1})
	assert_eq(ship.cargo_total(), 8)
	ship.change_cargo("grain", -2)
	assert_eq(ship.cargo_of("grain"), 5)


func test_change_cargo_drops_entries_that_reach_zero() -> void:
	var ship := ShipState.new("ship_9", "boat", "Probe", "port")
	ship.change_cargo("wine", 2)
	ship.change_cargo("wine", -2)
	assert_eq(ship.cargo, {}, "no zero-valued entries left behind")
	assert_eq(ship.cargo_of("wine"), 0)
	assert_eq(ship.cargo_total(), 0)


func test_change_cargo_rejects_removing_more_than_aboard() -> void:
	var ship := ShipState.new("ship_9", "boat", "Probe", "port")
	ship.change_cargo("grain", 1)
	assert_false(ship.change_cargo("grain", -2))
	assert_false(ship.change_cargo("wine", -1))
	assert_eq(ship.cargo, {"grain": 1}, "a refused change leaves the cargo as it was")
