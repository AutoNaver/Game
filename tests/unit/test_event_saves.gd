extends GutTest
## Saving world events and spoilage carries (save version 6, ADR 0011).

const SmallWorld := preload("res://tests/support/small_world.gd")
const PLAYER := WorldState.PLAYER_ID


## A world with a kontor in port holding grain, and a storm type in the data.
func _played_simulation() -> Simulation:
	var sim := SmallWorld.simulation(99)
	sim.world.player().coins = 5000
	assert_eq(sim.execute(BuyKontorCommand.new(PLAYER, "port")), "")
	assert_eq(sim.execute(BuyCommand.for_kontor(PLAYER, "port", "grain", 8)), "")
	assert_eq(sim.execute(BuyCommand.new(PLAYER, SmallWorld.SHIP_ID, "grain", 5)), "")
	var storm := EventDef.new("storm", "Storm", EventDef.STORM, 0.0, 1, 3)
	storm.slowdown = 2
	sim.data.add_event(storm)
	sim.advance_days(1)
	return sim


func _through_json(save: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(save)) as Dictionary


func _load(sim: Simulation, save: Dictionary) -> WorldState:
	var loader := SaveGame.new()
	var world := loader.from_dict(sim.data, save)
	assert_eq(Array(loader.errors), [])
	return world


func test_events_and_spoilage_carries_round_trip() -> void:
	var sim := _played_simulation()
	sim.world.events.append(EventState.new("event_1", "storm", "town", 2, 5))
	sim.world.next_event_number = 2
	sim.world.player().get_kontor("port").spoil_carry["grain"] = 300_000
	sim.world.player().ships[0].spoil_carry["grain"] = 7
	var saved := SaveGame.to_dict(sim.world)
	var world := _load(sim, _through_json(saved))
	assert_eq(_through_json(SaveGame.to_dict(world)), _through_json(saved))
	assert_eq(world.events[0].city_id, "town")
	assert_eq(world.player().get_kontor("port").spoil_carry["grain"], 300_000)


func test_version_5_saves_load_without_events_or_carries() -> void:
	var sim := _played_simulation()
	var save := _through_json(SaveGame.to_dict(sim.world))
	save["save_version"] = 5
	save.erase("events")
	save.erase("next_event_number")
	for ship: Dictionary in save["traders"][0]["ships"]:
		ship.erase("spoil_carry")
	var world := _load(sim, save)
	assert_eq(world.events.size(), 0)
	assert_eq(world.next_event_number, 1)


func test_bad_events_and_carries_are_rejected() -> void:
	var sim := _played_simulation()
	var save := _through_json(SaveGame.to_dict(sim.world))
	save["next_event_number"] = 2
	save["events"] = [
		{"id": "event_1", "type": "plague", "city": "riga", "start_day": 3, "end_day": 3},
	]
	save["traders"][0]["ships"][0]["spoil_carry"] = {"grain": 1_000_000, "amber": 5}
	var loader := SaveGame.new()
	assert_null(loader.from_dict(sim.data, save))
	assert_eq(
		Array(loader.errors),
		[
			"events[0]: unknown event type 'plague'",
			"events[0]: unknown city 'riga'",
			"events[0]: days 3 to 3 are not a span",
			"traders[0] ships[0] spoil_carry: grain 1000000 outside 1 to 999999",
			"traders[0] ships[0] spoil_carry: unknown good 'amber'",
		]
	)
