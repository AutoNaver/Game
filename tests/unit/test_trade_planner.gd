extends GutTest
## TradePlanner: the most profitable load per destination at today's prices.

const SmallWorld := preload("res://tests/support/small_world.gd")
const PLAYER := WorldState.PLAYER_ID


## Port has a grain glut and town none, so grain from port to town pays.
func _glut_simulation() -> Simulation:
	var sim := SmallWorld.simulation(1)
	SmallWorld.set_stock(sim, "port", "grain", 40)
	SmallWorld.set_stock(sim, "town", "grain", 0)
	return sim


func _plan(sim: Simulation, space: int, coins: int) -> Array[TradePlanner.Option]:
	var boat := sim.data.get_ship("boat")
	return TradePlanner.plan(sim.data, sim.world, boat, "port", space, coins)


func test_the_plan_matches_a_real_voyage() -> void:
	var sim := _glut_simulation()
	var options := _plan(sim, 10, 1000)
	assert_eq(options.size(), 1)
	var option := options[0]
	assert_eq([option.destination, option.good_id, option.quantity], ["town", "grain", 10])
	assert_eq(option.hours, 10)
	var coins := sim.world.player().coins
	assert_eq(sim.execute(BuyCommand.new(PLAYER, SmallWorld.SHIP_ID, "grain", 10)), "")
	assert_eq(coins - sim.world.player().coins, option.cost)
	assert_eq(sim.execute(SailCommand.new(PLAYER, SmallWorld.SHIP_ID, "town")), "")
	for i in option.hours:
		sim.tick()
	assert_eq(sim.execute(SellCommand.new(PLAYER, SmallWorld.SHIP_ID, "grain", 10)), "")
	assert_eq(sim.world.player().coins - coins, option.profit())


func test_the_load_is_the_best_rounded_profit() -> void:
	var sim := _glut_simulation()
	var option := _plan(sim, 1000, 100000)[0]
	assert_lt(option.quantity, 40, "not the whole glut")
	var best := _best_by_brute_force(sim, "port", "town", "grain", 40)
	assert_eq([option.quantity, option.profit()], best)


func test_small_loads_that_only_pay_after_rounding_are_found() -> void:
	# Shipped data near break-even: the unrounded optimum (4 grain) rounds to zero profit, but
	# 3 grain still earns a coin once cost is rounded up and revenue down.
	var data := GameDataLoader.new().load_dir(GameDataLoader.DEFAULT_DIR)
	var sim := Simulation.new_game(data, 1)
	SmallWorld.set_stock(sim, "lubeck", "grain", 138)
	SmallWorld.set_stock(sim, "danzig", "grain", 4)
	var cog := data.get_ship("cog")
	var options := TradePlanner.plan(data, sim.world, cog, "lubeck", 50, 100000)
	var to_danzig: Array = options.filter(
		func(option: TradePlanner.Option) -> bool: return option.destination == "danzig"
	)
	assert_eq(to_danzig.size(), 1)
	var option: TradePlanner.Option = to_danzig[0]
	assert_eq(option.good_id, "grain")
	var best := _best_by_brute_force(sim, "lubeck", "danzig", "grain", 50)
	assert_eq([option.quantity, option.profit()], best)
	assert_gt(option.profit(), 0)


func test_the_load_is_limited_by_coins_and_space() -> void:
	var sim := _glut_simulation()
	var cheap := _plan(sim, 10, 100)[0]
	assert_lte(cheap.cost, 100)
	var economy := sim.data.economy
	var grain := sim.data.get_good("grain")
	var port := sim.world.get_city("port")
	assert_gt(CityEconomy.buy_cost(economy, port, grain, cheap.quantity + 1), 100)
	assert_eq(_plan(sim, 3, 1000)[0].quantity, 3)
	assert_eq(_plan(sim, 0, 1000).size(), 0)
	assert_eq(_plan(sim, 10, 0).size(), 0)


func test_balanced_markets_offer_nothing() -> void:
	# At the start every market holds its target stock, so the spread eats any margin.
	var sim := SmallWorld.simulation(1)
	assert_eq(_plan(sim, 10, 1000).size(), 0)


func test_profit_per_day_scales_by_sailing_time() -> void:
	var option := TradePlanner.Option.new("town", "grain", 5, 100, 160, 12)
	assert_eq(option.profit(), 60)
	assert_eq(option.profit_per_day(), 120.0)


## [quantity, profit] of the smallest load with the highest rounded profit, trying every size.
func _best_by_brute_force(
	sim: Simulation, from_city: String, to_city: String, good_id: String, limit: int
) -> Array:
	var economy := sim.data.economy
	var good := sim.data.get_good(good_id)
	var source := sim.world.get_city(from_city)
	var market := sim.world.get_city(to_city)
	var best: Array = [0, 0]
	for quantity in range(1, mini(limit, source.stock[good_id]) + 1):
		var profit := (
			CityEconomy.sell_revenue(economy, market, good, quantity)
			- CityEconomy.buy_cost(economy, source, good, quantity)
		)
		if profit > best[1]:
			best = [quantity, profit]
	return best
