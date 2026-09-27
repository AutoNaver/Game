extends GutTest
## Building workshops and their daily work (WorkshopSystem). SmallWorld's "vintner" turns 4 grain
## into 2 wine a day for 10 coins of wages and employs 30 of a city's 100 workers.

const SmallWorld := preload("res://tests/support/small_world.gd")
const PLAYER := WorldState.PLAYER_ID

var _sim: Simulation


func before_each() -> void:
	_sim = SmallWorld.simulation()


func _player() -> TraderState:
	return _sim.world.player()


func _kontor() -> KontorState:
	return _player().get_kontor("port")


## A kontor in port with `grain` units of grain bought into it and one vintner.
func _set_up(grain: int) -> WorkshopState:
	_player().coins = 5000
	assert_eq(_sim.execute(BuyKontorCommand.new(PLAYER, "port")), "")
	if grain > 0:
		assert_eq(_sim.execute(BuyCommand.for_kontor(PLAYER, "port", "grain", grain)), "")
	assert_eq(_sim.execute(BuildWorkshopCommand.new(PLAYER, "port", "vintner")), "")
	return _kontor().workshops[0]


func test_building_needs_a_kontor_coins_and_workers() -> void:
	assert_eq(
		_sim.execute(BuildWorkshopCommand.new(PLAYER, "port", "vintner")),
		"You need a kontor in Port first"
	)
	_sim.execute(BuyKontorCommand.new(PLAYER, "port"))
	assert_eq(
		_sim.execute(BuildWorkshopCommand.new(PLAYER, "port", "mill")),
		"unknown workshop type 'mill'"
	)
	_player().coins = 10_000
	for i in 3:
		assert_eq(_sim.execute(BuildWorkshopCommand.new(PLAYER, "port", "vintner")), "")
	assert_eq(
		_sim.execute(BuildWorkshopCommand.new(PLAYER, "port", "vintner")),
		"A Vintner needs 30 workers; Port has only 10 free"
	)
	assert_eq(_kontor().workshops.size(), 3)
	assert_eq(_player().coins, 10_000 - 3 * 200)
	_player().coins = 5
	assert_eq(
		_sim.execute(BuildWorkshopCommand.new(PLAYER, "port", "vintner")),
		"A Vintner costs 200 coins, you have 5"
	)


func test_workshop_ids_are_sequential() -> void:
	_player().coins = 10_000
	var first := _set_up(0)
	_sim.execute(BuildWorkshopCommand.new(PLAYER, "port", "vintner"))
	assert_eq([first.id, _kontor().workshops[1].id], ["workshop_1", "workshop_2"])


func test_a_working_day_turns_inputs_into_output_and_pays_wages() -> void:
	var workshop := _set_up(8)
	var coins := _player().coins
	WorkshopSystem.run_day(_sim.data, _sim.world)
	assert_eq(workshop.status, WorkshopState.Status.WORKED)
	assert_eq(_kontor().cargo, {"grain": 4, "wine": 2})
	assert_eq(_player().coins, coins - 10)
	assert_eq(EconomyInvariants.check(_sim.data, _sim.world), PackedStringArray())


func test_missing_inputs_idle_the_workshop_but_wages_are_paid() -> void:
	var workshop := _set_up(3)
	var coins := _player().coins
	WorkshopSystem.run_day(_sim.data, _sim.world)
	assert_eq(workshop.status, WorkshopState.Status.NO_INPUTS)
	assert_eq(workshop.missing_good, "grain")
	assert_eq(_kontor().cargo, {"grain": 3}, "nothing consumed")
	assert_eq(_player().coins, coins - 10)


func test_unpaid_workers_stay_home() -> void:
	var workshop := _set_up(8)
	_player().coins = 9
	WorkshopSystem.run_day(_sim.data, _sim.world)
	assert_eq(workshop.status, WorkshopState.Status.UNPAID)
	assert_eq(_player().coins, 9, "coins never go negative")
	assert_eq(_kontor().cargo, {"grain": 8})


func test_output_that_does_not_fit_idles_the_workshop() -> void:
	# A workshop making more than it consumes: 1 grain -> 5 wine.
	var inputs: Dictionary[String, int] = {"grain": 1}
	_sim.data.add_workshop(WorkshopDef.new("press", "Press", "wine", 5, inputs, 10, 100, 5))
	_sim.execute(BuyKontorCommand.new(PLAYER, "port"))
	SmallWorld.set_stock(_sim, "port", "grain", 40)
	assert_eq(_sim.execute(BuyCommand.for_kontor(PLAYER, "port", "grain", 18)), "")
	assert_eq(_sim.execute(BuildWorkshopCommand.new(PLAYER, "port", "press")), "")
	var workshop := _kontor().workshops[0]
	WorkshopSystem.run_day(_sim.data, _sim.world)
	assert_eq(workshop.status, WorkshopState.Status.KONTOR_FULL, "18 - 1 + 5 = 22 > 20")
	assert_eq(_kontor().cargo, {"grain": 18})
	assert_eq(EconomyInvariants.check(_sim.data, _sim.world), PackedStringArray())


func test_workshops_run_every_day_with_the_simulation() -> void:
	var workshop := _set_up(12)
	_sim.advance_days(4)
	assert_eq(workshop.status, WorkshopState.Status.NO_INPUTS, "grain ran out on day 4")
	assert_eq(_kontor().cargo, {"wine": 6})
	assert_eq(EconomyInvariants.check(_sim.data, _sim.world), PackedStringArray())


func test_invariants_catch_overfull_kontors_and_bad_progress() -> void:
	var workshop := _set_up(0)
	_kontor().cargo["grain"] = 21
	_sim.world.goods_ledger["grain"] += 21
	workshop.progress = CityEconomy.PARTS_PER_UNIT + 1
	var violations := EconomyInvariants.check(_sim.data, _sim.world)
	assert_eq(violations.size(), 2)
	assert_string_contains(violations[0], "kontor in port: holds 21, over capacity 20")
	assert_string_contains(violations[1], "workshop_1 progress 1000001 out of range")


func test_understaffed_workshops_work_slower_and_pay_less() -> void:
	var workshop := _set_up(20)
	_sim.data.population.min_factor = 0.1
	# The city shrinks to 600 people: a workforce of 60 for 30 jobs is still enough.
	var port := _sim.world.get_city("port")
	port.population = 600
	assert_eq(CityEconomy.staffing(_sim.data, _sim.world, port), CityEconomy.PARTS_PER_UNIT)
	# At 150 people the workforce is 15 for 30 jobs: half staffed.
	port.population = 150
	assert_eq(CityEconomy.staffing(_sim.data, _sim.world, port), 500_000)
	assert_eq(CityEconomy.free_workers(_sim.data, _sim.world, port), 0, "never negative")
	var coins := _player().coins
	var wine: Array[int] = []
	for day in 4:
		WorkshopSystem.run_day(_sim.data, _sim.world)
		wine.append(_kontor().cargo_of("wine"))
		assert_eq(workshop.status, WorkshopState.Status.WORKED)
	assert_eq(wine, [0, 2, 2, 4], "a full batch every other day")
	assert_eq(_kontor().cargo_of("grain"), 12)
	assert_eq(_player().coins, coins - 4 * 5, "half the wages of 10")
	assert_eq(EconomyInvariants.check(_sim.data, _sim.world), PackedStringArray())


func test_understaffed_wages_round_up() -> void:
	var vintner := _sim.data.get_workshop("vintner")
	assert_eq(WorkshopSystem.wages(vintner, CityEconomy.PARTS_PER_UNIT), 10)
	assert_eq(WorkshopSystem.wages(vintner, 333_333), 4)
	assert_eq(WorkshopSystem.wages(vintner, 0), 0)


func test_a_stalled_understaffed_workshop_does_not_bank_days() -> void:
	var workshop := _set_up(0)
	_sim.world.get_city("port").population = 150
	for day in 5:
		WorkshopSystem.run_day(_sim.data, _sim.world)
	assert_eq(workshop.status, WorkshopState.Status.NO_INPUTS)
	assert_eq(workshop.progress, CityEconomy.PARTS_PER_UNIT, "capped at one batch")
