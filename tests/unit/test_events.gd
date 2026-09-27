extends GutTest
## World events (EventSystem, ADR 0011): when they start and end, and what each kind does.

const SmallWorld := preload("res://tests/support/small_world.gd")
const PLAYER := WorldState.PLAYER_ID

var _sim: Simulation


func before_each() -> void:
	_sim = SmallWorld.simulation()


func _add_event(id: String, kind: String, chance: float, days: int) -> EventDef:
	var event := EventDef.new(id, id.capitalize(), kind, chance, days, days)
	_sim.data.add_event(event)
	return event


## Puts an event of type `type_id` in `city_id` from today for `days` days.
func _start(type_id: String, city_id: String, days: int) -> void:
	var day := _sim.day()
	var id := "event_%d" % _sim.world.next_event_number
	_sim.world.next_event_number += 1
	_sim.world.events.append(EventState.new(id, type_id, city_id, day, day + days))


func test_events_start_in_eligible_cities_and_end_after_their_duration() -> void:
	var storm := _add_event("storm", EventDef.STORM, 1.0, 2)
	storm.slowdown = 2
	EventSystem.run_day(_sim.data, _sim.world, 0)
	assert_eq(_sim.world.events.size(), 1)
	var first := _sim.world.events[0]
	assert_eq([first.id, first.type_id, first.start_day, first.end_day], ["event_1", "storm", 0, 2])
	EventSystem.run_day(_sim.data, _sim.world, 1)
	assert_eq(_sim.world.events.size(), 2, "the other city: one storm per city at a time")
	assert_ne(_sim.world.events[1].city_id, first.city_id)
	EventSystem.run_day(_sim.data, _sim.world, 2)
	assert_eq(_sim.world.events.size(), 2, "the first storm ended and a new one began")
	assert_eq(_sim.world.events[0].id, "event_2")
	assert_eq(_sim.world.events[1].id, "event_3")
	assert_eq(_sim.world.next_event_number, 4)


func test_events_that_never_roll_never_start() -> void:
	_add_event("war", EventDef.WAR, 0.0, 10)
	for day in 50:
		EventSystem.run_day(_sim.data, _sim.world, day)
	assert_eq(_sim.world.events.size(), 0)


func test_harvest_failures_only_hit_cities_that_grow_the_goods() -> void:
	var blight := _add_event("blight", EventDef.HARVEST_FAILURE, 1.0, 5)
	blight.goods = ["grain"]
	blight.factor = 0.5
	assert_eq(Array(EventSystem.eligible_cities(_sim.data, _sim.world, blight, 0)), ["port"])


func test_a_harvest_failure_cuts_production() -> void:
	var blight := _add_event("blight", EventDef.HARVEST_FAILURE, 0.0, 20)
	blight.goods = ["grain"]
	blight.factor = 0.5
	_start("blight", "port", 20)
	SmallWorld.set_stock(_sim, "port", "grain", 0)
	for day in 4:
		ProductionSystem.run_day(_sim.data, _sim.world)
	# 1.5 a day halved: 0.75 a day, 3 in four days.
	assert_eq(_sim.world.get_city("port").stock["grain"], 3)
	assert_eq(EventSystem.production_steps(_sim.data, _sim.world, "port", "wine"), 1000)


func test_war_cuts_off_map_imports() -> void:
	_sim.data.economy.import_rate = 1.0
	var war := _add_event("war", EventDef.WAR, 0.0, 20)
	war.factor = 0.0
	SmallWorld.set_stock(_sim, "town", "grain", 0)
	OffMapTradeSystem.run_day(_sim.data, _sim.world)
	assert_gt(_sim.world.get_city("town").stock["grain"], 0, "imports without a war")
	SmallWorld.set_stock(_sim, "town", "grain", 0)
	_start("war", "town", 20)
	OffMapTradeSystem.run_day(_sim.data, _sim.world)
	assert_eq(_sim.world.get_city("town").stock["grain"], 0)
	assert_eq(EconomyInvariants.check(_sim.data, _sim.world), PackedStringArray())


func test_storms_slow_ships_sailing_to_or_from_the_city() -> void:
	var storm := _add_event("storm", EventDef.STORM, 0.0, 5)
	storm.slowdown = 2
	_start("storm", "town", 5)
	var ship := _sim.world.player().ships[0]
	assert_eq(_sim.execute(SailCommand.new(PLAYER, ship.id, "town")), "")
	for hour in 19:
		_sim.tick()
	assert_false(ship.is_docked(), "10 hours of sailing take 20 in the storm")
	_sim.tick()
	assert_eq(ship.docked_at, "town")


func test_fires_burn_a_share_of_kontor_stock_as_a_booked_loss() -> void:
	var fire := _add_event("fire", EventDef.FIRE, 1.0, 3)
	fire.loss_share = 0.25
	assert_eq(
		Array(EventSystem.eligible_cities(_sim.data, _sim.world, fire, 0)), [], "no stored goods"
	)
	_sim.world.player().coins = 5000
	assert_eq(_sim.execute(BuyKontorCommand.new(PLAYER, "port")), "")
	assert_eq(_sim.execute(BuyCommand.for_kontor(PLAYER, "port", "grain", 18)), "")
	EventSystem.run_day(_sim.data, _sim.world, 0)
	assert_eq(_sim.world.events[0].city_id, "port")
	assert_eq(_sim.world.player().get_kontor("port").cargo_of("grain"), 14, "a quarter of 18, down")
	var loss := _sim.world.losses[0]
	assert_eq([loss.hold_id, loss.good_id, loss.units, loss.cause], ["port", "grain", 4, "fire"])
	assert_eq(EconomyInvariants.check(_sim.data, _sim.world), PackedStringArray())
	EventSystem.run_day(_sim.data, _sim.world, 1)
	assert_eq(_sim.world.player().get_kontor("port").cargo_of("grain"), 14, "burns once")


func test_same_seed_gives_the_same_events() -> void:
	var worlds: Array[Simulation] = []
	for i in 2:
		var sim := SmallWorld.simulation(5)
		var storm := EventDef.new("storm", "Storm", EventDef.STORM, 0.3, 1, 4)
		storm.slowdown = 2
		sim.data.add_event(storm)
		sim.advance_days(30)
		worlds.append(sim)
	assert_eq(SaveGame.to_dict(worlds[0].world), SaveGame.to_dict(worlds[1].world))
	assert_gt(worlds[0].world.next_event_number, 1, "some storms happened")
