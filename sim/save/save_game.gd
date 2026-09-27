class_name SaveGame
extends RefCounted
## Converts a WorldState to and from a JSON-compatible dictionary, and reads/writes save files.
##
## Saves store state only; definitions come from the loaded GameData and are referenced by id.
## Loading validates every id and number and then runs EconomyInvariants, so a damaged or
## outdated save is rejected with messages instead of producing a broken world.
##
## RNG seed and state are 64-bit and stored as strings: JSON numbers are doubles and would lose
## precision.

## Bump on every change to the saved shape, with a migration in from_dict() or an explicit
## decision to reject older saves.
const SAVE_VERSION: int = 1
const SAVE_DIR: String = "user://saves"

## Problems found by the last from_dict() / load_file() call.
var errors: PackedStringArray = []


static func to_dict(world: WorldState) -> Dictionary:
	var cities: Array = []
	for city in world.cities:
		(
			cities
			. append(
				{
					"id": city.id,
					"population": city.population,
					"stock": city.stock.duplicate(),
					"production_carry": city.production_carry.duplicate(),
					"consumption_carry": city.consumption_carry.duplicate(),
					"trade_carry": city.trade_carry.duplicate(),
					"shortage": city.shortage.duplicate(),
				}
			)
		)
	var traders: Array = []
	for trader in world.traders:
		traders.append(_trader_to_dict(trader))
	return {
		"save_version": SAVE_VERSION,
		"hour": world.hour,
		"rng_seed": str(world.rng.seed),
		"rng_state": str(world.rng.state),
		"next_ship_number": world.next_ship_number,
		"next_workshop_number": world.next_workshop_number,
		"goods_ledger": world.goods_ledger.duplicate(),
		"cities": cities,
		"traders": traders,
	}


static func path_for(slot: String) -> String:
	return SAVE_DIR.path_join("%s.json" % slot)


## Writes the world to `path` as JSON. Returns "" or an error message.
static func save_file(world: WorldState, path: String) -> String:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return "could not write %s (%s)" % [path, error_string(FileAccess.get_open_error())]
	file.store_string(JSON.stringify(to_dict(world), "\t"))
	file.close()
	return ""


## Reads and validates a save file. Returns null and fills `errors` if anything is wrong.
func load_file(data: GameData, path: String) -> WorldState:
	errors.clear()
	if not FileAccess.file_exists(path):
		errors.append("no save at %s" % path)
		return null
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		var line := json.get_error_line() + 1
		errors.append("save is not valid JSON (line %d: %s)" % [line, json.get_error_message()])
		return null
	if not json.data is Dictionary:
		errors.append("save must be a JSON object")
		return null
	return from_dict(data, json.data as Dictionary)


## Rebuilds a world from to_dict() output (possibly after a JSON round trip).
## Returns null and fills `errors` if the save doesn't fit `data` or breaks an invariant.
func from_dict(data: GameData, save: Dictionary) -> WorldState:
	errors.clear()
	var version := _int(save, "save_version", "save")
	if errors.is_empty() and version != SAVE_VERSION:
		errors.append("save version %d is not supported (expected %d)" % [version, SAVE_VERSION])
		return null
	var world := WorldState.new()
	world.hour = _int(save, "hour", "save")
	var rng_seed := _int_string(save, "rng_seed", "save")
	var rng_state := _int_string(save, "rng_state", "save")
	world.rng.seed = rng_seed
	world.rng.state = rng_state
	world.next_ship_number = _int(save, "next_ship_number", "save")
	world.next_workshop_number = _int(save, "next_workshop_number", "save")
	world.goods_ledger = _goods(data, _dict(save, "goods_ledger", "save"), "goods_ledger", true)
	_read_cities(data, world, _array(save, "cities", "save"))
	for i in _array(save, "traders", "save").size():
		var trader := _read_trader(data, save["traders"][i], "traders[%d]" % i)
		if trader != null:
			world.traders.append(trader)
	if errors.is_empty() and world.player() == null:
		errors.append("save has no player")
	_check_unique_ids(world)
	if errors.is_empty():
		errors.append_array(EconomyInvariants.check(data, world))
	return world if errors.is_empty() else null


## Ship and workshop ids must be unique across all traders, and below the next free number.
func _check_unique_ids(world: WorldState) -> void:
	var seen: Dictionary[String, bool] = {}
	for trader in world.traders:
		for ship in trader.ships:
			if seen.has(ship.id):
				errors.append("duplicate ship id '%s'" % ship.id)
			seen[ship.id] = true
		for kontor: KontorState in trader.kontors.values():
			for workshop in kontor.workshops:
				if seen.has(workshop.id):
					errors.append("duplicate workshop id '%s'" % workshop.id)
				seen[workshop.id] = true
	for id: String in seen:
		var number := id.get_slice("_", id.get_slice_count("_") - 1).to_int()
		var next := (
			world.next_ship_number if id.begins_with("ship_") else world.next_workshop_number
		)
		if number >= next:
			errors.append("id '%s' is not below the next free number %d" % [id, next])


static func _trader_to_dict(trader: TraderState) -> Dictionary:
	var ships: Array = []
	for ship in trader.ships:
		(
			ships
			. append(
				{
					"id": ship.id,
					"type": ship.type_id,
					"name": ship.name,
					"cargo": ship.cargo.duplicate(),
					"docked_at": ship.docked_at,
					"origin": ship.origin,
					"destination": ship.destination,
					"voyage_hours": ship.voyage_hours,
					"hours_sailed": ship.hours_sailed,
				}
			)
		)
	var kontors: Array = []
	for city_id: String in trader.kontors.keys():
		var kontor: KontorState = trader.kontors[city_id]
		var workshops: Array = []
		for workshop in kontor.workshops:
			(
				workshops
				. append(
					{
						"id": workshop.id,
						"type": workshop.type_id,
						"status": WorkshopState.Status.keys()[workshop.status],
						"missing_good": workshop.missing_good,
					}
				)
			)
		kontors.append(
			{"city": kontor.city_id, "cargo": kontor.cargo.duplicate(), "workshops": workshops}
		)
	kontors.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["city"] < b["city"])
	return {
		"id": trader.id,
		"name": trader.name,
		"coins": trader.coins,
		"ships": ships,
		"kontors": kontors,
	}


func _read_cities(data: GameData, world: WorldState, cities: Array) -> void:
	if cities.size() != data.cities.size():
		errors.append("save has %d cities, the game has %d" % [cities.size(), data.cities.size()])
		return
	for i in cities.size():
		var ctx := "cities[%d]" % i
		if not cities[i] is Dictionary:
			errors.append("%s: must be an object" % ctx)
			continue
		var raw: Dictionary = cities[i]
		var id := _string(raw, "id", ctx)
		if id != data.cities[i].id:
			errors.append("%s: expected city '%s', got '%s'" % [ctx, data.cities[i].id, id])
			continue
		var city := CityState.new(id, _int(raw, "population", ctx))
		city.stock = _goods(data, _dict(raw, "stock", ctx), "%s stock" % ctx, true)
		city.production_carry = _goods(
			data, _dict(raw, "production_carry", ctx), "%s production_carry" % ctx, true
		)
		city.consumption_carry = _goods(
			data, _dict(raw, "consumption_carry", ctx), "%s consumption_carry" % ctx, true
		)
		city.trade_carry = _goods(
			data, _dict(raw, "trade_carry", ctx), "%s trade_carry" % ctx, true
		)
		city.shortage = _goods(data, _dict(raw, "shortage", ctx), "%s shortage" % ctx, true)
		world.add_city(city)


func _read_trader(data: GameData, raw_value: Variant, ctx: String) -> TraderState:
	if not raw_value is Dictionary:
		errors.append("%s: must be an object" % ctx)
		return null
	var raw: Dictionary = raw_value
	var trader := TraderState.new(
		_string(raw, "id", ctx), _string(raw, "name", ctx), _int(raw, "coins", ctx)
	)
	var ships := _array(raw, "ships", ctx)
	for i in ships.size():
		var ship := _read_ship(data, ships[i], "%s ships[%d]" % [ctx, i])
		if ship != null:
			trader.ships.append(ship)
	var kontors := _array(raw, "kontors", ctx)
	for i in kontors.size():
		var kontor := _read_kontor(data, kontors[i], "%s kontors[%d]" % [ctx, i])
		if kontor == null:
			continue
		if trader.kontors.has(kontor.city_id):
			errors.append("%s kontors[%d]: second kontor in %s" % [ctx, i, kontor.city_id])
		trader.kontors[kontor.city_id] = kontor
	return trader


func _read_ship(data: GameData, raw_value: Variant, ctx: String) -> ShipState:
	if not raw_value is Dictionary:
		errors.append("%s: must be an object" % ctx)
		return null
	var raw: Dictionary = raw_value
	var type_id := _string(raw, "type", ctx)
	if not data.has_ship(type_id):
		errors.append("%s: unknown ship type '%s'" % [ctx, type_id])
	var ship := ShipState.new(
		_string(raw, "id", ctx), type_id, _string(raw, "name", ctx), _string(raw, "docked_at", ctx)
	)
	ship.cargo = _goods(data, _dict(raw, "cargo", ctx), "%s cargo" % ctx, false)
	ship.origin = _string(raw, "origin", ctx)
	ship.destination = _string(raw, "destination", ctx)
	ship.voyage_hours = _int(raw, "voyage_hours", ctx)
	ship.hours_sailed = _int(raw, "hours_sailed", ctx)
	return ship


func _read_kontor(data: GameData, raw_value: Variant, ctx: String) -> KontorState:
	if not raw_value is Dictionary:
		errors.append("%s: must be an object" % ctx)
		return null
	var raw: Dictionary = raw_value
	var kontor := KontorState.new(_string(raw, "city", ctx))
	kontor.cargo = _goods(data, _dict(raw, "cargo", ctx), "%s cargo" % ctx, false)
	var workshops := _array(raw, "workshops", ctx)
	for i in workshops.size():
		var workshop_ctx := "%s workshops[%d]" % [ctx, i]
		if not workshops[i] is Dictionary:
			errors.append("%s: must be an object" % workshop_ctx)
			continue
		var entry: Dictionary = workshops[i]
		var type_id := _string(entry, "type", workshop_ctx)
		if not data.has_workshop(type_id):
			errors.append("%s: unknown workshop type '%s'" % [workshop_ctx, type_id])
		var workshop := WorkshopState.new(_string(entry, "id", workshop_ctx), type_id)
		var status := _string(entry, "status", workshop_ctx)
		if not WorkshopState.Status.has(status):
			errors.append("%s: unknown status '%s'" % [workshop_ctx, status])
		else:
			workshop.status = WorkshopState.Status[status] as WorkshopState.Status
		workshop.missing_good = _string(entry, "missing_good", workshop_ctx)
		kontor.workshops.append(workshop)
	return kontor


## A per-good table of whole numbers. With `complete`, every good must be present (cities and the
## ledger); otherwise only known goods with positive amounts may appear (cargo).
func _goods(
	data: GameData, raw: Dictionary, ctx: String, complete: bool
) -> Dictionary[String, int]:
	var table: Dictionary[String, int] = {}
	for key: Variant in raw.keys():
		var good_id := str(key)
		if not data.has_good(good_id):
			errors.append("%s: unknown good '%s'" % [ctx, good_id])
			continue
		var amount := _int(raw, good_id, ctx)
		if not complete and amount <= 0:
			errors.append("%s: %s must be positive" % [ctx, good_id])
			continue
		table[good_id] = amount
	if complete:
		for good in data.goods:
			if not table.has(good.id):
				errors.append("%s: missing %s" % [ctx, good.id])
	return table


func _int(raw: Dictionary, field: String, ctx: String) -> int:
	var value: Variant = raw.get(field)
	if (value is int or value is float) and float(value) == floorf(float(value)):
		if absf(float(value)) < 9.0e15:
			return int(value)
	errors.append("%s: '%s' must be a whole number" % [ctx, field])
	return 0


func _int_string(raw: Dictionary, field: String, ctx: String) -> int:
	var value: Variant = raw.get(field)
	if value is String and (value as String).is_valid_int():
		return (value as String).to_int()
	errors.append("%s: '%s' must be a whole number in a string" % [ctx, field])
	return 0


func _string(raw: Dictionary, field: String, ctx: String) -> String:
	var value: Variant = raw.get(field)
	if value is String:
		return value as String
	errors.append("%s: '%s' must be a string" % [ctx, field])
	return ""


func _dict(raw: Dictionary, field: String, ctx: String) -> Dictionary:
	var value: Variant = raw.get(field)
	if value is Dictionary:
		return value as Dictionary
	errors.append("%s: '%s' must be an object" % [ctx, field])
	return {}


func _array(raw: Dictionary, field: String, ctx: String) -> Array:
	var value: Variant = raw.get(field)
	if value is Array:
		return value as Array
	errors.append("%s: '%s' must be an array" % [ctx, field])
	return []
