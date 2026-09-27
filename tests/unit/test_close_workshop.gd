extends GutTest
## CloseWorkshopCommand: closing a workshop frees its workers and stops its wages, without a refund.

const SmallWorld := preload("res://tests/support/small_world.gd")
const PLAYER := WorldState.PLAYER_ID

var _sim: Simulation


func before_each() -> void:
	_sim = SmallWorld.simulation()
	_sim.world.player().coins = 5000
	assert_eq(_sim.execute(BuyKontorCommand.new(PLAYER, "port")), "")
	assert_eq(_sim.execute(BuildWorkshopCommand.new(PLAYER, "port", "vintner")), "")


func test_closing_frees_the_workers_and_stops_the_wages() -> void:
	var port := _sim.world.get_city("port")
	assert_eq(CityEconomy.free_workers(_sim.data, _sim.world, port), 70)
	var coins := _sim.world.player().coins
	assert_eq(_sim.execute(CloseWorkshopCommand.new(PLAYER, "port", "workshop_1")), "")
	assert_eq(_sim.world.player().get_kontor("port").workshops.size(), 0)
	assert_eq(CityEconomy.free_workers(_sim.data, _sim.world, port), 100)
	assert_eq(_sim.world.player().coins, coins, "no refund")
	_sim.advance_days(1)
	assert_eq(_sim.world.player().coins, coins - _sim.data.captains.daily_wage, "crew only")


func test_closing_is_validated() -> void:
	assert_eq(
		_sim.execute(CloseWorkshopCommand.new(PLAYER, "town", "workshop_1")),
		"You have no kontor in Town"
	)
	assert_eq(
		_sim.execute(CloseWorkshopCommand.new(PLAYER, "port", "workshop_9")),
		"unknown workshop 'workshop_9'"
	)
	assert_eq(
		_sim.execute(CloseWorkshopCommand.new("nobody", "port", "workshop_1")),
		"unknown trader 'nobody'"
	)
	assert_eq(_sim.world.player().get_kontor("port").workshops.size(), 1)
