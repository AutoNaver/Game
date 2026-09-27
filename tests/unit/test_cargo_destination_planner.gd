extends GutTest
## Destinations for goods already in a docked ship, at current market prices.

const SmallWorld := preload("res://tests/support/small_world.gd")


func _loaded_simulation() -> Simulation:
	var sim := SmallWorld.simulation(1)
	SmallWorld.set_stock(sim, "port", "grain", 40)
	SmallWorld.set_stock(sim, "town", "grain", 0)
	SmallWorld.give_cargo(sim, sim.world.player().ships[0], "grain", 5)
	return sim


func test_destination_value_matches_selling_after_the_voyage() -> void:
	var sim := _loaded_simulation()
	var ship := sim.world.player().ships[0]
	var options := CargoDestinationPlanner.plan(sim.data, sim.world, ship)
	assert_eq(options.size(), 1)
	var option := options[0]
	assert_eq(option.destination, "town")
	assert_eq(option.hours, 10)
	assert_gt(option.extra_value(), 0)
	assert_eq(option.extra_value(), option.sale_value - option.local_value)
	assert_eq(option.extra_per_day(), option.extra_value() * 24.0 / 10.0)
	var coins := sim.world.player().coins
	assert_eq(sim.execute(SailCommand.new(WorldState.PLAYER_ID, ship.id, "town")), "")
	for i in option.hours:
		sim.tick()
	assert_eq(sim.execute(SellCommand.new(WorldState.PLAYER_ID, ship.id, "grain", 5)), "")
	assert_eq(sim.world.player().coins - coins, option.sale_value)


func test_sale_value_sums_each_good_without_changing_state() -> void:
	var sim := _loaded_simulation()
	var ship := sim.world.player().ships[0]
	SmallWorld.give_cargo(sim, ship, "wine", 2)
	var city := sim.world.get_city("town")
	var before_stock := city.stock.duplicate()
	var before_cargo := ship.cargo.duplicate()
	var expected := (
		CityEconomy.sell_revenue(sim.data.economy, city, sim.data.get_good("grain"), 5)
		+ CityEconomy.sell_revenue(sim.data.economy, city, sim.data.get_good("wine"), 2)
	)
	assert_eq(CargoDestinationPlanner.sale_value(sim.data, city, ship), expected)
	assert_eq(city.stock, before_stock)
	assert_eq(ship.cargo, before_cargo)


func test_empty_and_sailing_ships_have_no_destinations() -> void:
	var sim := SmallWorld.simulation(1)
	var ship := sim.world.player().ships[0]
	assert_eq(CargoDestinationPlanner.plan(sim.data, sim.world, ship).size(), 0)
	SmallWorld.give_cargo(sim, ship, "grain", 3)
	assert_eq(sim.execute(SailCommand.new(WorldState.PLAYER_ID, ship.id, "town")), "")
	assert_eq(CargoDestinationPlanner.plan(sim.data, sim.world, ship).size(), 0)


func test_does_not_suggest_a_market_that_pays_less_than_here() -> void:
	var sim := SmallWorld.simulation(1)
	SmallWorld.set_stock(sim, "port", "grain", 0)
	SmallWorld.set_stock(sim, "town", "grain", 40)
	var ship := sim.world.player().ships[0]
	SmallWorld.give_cargo(sim, ship, "grain", 5)
	assert_eq(CargoDestinationPlanner.plan(sim.data, sim.world, ship).size(), 0)
