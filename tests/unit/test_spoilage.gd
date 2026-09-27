extends GutTest
## Spoilage of goods in ships and kontors (SpoilageSystem, ADR 0006, ADR 0011).

const SmallWorld := preload("res://tests/support/small_world.gd")
const PLAYER := WorldState.PLAYER_ID

var _sim: Simulation


func before_each() -> void:
	_sim = SmallWorld.simulation()
	_sim.data.get_good("grain").spoilage_per_day = 0.1


func _ship() -> ShipState:
	return _sim.world.player().ships[0]


func test_whole_units_spoil_at_the_daily_rate() -> void:
	SmallWorld.give_cargo(_sim, _ship(), "grain", 10)
	SpoilageSystem.run_day(_sim.data, _sim.world)
	assert_eq(_ship().cargo_of("grain"), 9)
	assert_true(_ship().spoil_carry.is_empty(), "exactly one unit")
	assert_eq(_sim.world.losses.size(), 1)
	var loss := _sim.world.losses[0]
	assert_eq(
		[loss.trader_id, loss.hold_id, loss.good_id, loss.units, loss.cause],
		[PLAYER, SmallWorld.SHIP_ID, "grain", 1, GoodsLoss.SPOILAGE]
	)
	assert_eq(EconomyInvariants.check(_sim.data, _sim.world), PackedStringArray())


func test_fractions_carry_over_exactly() -> void:
	SmallWorld.give_cargo(_sim, _ship(), "grain", 5)
	var held: Array[int] = []
	for day in 4:
		SpoilageSystem.run_day(_sim.data, _sim.world)
		held.append(_ship().cargo_of("grain"))
	# 0.5, then 1.0 (one lost), then 0.4 of 4, then 0.8.
	assert_eq(held, [5, 4, 4, 4])
	assert_eq(_ship().spoil_carry["grain"], 800_000)
	SpoilageSystem.run_day(_sim.data, _sim.world)
	assert_eq(_ship().cargo_of("grain"), 3, "0.8 + 0.4 = 1.2: one more lost")
	assert_eq(_ship().spoil_carry["grain"], 200_000)


func test_goods_that_keep_and_city_markets_do_not_spoil() -> void:
	SmallWorld.give_cargo(_sim, _ship(), "wine", 10)
	var market: int = _sim.world.get_city("port").stock["grain"]
	for day in 5:
		SpoilageSystem.run_day(_sim.data, _sim.world)
	assert_eq(_ship().cargo_of("wine"), 10)
	assert_eq(_sim.world.get_city("port").stock["grain"], market)


func test_kontors_spoil_too() -> void:
	_sim.world.player().coins = 5000
	assert_eq(_sim.execute(BuyKontorCommand.new(PLAYER, "port")), "")
	assert_eq(_sim.execute(BuyCommand.for_kontor(PLAYER, "port", "grain", 20)), "")
	SpoilageSystem.run_day(_sim.data, _sim.world)
	var kontor := _sim.world.player().get_kontor("port")
	assert_eq(kontor.cargo_of("grain"), 18)
	assert_eq(_sim.world.losses[0].hold_id, "port")
	assert_eq(EconomyInvariants.check(_sim.data, _sim.world), PackedStringArray())


func test_a_fraction_does_not_follow_new_goods_after_the_hold_empties() -> void:
	SmallWorld.give_cargo(_sim, _ship(), "grain", 5)
	SpoilageSystem.run_day(_sim.data, _sim.world)
	assert_eq(_ship().spoil_carry["grain"], 500_000)
	_ship().change_cargo("grain", -5)
	_sim.world.goods_ledger["grain"] -= 5
	SpoilageSystem.run_day(_sim.data, _sim.world)
	assert_false(_ship().spoil_carry.has("grain"))


func test_losses_are_cleared_each_day_with_the_simulation() -> void:
	SmallWorld.give_cargo(_sim, _ship(), "grain", 10)
	_sim.advance_days(1)
	assert_eq(_sim.world.losses.size(), 1)
	_ship().change_cargo("grain", -_ship().cargo_of("grain"))
	_sim.world.goods_ledger["grain"] -= 9
	_sim.advance_days(1)
	assert_eq(_sim.world.losses.size(), 0)
	assert_eq(EconomyInvariants.check(_sim.data, _sim.world), PackedStringArray())
