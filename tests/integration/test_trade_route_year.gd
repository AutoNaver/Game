extends GutTest
## A looping trade route on the shipped data runs for a year: it stays profitable, never breaks an
## economy invariant, and runs identically from the same seed.

const PLAYER := WorldState.PLAYER_ID
const DAYS: int = 365
const CHECK_EVERY_DAYS: int = 30


## Salt from Lübeck to Danzig, grain back, buying at or below base price and selling at or above.
func _routed_simulation(seed_value: int) -> Simulation:
	var data := GameDataLoader.new().load_dir(GameDataLoader.DEFAULT_DIR)
	var sim := Simulation.new_game(data, seed_value)
	# Trade routes need the rank Merchant.
	sim.world.player().rank_id = "merchant"
	var salt := data.get_good("salt").base_price
	var grain := data.get_good("grain").base_price
	var lubeck: Array[RouteOrder] = [
		RouteOrder.new(RouteOrder.Action.SELL, "grain", 50, grain),
		RouteOrder.new(RouteOrder.Action.BUY, "salt", 50, salt),
	]
	var danzig: Array[RouteOrder] = [
		RouteOrder.new(RouteOrder.Action.SELL, "salt", 50, salt),
		RouteOrder.new(RouteOrder.Action.BUY, "grain", 50, grain),
	]
	var stops: Array[RouteStop] = [RouteStop.new("lubeck", lubeck), RouteStop.new("danzig", danzig)]
	assert_eq(sim.execute(SaveRouteCommand.new(PLAYER, "", "Salt and grain", stops)), "")
	var ship_id := sim.world.player().ships[0].id
	assert_eq(sim.execute(AssignRouteCommand.new(PLAYER, ship_id, "route_1")), "")
	return sim


func test_a_route_runs_profitably_for_a_year() -> void:
	var sim := _routed_simulation(1)
	var start_coins := sim.world.player().coins
	while sim.day() < DAYS:
		sim.advance_days(mini(CHECK_EVERY_DAYS, DAYS - sim.day()))
		var day := sim.day()
		assert_eq(EconomyInvariants.check(sim.data, sim.world), PackedStringArray(), "day %d" % day)
	assert_eq(sim.day(), DAYS)
	var coins := sim.world.player().coins
	gut.p("coins after %d days: %d (started with %d)" % [DAYS, coins, start_coins])
	assert_gt(coins, start_coins, "the route made money")
	assert_eq(sim.world.player().ships[0].route_id, "route_1", "still on its route")


func test_the_same_seed_runs_the_route_identically() -> void:
	var first := _routed_simulation(7)
	var second := _routed_simulation(7)
	first.advance_days(60)
	second.advance_days(60)
	assert_eq(SaveGame.to_dict(first.world), SaveGame.to_dict(second.world))
