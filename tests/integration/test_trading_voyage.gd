extends GutTest
## End-to-end trade loop through the command API: buy where it's cheap, sail, sell where it's dear.

const SmallWorld := preload("res://tests/support/small_world.gd")
const PLAYER := WorldState.PLAYER_ID
const SHIP := SmallWorld.SHIP_ID


func test_grain_run_from_producer_to_starving_town_makes_money() -> void:
	var sim := SmallWorld.simulation()
	# Town produces no grain: after its 10 days of cover it's empty and grain is at max price.
	sim.advance_days(12)
	assert_eq(sim.world.get_city("town").stock["grain"], 0)

	var coins_before := sim.world.player().coins
	assert_eq(sim.execute(BuyCommand.new(PLAYER, SHIP, "grain", 10)), "")
	assert_eq(sim.execute(SailCommand.new(PLAYER, SHIP, "town")), "")
	for i in 10:
		sim.tick()
	assert_eq(sim.world.player().get_ship(SHIP).docked_at, "town")
	assert_eq(sim.execute(SellCommand.new(PLAYER, SHIP, "grain", 10)), "")

	var profit := sim.world.player().coins - coins_before
	assert_gt(profit, 0, "a cheap-to-dear grain run must pay off")
	assert_eq(EconomyInvariants.check(sim.data, sim.world), PackedStringArray())


func test_dumping_cargo_crashes_the_price() -> void:
	var sim := SmallWorld.simulation()
	var town := sim.world.get_city("town")
	var grain := sim.data.get_good("grain")
	var ship := sim.world.player().get_ship(SHIP)
	ship.docked_at = "town"
	ship.cargo["grain"] = 10
	town.stock["grain"] = 0
	var first_half := CityEconomy.sell_revenue(sim.data.economy, town, grain, 5)
	sim.execute(SellCommand.new(PLAYER, SHIP, "grain", 5))
	var second_half := CityEconomy.sell_revenue(sim.data.economy, town, grain, 5)
	assert_lt(second_half, first_half, "the second five sell for less than the first five")
