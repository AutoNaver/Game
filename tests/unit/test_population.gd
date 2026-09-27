extends GutTest
## City satisfaction and population change (PopulationSystem, ADR 0010).
##
## SmallWorld: grain (2.0/day per 1000, base 40, target 20) and wine (0.5/day, base 220,
## target 5). Spending weights are 2000 × 40 = 80 000 for grain and 500 × 220 = 110 000 for wine.

const SmallWorld := preload("res://tests/support/small_world.gd")
const PLAYER := WorldState.PLAYER_ID
const FULL: int = CityEconomy.PARTS_PER_UNIT


func _population(sim: Simulation) -> PopulationDef:
	return sim.data.population


func test_supply_is_stock_against_target_capped_at_full() -> void:
	var sim := SmallWorld.simulation()
	var town := sim.world.get_city("town")
	SmallWorld.set_stock(sim, "town", "grain", 5)
	assert_eq(PopulationSystem.supply(sim.data.economy, town, sim.data.get_good("grain")), 250_000)
	SmallWorld.set_stock(sim, "town", "grain", 60)
	assert_eq(PopulationSystem.supply(sim.data.economy, town, sim.data.get_good("grain")), FULL)


func test_supply_score_weighs_goods_by_spending() -> void:
	var sim := SmallWorld.simulation()
	var town := sim.world.get_city("town")
	assert_eq(PopulationSystem.supply_score(sim.data, town), FULL, "every good at target")
	SmallWorld.set_stock(sim, "town", "grain", 0)
	# Only wine is supplied: 110 000 of 190 000.
	assert_eq(PopulationSystem.supply_score(sim.data, town), 578_947)
	SmallWorld.set_stock(sim, "town", "grain", 20)
	SmallWorld.set_stock(sim, "town", "wine", 0)
	assert_eq(PopulationSystem.supply_score(sim.data, town), 421_052, "wine weighs more")


func test_new_games_start_at_home_population_and_neutral_satisfaction() -> void:
	var sim := SmallWorld.simulation()
	for city in sim.world.cities:
		assert_eq(city.population, sim.data.get_city(city.id).population)
		assert_eq(city.satisfaction, 500_000)


func test_satisfaction_moves_a_share_of_the_way_to_the_day_score() -> void:
	var sim := SmallWorld.simulation()
	var town := sim.world.get_city("town")
	PopulationSystem.run_day(sim.data, sim.world)
	assert_eq(town.satisfaction, 550_000, "a tenth of the way from 0.5 to a full market")
	SmallWorld.set_stock(sim, "town", "grain", 0)
	SmallWorld.set_stock(sim, "town", "wine", 0)
	PopulationSystem.run_day(sim.data, sim.world)
	assert_eq(town.satisfaction, 495_000, "a tenth of the way from 0.55 to an empty market")


func test_a_shortage_counts_as_no_supply_on_that_day() -> void:
	var sim := SmallWorld.simulation()
	var town := sim.world.get_city("town")
	SmallWorld.set_stock(sim, "town", "grain", 1)
	# Consumption takes the last unit and runs short; the city is measured afterwards, so grain
	# counts as empty: the day scores 578 947 instead of a full market's 1 000 000.
	sim.advance_days(1)
	assert_eq(town.shortage["grain"], 1)
	assert_eq(town.satisfaction, 507_894)


func test_sustainable_population_follows_satisfaction_within_bounds() -> void:
	var sim := SmallWorld.simulation()
	var town := sim.world.get_city("town")
	assert_eq(PopulationSystem.sustainable_population(sim.data, town), 1000, "neutral")
	town.satisfaction = 700_000
	assert_eq(PopulationSystem.sustainable_population(sim.data, town), 1200)
	town.satisfaction = 200_000
	assert_eq(PopulationSystem.sustainable_population(sim.data, town), 700)
	_population(sim).sensitivity = 3.0
	assert_eq(PopulationSystem.sustainable_population(sim.data, town), 500, "min_factor 0.5")
	town.satisfaction = FULL
	assert_eq(PopulationSystem.sustainable_population(sim.data, town), 2000, "max_factor 2")


func test_population_moves_a_share_of_the_gap_each_day() -> void:
	var sim := SmallWorld.simulation()
	_population(sim).growth_rate = 0.1
	_population(sim).satisfaction_weight = 0.0
	var town := sim.world.get_city("town")
	town.satisfaction = 700_000
	assert_eq(PopulationSystem.daily_change(sim.data, town), 20)
	PopulationSystem.run_day(sim.data, sim.world)
	assert_eq(town.population, 1020, "a tenth of the 200 gap")
	PopulationSystem.run_day(sim.data, sim.world)
	assert_eq(town.population, 1038)
	town.satisfaction = 300_000
	PopulationSystem.run_day(sim.data, sim.world)
	assert_eq(town.population, 1015, "a tenth of the gap down to 800")


func test_growth_raises_demand_and_workforce() -> void:
	var sim := SmallWorld.simulation()
	_population(sim).growth_rate = 1.0
	_population(sim).satisfaction_weight = 0.0
	var town := sim.world.get_city("town")
	var grain := sim.data.get_good("grain")
	town.satisfaction = 800_000
	PopulationSystem.run_day(sim.data, sim.world)
	assert_eq(town.population, 1300)
	assert_eq(CityEconomy.target_stock(sim.data.economy, town, grain), 26)
	assert_eq(CityEconomy.workforce(sim.data.economy, town), 130)


func test_cities_do_not_shrink_below_their_employed_workers() -> void:
	var sim := SmallWorld.simulation()
	sim.world.player().coins = 5000
	assert_eq(sim.execute(BuyKontorCommand.new(PLAYER, "port")), "")
	assert_eq(sim.execute(BuildWorkshopCommand.new(PLAYER, "port", "vintner")), "")
	_population(sim).min_factor = 0.1
	_population(sim).sensitivity = 2.0
	_population(sim).growth_rate = 1.0
	_population(sim).satisfaction_weight = 0.0
	var port := sim.world.get_city("port")
	port.satisfaction = 0
	PopulationSystem.run_day(sim.data, sim.world)
	# Unhappy enough for 100 people, but the vintner's 30 workers need a workforce of 30.
	assert_eq(port.population, 300)
	assert_eq(CityEconomy.free_workers(sim.data, sim.world, port), 0)
	assert_eq(Array(EconomyInvariants.check(sim.data, sim.world)), [])


func test_invariants_catch_populations_and_satisfaction_out_of_range() -> void:
	var sim := SmallWorld.simulation()
	var town := sim.world.get_city("town")
	town.population = 2001
	town.satisfaction = FULL + 1
	var violations := EconomyInvariants.check(sim.data, sim.world)
	assert_eq(violations.size(), 2)
	assert_string_contains(violations[0], "town: population 2001 outside 500 to 2000")
	assert_string_contains(violations[1], "town: satisfaction 1000001 out of range")
