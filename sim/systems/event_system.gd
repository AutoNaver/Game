class_name EventSystem
extends RefCounted
## Starts, ends and applies world events (data/events.json, ADR 0011).
##
## Runs first each day: events that are over are dropped, then every event type in data order
## draws once from the world RNG whether it starts today; if so, it picks one eligible city and a
## duration from the same RNG, so the same seed gives the same events. A fire burns its share of
## the kontor stock in its city at once, booked in the goods ledger as a loss. The other kinds act
## through the queries below, which the systems they affect call.


static func run_day(data: GameData, world: WorldState, day: int) -> void:
	var running: Array[EventState] = []
	for event in world.events:
		if event.end_day > day:
			running.append(event)
	world.events = running
	for event_type in data.events:
		# Always draw, even when nothing is eligible, so one city's state can't shift later draws.
		var roll := world.rng.randf()
		if roll >= event_type.chance_per_day:
			continue
		var cities := eligible_cities(data, world, event_type, day)
		var duration := world.rng.randi_range(event_type.min_days, event_type.max_days)
		if cities.is_empty():
			continue
		var city_id := cities[world.rng.randi_range(0, cities.size() - 1)]
		var id := "event_%d" % world.next_event_number
		world.next_event_number += 1
		var event := EventState.new(id, event_type.id, city_id, day, day + duration)
		world.events.append(event)
		if event_type.kind == EventDef.FIRE:
			_burn(data, world, event_type, city_id)


## Cities `event_type` can start in today: not already hit by the same type, and able to feel it
## (a harvest failure needs a city producing one of its goods, a fire a kontor with goods).
static func eligible_cities(
	data: GameData, world: WorldState, event_type: EventDef, day: int
) -> PackedStringArray:
	var cities := PackedStringArray()
	for city in data.cities:
		if _has_event(world, city.id, event_type.id, day):
			continue
		match event_type.kind:
			EventDef.HARVEST_FAILURE:
				var grows := false
				for good_id in event_type.goods:
					grows = grows or city.production_of(good_id) > 0.0
				if not grows:
					continue
			EventDef.FIRE:
				if not _has_stored_goods(world, city.id):
					continue
		cities.append(city.id)
	return cities


## Events in effect in `city_id` today, in start order.
static func active_in(world: WorldState, city_id: String, day: int) -> Array[EventState]:
	var found: Array[EventState] = []
	for event in world.events:
		if event.city_id == city_id and event.is_active(day):
			found.append(event)
	return found


## Share of the city's own production of `good_id` left today, in 1/RATE_STEPS steps.
static func production_steps(
	data: GameData, world: WorldState, city_id: String, good_id: String
) -> int:
	var steps := CityEconomy.RATE_STEPS
	for event in active_in(world, city_id, _day(world)):
		var event_type := data.get_event(event.type_id)
		if event_type.kind == EventDef.HARVEST_FAILURE and event_type.goods.has(good_id):
			steps = mini(steps, CityEconomy.rate_steps(event_type.factor))
	return steps


## Share of the city's off-map imports left today, in 1/RATE_STEPS steps.
static func import_steps(data: GameData, world: WorldState, city_id: String) -> int:
	var steps := CityEconomy.RATE_STEPS
	for event in active_in(world, city_id, _day(world)):
		var event_type := data.get_event(event.type_id)
		if event_type.kind == EventDef.WAR:
			steps = mini(steps, CityEconomy.rate_steps(event_type.factor))
	return steps


## Ships sailing to or from a storm-hit city advance one hour of their voyage every this many
## hours (1 without a storm).
static func slowdown(data: GameData, world: WorldState, ship: ShipState) -> int:
	var slowest := 1
	var day := _day(world)
	for city_id: String in [ship.origin, ship.destination]:
		for event in active_in(world, city_id, day):
			var event_type := data.get_event(event.type_id)
			if event_type.kind == EventDef.STORM:
				slowest = maxi(slowest, event_type.slowdown)
	return slowest


static func _burn(data: GameData, world: WorldState, event_type: EventDef, city_id: String) -> void:
	var share := CityEconomy.rate_steps(event_type.loss_share)
	for trader in world.traders:
		var kontor := trader.get_kontor(city_id)
		if kontor == null:
			continue
		for good in data.goods:
			@warning_ignore("integer_division")
			var lost := kontor.cargo_of(good.id) * share / CityEconomy.RATE_STEPS
			if lost <= 0:
				continue
			kontor.change_cargo(good.id, -lost)
			world.goods_ledger[good.id] -= lost
			world.losses.append(GoodsLoss.new(trader.id, city_id, good.id, lost, event_type.id))


static func _has_event(world: WorldState, city_id: String, type_id: String, day: int) -> bool:
	for event in active_in(world, city_id, day):
		if event.type_id == type_id:
			return true
	return false


static func _has_stored_goods(world: WorldState, city_id: String) -> bool:
	for trader in world.traders:
		var kontor := trader.get_kontor(city_id)
		if kontor != null and kontor.cargo_total() > 0:
			return true
	return false


## The day the events are evaluated for. During an hour's movement this is the day that hour
## belongs to; the daily systems run at the first hour of a new day, matching EventSystem.run_day.
static func _day(world: WorldState) -> int:
	@warning_ignore("integer_division")
	return world.hour / Simulation.HOURS_PER_DAY
