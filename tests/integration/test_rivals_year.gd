extends GutTest
## The rival houses on the shipped data for a year: they never break an economy invariant, all of
## them grow, and they leave the player room to trade.

const DAYS: int = 365
const CHECK_EVERY_DAYS: int = 30


func test_rivals_grow_for_a_year_without_breaking_invariants() -> void:
	var data := GameDataLoader.new().load_dir(GameDataLoader.DEFAULT_DIR)
	var sim := Simulation.new_game(data, 1)
	var start_worth: Dictionary[String, int] = {}
	for rival in data.rivals:
		start_worth[rival.id] = HouseValue.net_worth(data, sim.world.get_trader(rival.id))
	while sim.day() < DAYS:
		sim.advance_days(mini(CHECK_EVERY_DAYS, DAYS - sim.day()))
		var day := sim.day()
		assert_eq(EconomyInvariants.check(data, sim.world), PackedStringArray(), "day %d" % day)
	assert_eq(data.rivals.size(), 3)
	for rival in data.rivals:
		var trader := sim.world.get_trader(rival.id)
		var worth := HouseValue.net_worth(data, trader)
		gut.p(
			(
				"%s: worth %d, %d ships, %d kontors"
				% [trader.name, worth, trader.ships.size(), trader.kontors.size()]
			)
		)
		assert_gt(worth, start_worth[rival.id] * 5, "%s grew" % rival.name)
		assert_eq(trader.ships.size(), data.rival_ai.max_ships, "%s filled its fleet" % rival.name)
		assert_gt(trader.kontors.size(), 0, "%s bought a kontor" % rival.name)
		assert_eq(sim.world.player().coins, data.scenario.coins, "the idle player is untouched")


func test_different_seeds_play_out_differently() -> void:
	var data := GameDataLoader.new().load_dir(GameDataLoader.DEFAULT_DIR)
	var first := Simulation.new_game(data, 1)
	var second := Simulation.new_game(data, 2)
	first.advance_days(20)
	second.advance_days(20)
	assert_ne(SaveGame.to_dict(first.world)["traders"], SaveGame.to_dict(second.world)["traders"])
