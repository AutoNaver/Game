extends GutTest
## City growth over long runs (ADR 0010): without the player the shipped cities settle near their
## home populations, and a city grows when it is kept supplied and shrinks when it starves.

const SmallWorld := preload("res://tests/support/small_world.gd")
const Soak := preload("res://tools/soak.gd")
const YEARS_DAYS: int = 730
const CHECK_EVERY_DAYS: int = 30


func test_shipped_cities_neither_explode_nor_starve_without_the_player() -> void:
	var data := GameDataLoader.new().load_dir(GameDataLoader.DEFAULT_DIR)
	var sim := Simulation.new_game(data, 7)
	while sim.day() < YEARS_DAYS:
		sim.advance_days(CHECK_EVERY_DAYS)
		assert_eq(
			EconomyInvariants.check(data, sim.world), PackedStringArray(), "day %d" % sim.day()
		)
	assert_eq(Soak.check_populations(data, sim.world), PackedStringArray())
	for city in sim.world.cities:
		gut.p("%s: %d people, satisfaction %d" % [city.id, city.population, city.satisfaction])


func test_a_supplied_city_grows_and_a_starved_one_shrinks() -> void:
	var supplied := _growing_town_simulation()
	var starved := _growing_town_simulation()
	for day in 200:
		# Deliveries keep the supplied town at its target stock of everything.
		for good in supplied.data.goods:
			var town := supplied.world.get_city("town")
			var target := CityEconomy.target_stock(supplied.data.economy, town, good)
			SmallWorld.set_stock(supplied, "town", good.id, maxi(town.stock[good.id], target))
		supplied.advance_days(1)
		starved.advance_days(1)
	var grown := supplied.world.get_city("town")
	var shrunk := starved.world.get_city("town")
	assert_gt(grown.satisfaction, 900_000)
	assert_between(grown.population, 1300, 1500, "towards 1.5x home at full satisfaction")
	assert_lt(shrunk.satisfaction, 100_000)
	assert_between(shrunk.population, 500, 700, "towards the 0.5x floor")
	assert_eq(EconomyInvariants.check(supplied.data, supplied.world), PackedStringArray())
	assert_eq(EconomyInvariants.check(starved.data, starved.world), PackedStringArray())


## SmallWorld's town makes nothing and gets no off-map imports, so it runs out without deliveries.
func _growing_town_simulation() -> Simulation:
	var sim := SmallWorld.simulation()
	sim.data.population.growth_rate = 0.02
	return sim
