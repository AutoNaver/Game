extends GutTest
## Captains gate sailing, grow with voyages and apply their skills through the command layer.

const SmallWorld := preload("res://tests/support/small_world.gd")
const PLAYER: String = WorldState.PLAYER_ID


func test_new_ship_needs_a_tavern_captain_before_sailing() -> void:
	var sim := SmallWorld.simulation()
	assert_eq(sim.execute(BuyShipCommand.new(PLAYER, "port", "boat")), "")
	var ship := sim.world.player().get_ship("ship_2")
	assert_eq(
		sim.execute(SailCommand.new(PLAYER, ship.id, "town")), "Boat 2 needs a captain to sail"
	)
	var pool: Array = sim.world.taverns["port"]
	var candidate: CaptainState = pool[0]
	var coins := sim.world.player().coins
	assert_eq(sim.execute(HireCaptainCommand.new(PLAYER, ship.id, candidate.id)), "")
	assert_eq(sim.world.player().coins, coins - sim.data.captains.hiring_fee)
	assert_eq(ship.captain_id, candidate.id)
	assert_eq(pool.size(), 1)
	assert_eq(sim.execute(SailCommand.new(PLAYER, ship.id, "town")), "")


func test_player_can_move_only_within_a_port() -> void:
	var sim := SmallWorld.simulation()
	assert_eq(sim.execute(BuyShipCommand.new(PLAYER, "port", "boat")), "")
	assert_eq(sim.execute(MovePersonCommand.new("ship_2")), "")
	assert_eq(sim.world.player().person_ship_id, "ship_2")
	assert_eq(sim.execute(MovePersonCommand.new()), "")
	assert_eq(sim.world.player().person_city_id, "port")
	assert_eq(sim.execute(SailCommand.new(PLAYER, "ship_1", "town")), "")
	assert_eq(sim.execute(MovePersonCommand.new("ship_1")), "The ship must be in your port")


func test_experienced_captain_shortens_voyage_and_improves_trade_spread() -> void:
	var sim := SmallWorld.simulation()
	var ship := sim.world.player().ships[0]
	var captain := sim.world.player().get_captain(ship.captain_id)
	captain.voyages = sim.data.captains.voyages_per_level - 1
	assert_eq(sim.execute(SailCommand.new(PLAYER, ship.id, "town")), "")
	sim.tick()
	for i in 9:
		sim.tick()
	assert_eq(captain.seamanship, 1)
	assert_eq(captain.trading, 1)
	assert_eq(sim.execute(SailCommand.new(PLAYER, ship.id, "port")), "")
	assert_eq(ship.voyage_hours, 8)
	assert_lt(
		CaptainSystem.trade_spread(sim.data, sim.world.player(), ship.id), sim.data.economy.spread
	)


func test_trading_skill_changes_the_actual_buy_command_cost() -> void:
	var sim := SmallWorld.simulation()
	var ship := sim.world.player().ships[0]
	var captain := sim.world.player().get_captain(ship.captain_id)
	captain.trading = sim.data.captains.max_skill
	var city := sim.world.get_city("port")
	var good := sim.data.get_good("wine")
	var no_spread := CityEconomy.buy_cost(sim.data.economy, city, good, 1, 0.0)
	var ordinary := CityEconomy.buy_cost(sim.data.economy, city, good, 1)
	assert_lt(no_spread, ordinary)
	var before := sim.world.player().coins
	assert_eq(sim.execute(BuyCommand.new(PLAYER, ship.id, good.id, 1)), "")
	assert_eq(before - sim.world.player().coins, no_spread)


func test_unpaid_wages_create_debt_then_bankruptcy() -> void:
	var sim := SmallWorld.simulation()
	sim.world.player().coins = 0
	sim.advance_days(sim.data.captains.bankruptcy_grace_days - 1)
	assert_false(sim.world.player().bankrupt)
	assert_gt(sim.world.player().debt, 0)
	sim.advance_days(1)
	assert_true(sim.world.player().bankrupt)
	assert_eq(sim.world.player().debt_days, sim.data.captains.bankruptcy_grace_days)
	assert_eq(sim.world.player().coins, 0)


func test_old_save_gains_captains_without_losing_ships() -> void:
	var sim := SmallWorld.simulation()
	var save := SaveGame.to_dict(sim.world)
	save["save_version"] = 6
	save.erase("next_captain_number")
	save.erase("taverns")
	for trader: Dictionary in save["traders"]:
		for field: String in [
			"debt", "debt_days", "bankrupt", "person_ship", "person_city", "captains"
		]:
			trader.erase(field)
		for ship: Dictionary in trader["ships"]:
			ship.erase("captain")
	var loader := SaveGame.new()
	var restored := loader.from_dict(sim.data, save)
	assert_eq(Array(loader.errors), [])
	assert_not_null(restored)
	if restored != null:
		assert_eq(restored.player().person_ship_id, SmallWorld.SHIP_ID)
		assert_false(restored.player().ships[0].captain_id.is_empty())
		assert_eq(EconomyInvariants.check(sim.data, restored), PackedStringArray())


func test_corrupt_captain_assignment_is_rejected_on_load() -> void:
	var sim := SmallWorld.simulation()
	var save := SaveGame.to_dict(sim.world)
	save["traders"][0]["ships"][0]["captain"] = "captain_999"
	var loader := SaveGame.new()
	assert_null(loader.from_dict(sim.data, save))
	assert_string_contains(" ".join(loader.errors), "unknown captain")


func test_bankrupt_rival_leaves_and_goods_return_to_the_market() -> void:
	var sim := SmallWorld.rival_simulation()
	var rival := sim.world.get_trader(SmallWorld.RIVAL_ID)
	var ship := rival.ships[0]
	SmallWorld.give_cargo(sim, ship, "grain", 3)
	var before: int = sim.world.get_city("port").stock["grain"]
	rival.coins = 0
	rival.debt_days = sim.data.captains.bankruptcy_grace_days - 1
	rival.debt = 1000
	CaptainSystem.run_day(sim.data, sim.world, 1)
	assert_null(sim.world.get_trader(SmallWorld.RIVAL_ID))
	assert_eq(sim.world.get_city("port").stock["grain"], before + 3)
	assert_eq(EconomyInvariants.check(sim.data, sim.world), PackedStringArray())
