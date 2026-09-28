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
## Version 2 added cities' price_history; version 1 saves load with an empty history.
## Version 3 added trade routes (traders' routes, ships' route fields, next_route_number); older
## saves load without routes.
## Version 4 added the rival houses (ADR 0008). Their shape is an ordinary trader's; older saves
## get every rival added as it starts a new game.
## Version 5 added cities' satisfaction, and population may differ from data/cities.json within
## the bounds of data/population.json (ADR 0010), and workshops' batch progress (understaffed
## workshops work slower); older saves load at neutral satisfaction and no progress.
## Version 6 added world events, next_event_number and ships' and kontors' spoil_carry (ADR 0011);
## older saves load with no events and no spoilage carried.
## Version 7 marks the larger world of M11 (ADR 0012); the shape is unchanged. Cities, goods and
## rival houses carry the version that first has them ("since_save" in the data). A save must hold
## every city and good of its own version's world and is refused otherwise; the newer ones are
## added as a new game starts them (newer cities come after the older ones in data order).
## Version 8 added a market book per trader and ships' departure reports (ADR 0013). Older saves
## begin with current reports for every city, then learn only where each trader has presence.
## Version 9 added captains, taverns, the player's location and house debt (ADR 0014). Older
## saves give every ship a captain and put the player aboard their first ship.
## Version 10 added each house's rank and reputation per city, and kontors' factor orders
## (ADR 0015). Older saves start without reputation or orders and at the rank their worth earns.
## Version 11 added rivals' offers to the player and next_offer_number, and a bankrupt rival's
## sale_end_day (ADR 0016). Older saves have no offers and never hold a bankrupt rival.
const SAVE_VERSION: int = 11
const OLDEST_SUPPORTED_VERSION: int = 1
const SAVE_DIR: String = "user://saves"
## Longest slot name the player can type.
const MAX_SLOT_NAME: int = 32
## Characters above this are non-ASCII letters and symbols, all safe in file names.
const ASCII_MAX: int = 127

## Problems found by the last from_dict() / load_file() call.
var errors: PackedStringArray = []

## Goods the save being read must hold: those whose since_save is at most its version (the rest
## are added as in a new game).
var _save_goods: PackedStringArray = []


static func to_dict(world: WorldState) -> Dictionary:
	var cities: Array = []
	for city in world.cities:
		(
			cities
			. append(
				{
					"id": city.id,
					"population": city.population,
					"satisfaction": city.satisfaction,
					"stock": city.stock.duplicate(),
					"production_carry": city.production_carry.duplicate(),
					"consumption_carry": city.consumption_carry.duplicate(),
					"trade_carry": city.trade_carry.duplicate(),
					"shortage": city.shortage.duplicate(),
					"price_history": _history_to_dict(city),
				}
			)
		)
	var traders: Array = []
	for trader in world.traders:
		traders.append(SaveWriter.trader_to_dict(trader, world.cities))
	var events: Array = []
	for event in world.events:
		(
			events
			. append(
				{
					"id": event.id,
					"type": event.type_id,
					"city": event.city_id,
					"start_day": event.start_day,
					"end_day": event.end_day,
				}
			)
		)
	var taverns: Array = []
	for city in world.cities:
		var pool: Array = world.taverns.get(city.id, [])
		var candidates: Array = []
		for captain: CaptainState in pool:
			candidates.append(SaveWriter.captain_to_dict(captain))
		taverns.append({"city": city.id, "captains": candidates})
	return {
		"save_version": SAVE_VERSION,
		"hour": world.hour,
		"rng_seed": str(world.rng.seed),
		"rng_state": str(world.rng.state),
		"next_ship_number": world.next_ship_number,
		"next_captain_number": world.next_captain_number,
		"taverns": taverns,
		"next_workshop_number": world.next_workshop_number,
		"next_route_number": world.next_route_number,
		"next_event_number": world.next_event_number,
		"next_offer_number": world.next_offer_number,
		"offers": SaveWriter.offers_to_dict(world),
		"events": events,
		"goods_ledger": world.goods_ledger.duplicate(),
		"cities": cities,
		"traders": traders,
	}


static func path_for(slot: String, dir: String = SAVE_DIR) -> String:
	return dir.path_join("%s.json" % slot)


## Slot names are what the player types: letters (including non-ASCII ones such as "ü"), digits,
## spaces, "-" and "_", so they are also safe file names. Returns "" or why the name can't be used.
static func check_slot_name(slot: String) -> String:
	if slot.strip_edges().is_empty():
		return "Enter a name for the save"
	if slot.length() > MAX_SLOT_NAME:
		return "Save names can be at most %d characters" % MAX_SLOT_NAME
	for character in slot:
		var code := character.unicode_at(0)
		var ascii_ok := character.is_valid_identifier() or character.is_valid_int()
		if not (ascii_ok or character in " -" or code > ASCII_MAX):
			return "Save names can only use letters, digits, spaces, - and _"
	if slot != slot.strip_edges():
		return "Save names can't start or end with a space"
	return ""


## Names of the saves in `dir`, sorted.
static func list_slots(dir: String = SAVE_DIR) -> PackedStringArray:
	var slots: PackedStringArray = []
	if not DirAccess.dir_exists_absolute(dir):
		return slots
	for file_name in DirAccess.get_files_at(dir):
		if file_name.get_extension() == "json":
			slots.append(file_name.get_basename())
	slots.sort()
	return slots


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
	if errors.is_empty() and (version < OLDEST_SUPPORTED_VERSION or version > SAVE_VERSION):
		var versions := [version, OLDEST_SUPPORTED_VERSION, SAVE_VERSION]
		errors.append("save version %d is not supported (expected %d to %d)" % versions)
		return null
	var world := WorldState.new()
	world.hour = _int(save, "hour", "save")
	var rng_seed := _int_string(save, "rng_seed", "save")
	var rng_state := _int_string(save, "rng_state", "save")
	world.rng.seed = rng_seed
	world.rng.state = rng_state
	world.next_ship_number = _int(save, "next_ship_number", "save")
	if version >= 9:
		world.next_captain_number = _int(save, "next_captain_number", "save")
	world.next_workshop_number = _int(save, "next_workshop_number", "save")
	if version >= 3:
		world.next_route_number = _int(save, "next_route_number", "save")
	if version >= 6:
		world.next_event_number = _int(save, "next_event_number", "save")
		var events := _array(save, "events", "save")
		for i in events.size():
			var event := _read_event(data, events[i], "events[%d]" % i)
			if event != null:
				world.events.append(event)
	_save_goods.clear()
	for good in data.goods:
		if good.since_save <= version:
			_save_goods.append(good.id)
	world.goods_ledger = _goods(data, _dict(save, "goods_ledger", "save"), "goods_ledger", true)
	_read_cities(data, world, _array(save, "cities", "save"), version)
	if errors.is_empty():
		_grow_world(data, world)
	@warning_ignore("integer_division")
	var current_day := world.hour / Simulation.HOURS_PER_DAY
	for i in _array(save, "traders", "save").size():
		var trader := _read_trader(
			data, save["traders"][i], "traders[%d]" % i, version, current_day
		)
		if trader != null:
			world.traders.append(trader)
	if errors.is_empty() and world.player() == null:
		errors.append("save has no player")
	for trader in world.traders:
		if trader.id != WorldState.PLAYER_ID and not data.has_rival(trader.id):
			errors.append("unknown trader '%s' (neither the player nor a rival house)" % trader.id)
	# Houses newer than the save join as they start; before version 4 there were no houses in
	# saves at all. A house the save's own world had but the save lacks is not revived.
	if errors.is_empty():
		for rival in data.rivals:
			var newer := version < 4 or rival.since_save > version
			if newer and world.get_trader(rival.id) == null:
				Simulation.add_rival(world, rival)
	if version >= 9:
		_read_taverns(data, world, _array(save, "taverns", "save"))
	elif errors.is_empty():
		var player := world.player()
		if player != null:
			player.person_ship_id = player.ships[0].id if not player.ships.is_empty() else ""
			player.person_city_id = data.scenario.start_city if player.ships.is_empty() else ""
		CaptainSystem.crew_starting_ships(data, world)
	if version < 8 and errors.is_empty():
		_migrate_market_books(data, world)
	if version < 10 and errors.is_empty():
		RankSystem.run_day(data, world)
	if version >= 11:
		world.next_offer_number = _int(save, "next_offer_number", "save")
		_read_offers(data, world, _array(save, "offers", "save"))
	_check_unique_ids(data, world)
	if errors.is_empty():
		_check_trader_order(data, world)
	if version >= 8 and errors.is_empty():
		for trader in world.traders:
			for city in data.cities:
				if MarketKnowledgeSystem.has_presence(data, trader, city.id):
					var report: MarketRecord = trader.market_book.get(city.id)
					if report == null or report.day != current_day:
						errors.append("%s needs a current report for %s" % [trader.id, city.id])
	if errors.is_empty():
		errors.append_array(EconomyInvariants.check(data, world))
	return world if errors.is_empty() else null


## Trader ids must be unique. Ship, workshop, route and event ids must be unique across the world,
## of the form the game creates ("ship_3"), and below the next free number of their kind.
func _check_unique_ids(data: GameData, world: WorldState) -> void:
	var trader_ids: Dictionary[String, bool] = {}
	for trader in world.traders:
		if trader_ids.has(trader.id):
			errors.append("duplicate trader id '%s'" % trader.id)
		trader_ids[trader.id] = true
	# Id -> the kind it must be, in a stable order (traders, then ships, workshops and routes).
	var seen: Dictionary[String, String] = {}
	for trader in world.traders:
		for ship in trader.ships:
			_see_id(seen, ship.id, "ship")
		for captain in trader.captains:
			_see_id(seen, captain.id, "captain")
		for kontor in trader.kontors_in_order(data.cities):
			for workshop in kontor.workshops:
				_see_id(seen, workshop.id, "workshop")
		for route in trader.routes:
			_see_id(seen, route.id, "route")
	for event in world.events:
		_see_id(seen, event.id, "event")
	for offer in world.offers:
		_see_id(seen, offer.id, "offer")
	for city in data.cities:
		var pool: Array = world.taverns.get(city.id, [])
		for captain: CaptainState in pool:
			_see_id(seen, captain.id, "captain")
	var next_numbers: Dictionary[String, int] = {
		"ship": world.next_ship_number,
		"captain": world.next_captain_number,
		"workshop": world.next_workshop_number,
		"route": world.next_route_number,
		"event": world.next_event_number,
		"offer": world.next_offer_number,
	}
	for id: String in seen:
		var kind := seen[id]
		# Ids end up in UI node names and paths, so only the exact shape the game creates is allowed.
		var number_text := id.trim_prefix(kind + "_")
		var number := number_text.to_int()
		if not id.begins_with(kind + "_") or number < 1 or number_text != str(number):
			errors.append("%s id '%s' is not of the form %s_<number>" % [kind, id, kind])
		elif number >= next_numbers[kind]:
			errors.append("id '%s' is not below the next free number %d" % [id, next_numbers[kind]])


## The player comes first, then the rival houses in data order (WorldState.traders). The systems
## act in that order every hour and day, so a reordered save would play out differently.
func _check_trader_order(data: GameData, world: WorldState) -> void:
	var expected := PackedStringArray([WorldState.PLAYER_ID])
	for rival in data.rivals:
		if world.get_trader(rival.id) != null:
			expected.append(rival.id)
	var actual := PackedStringArray()
	for trader in world.traders:
		actual.append(trader.id)
	if actual != expected:
		var order := [", ".join(expected), ", ".join(actual)]
		errors.append("traders must be in the order %s (got %s)" % order)


func _see_id(seen: Dictionary[String, String], id: String, kind: String) -> void:
	if seen.has(id):
		errors.append("duplicate %s id '%s'" % [kind, id])
	seen[id] = kind


## Adds what is newer than the save: goods to every city it has, then the cities after its last
## one, all as a new game starts them. Nothing for a save of the current version.
func _grow_world(data: GameData, world: WorldState) -> void:
	for good in data.goods:
		if _save_goods.has(good.id):
			continue
		world.goods_ledger[good.id] = 0
		for city in world.cities:
			Simulation.stock_new_good(data, world, city, good)
	for i in range(world.cities.size(), data.cities.size()):
		Simulation.add_city(data, world, data.cities[i])


func _read_cities(data: GameData, world: WorldState, cities: Array, version: int) -> void:
	var expected := 0
	for city_def in data.cities:
		if city_def.since_save <= version:
			expected += 1
	if cities.size() != expected:
		errors.append(
			"save has %d cities, its version %d has %d" % [cities.size(), version, expected]
		)
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
		# Only the range a city can reach in play: larger values would bypass the loader's overflow
		# checks on population × rates.
		var population := _int(raw, "population", ctx)
		var home := data.cities[i].population
		var lowest := data.population.min_population(home)
		var highest := data.population.max_population(home)
		if population < lowest or population > highest:
			var bounds := [ctx, population, lowest, highest]
			errors.append("%s: population %d outside %d to %d" % bounds)
		var city := CityState.new(id, population)
		if version >= 5:
			city.satisfaction = _int(raw, "satisfaction", ctx)
			if city.satisfaction < 0 or city.satisfaction > CityEconomy.PARTS_PER_UNIT:
				var limit := CityEconomy.PARTS_PER_UNIT
				errors.append(
					"%s: satisfaction %d outside 0 to %d" % [ctx, city.satisfaction, limit]
				)
		else:
			city.satisfaction = CityEconomy.to_parts(data.population.neutral_satisfaction)
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
		if version >= 2:
			_read_history(data, city, _dict(raw, "price_history", ctx), ctx)
		else:
			for good in data.goods:
				city.price_history[good.id] = PackedInt64Array()
		world.add_city(city)


static func _history_to_dict(city: CityState) -> Dictionary:
	var history: Dictionary = {}
	for good_id: String in city.price_history:
		history[good_id] = Array(city.price_history[good_id])
	return history


## Every good needs a history of at most HISTORY_DAYS whole, non-negative prices (in
## PriceHistorySystem's scale). A balance change can move the clamped price range after a game was
## saved, and the history is only drawn, so prices outside today's range are clamped into it
## instead of rejecting the save.
func _read_history(data: GameData, city: CityState, raw: Dictionary, ctx: String) -> void:
	for key: Variant in raw.keys():
		if not data.has_good(str(key)):
			errors.append("%s price_history: unknown good '%s'" % [ctx, str(key)])
	for good in data.goods:
		if not _save_goods.has(good.id):
			continue
		var good_ctx := "%s price_history %s" % [ctx, good.id]
		var history := PackedInt64Array()
		var entries := _array(raw, good.id, "%s price_history" % ctx)
		if entries.size() > PriceHistorySystem.HISTORY_DAYS:
			var limit := PriceHistorySystem.HISTORY_DAYS
			errors.append("%s: %d days, at most %d" % [good_ctx, entries.size(), limit])
		var lowest := PriceHistorySystem.min_scaled_price(data.economy, good)
		var highest := PriceHistorySystem.max_scaled_price(data.economy, good)
		for i in entries.size():
			var price := _int({"price": entries[i]}, "price", "%s[%d]" % [good_ctx, i])
			if price < 0:
				errors.append("%s[%d]: price %d is negative" % [good_ctx, i, price])
			history.append(clampi(price, lowest, highest))
		city.price_history[good.id] = history


func _read_trader(
	data: GameData, raw_value: Variant, ctx: String, version: int, current_day: int
) -> TraderState:
	if not raw_value is Dictionary:
		errors.append("%s: must be an object" % ctx)
		return null
	var raw: Dictionary = raw_value
	var trader := TraderState.new(
		_string(raw, "id", ctx), _string(raw, "name", ctx), _int(raw, "coins", ctx)
	)
	if version >= 9:
		trader.debt = _int(raw, "debt", ctx)
		trader.debt_days = _int(raw, "debt_days", ctx)
		trader.bankrupt = _bool(raw, "bankrupt", ctx)
		trader.person_ship_id = _string(raw, "person_ship", ctx)
		trader.person_city_id = _string(raw, "person_city", ctx)
		var raw_captains := _array(raw, "captains", ctx)
		for i in raw_captains.size():
			var captain := _read_captain(raw_captains[i], "%s captains[%d]" % [ctx, i])
			if captain != null:
				trader.captains.append(captain)
	if version >= 10:
		trader.rank_id = _string(raw, "rank", ctx)
	if version >= 11:
		trader.sale_end_day = _int(raw, "sale_end_day", ctx)
		if data.rank_index(trader.rank_id) < 0:
			errors.append("%s: unknown rank '%s'" % [ctx, trader.rank_id])
		var reputation := _dict(raw, "reputation", ctx)
		for key: Variant in reputation.keys():
			var city_id := str(key)
			var points := _int(reputation, city_id, "%s reputation" % ctx)
			if not data.has_city(city_id):
				errors.append("%s reputation: unknown city '%s'" % [ctx, city_id])
			elif points <= 0 or points > data.reputation.max:
				var bounds := [ctx, city_id, points, data.reputation.max]
				errors.append("%s reputation: %s %d outside 1 to %d" % bounds)
			else:
				trader.reputation[city_id] = points
	if version >= 3:
		var routes := _array(raw, "routes", ctx)
		for i in routes.size():
			var route := _read_route(data, routes[i], "%s routes[%d]" % [ctx, i])
			if route != null:
				trader.routes.append(route)
	var ships := _array(raw, "ships", ctx)
	for i in ships.size():
		var ship := _read_ship(data, ships[i], "%s ships[%d]" % [ctx, i])
		if ship == null:
			continue
		if version >= 6:
			ship.spoil_carry = _carry(data, ships[i] as Dictionary, "%s ships[%d]" % [ctx, i])
		if version >= 9:
			ship.captain_id = _string(ships[i], "captain", "%s ships[%d]" % [ctx, i])
		if version >= 8:
			if not (ships[i] as Dictionary).has("news"):
				errors.append("%s ships[%d]: missing news" % [ctx, i])
			var news: Variant = (ships[i] as Dictionary).get("news")
			if news != null:
				ship.news = _read_market(data, news, "%s ships[%d] news" % [ctx, i], current_day)
			if not ship.is_docked() and ship.news == null:
				errors.append("%s ships[%d]: a sailing ship needs departure news" % [ctx, i])
			elif not ship.is_docked() and ship.news.city_id != ship.origin:
				errors.append("%s ships[%d]: departure news must be from the origin" % [ctx, i])
		if version >= 3:
			_read_ship_route(trader, ship, ships[i], "%s ships[%d]" % [ctx, i])
		trader.ships.append(ship)
	var kontors := _array(raw, "kontors", ctx)
	for i in kontors.size():
		var kontor := _read_kontor(data, kontors[i], "%s kontors[%d]" % [ctx, i], version)
		if kontor != null and version >= 6:
			kontor.spoil_carry = _carry(data, kontors[i] as Dictionary, "%s kontors[%d]" % [ctx, i])
		if kontor == null:
			continue
		if trader.kontors.has(kontor.city_id):
			errors.append("%s kontors[%d]: second kontor in %s" % [ctx, i, kontor.city_id])
		trader.kontors[kontor.city_id] = kontor
	if version >= 8:
		var book := _array(raw, "market_book", ctx)
		for i in book.size():
			var record := _read_market(data, book[i], "%s market_book[%d]" % [ctx, i], current_day)
			if record == null:
				continue
			if trader.market_book.has(record.city_id):
				errors.append("%s: duplicate market report for %s" % [ctx, record.city_id])
			trader.market_book[record.city_id] = record
	return trader


func _read_captain(raw_value: Variant, ctx: String) -> CaptainState:
	if not raw_value is Dictionary:
		errors.append("%s: must be an object" % ctx)
		return null
	var raw: Dictionary = raw_value
	var captain := CaptainState.new(
		_string(raw, "id", ctx),
		_string(raw, "name", ctx),
		_int(raw, "wage", ctx),
		_string(raw, "city", ctx)
	)
	captain.ship_id = _string(raw, "ship", ctx)
	captain.seamanship = _int(raw, "seamanship", ctx)
	captain.trading = _int(raw, "trading", ctx)
	captain.voyages = _int(raw, "voyages", ctx)
	return captain


func _read_taverns(data: GameData, world: WorldState, entries: Array) -> void:
	if entries.size() != data.cities.size():
		errors.append(
			"save has %d taverns, the game has %d cities" % [entries.size(), data.cities.size()]
		)
		return
	for i in entries.size():
		var ctx := "taverns[%d]" % i
		if not entries[i] is Dictionary:
			errors.append("%s: must be an object" % ctx)
			continue
		var raw: Dictionary = entries[i]
		var city_id := _string(raw, "city", ctx)
		if city_id != data.cities[i].id:
			errors.append("%s: expected city '%s'" % [ctx, data.cities[i].id])
		var pool: Array[CaptainState] = []
		var candidates := _array(raw, "captains", ctx)
		for j in candidates.size():
			var captain := _read_captain(candidates[j], "%s captains[%d]" % [ctx, j])
			if captain != null:
				pool.append(captain)
		world.taverns[city_id] = pool


## An untrusted market report: all goods must be present. Quotes aren't saved but derived from the
## remembered stock and population. History may contain -1 gaps but no other negative prices.
func _read_market(
	data: GameData, raw_value: Variant, ctx: String, current_day: int
) -> MarketRecord:
	if not raw_value is Dictionary:
		errors.append("%s: must be an object" % ctx)
		return null
	var raw: Dictionary = raw_value
	var city_id := _string(raw, "city", ctx)
	if not data.has_city(city_id):
		errors.append("%s: unknown city '%s'" % [ctx, city_id])
		return null
	var record := MarketRecord.new(city_id, _int(raw, "day", ctx))
	if record.day < 0 or record.day > current_day:
		errors.append("%s: day %d outside 0 to %d" % [ctx, record.day, current_day])
	record.population = _int(raw, "population", ctx)
	record.satisfaction = _int(raw, "satisfaction", ctx)
	if record.satisfaction < 0 or record.satisfaction > CityEconomy.PARTS_PER_UNIT:
		errors.append("%s: satisfaction is out of range" % ctx)
	var home := data.get_city(city_id).population
	if (
		record.population < data.population.min_population(home)
		or record.population > data.population.max_population(home)
	):
		errors.append("%s: population %d outside the city's range" % [ctx, record.population])
	for field: String in ["stock", "shortage"]:
		var values := _goods(data, _dict(raw, field, ctx), "%s %s" % [ctx, field], true)
		for good in data.goods:
			if not values.has(good.id):
				values[good.id] = 0
			elif values[good.id] < 0:
				errors.append("%s %s %s: must not be negative" % [ctx, field, good.id])
		if field == "stock":
			record.stock = values
		else:
			record.shortage = values
	MarketKnowledgeSystem.fill_prices(data, record)
	var history := _dict(raw, "history", ctx)
	for key: Variant in history.keys():
		if not data.has_good(str(key)):
			errors.append("%s history: unknown good '%s'" % [ctx, str(key)])
	for good in data.goods:
		if not history.has(good.id):
			continue
		var entries := _array(history, good.id, "%s history" % ctx)
		if entries.size() > PriceHistorySystem.HISTORY_DAYS:
			errors.append("%s history %s: more than 30 days" % [ctx, good.id])
		var prices := PackedInt64Array()
		for i in entries.size():
			var value := _int(
				{"price": entries[i]}, "price", "%s history %s[%d]" % [ctx, good.id, i]
			)
			if value < -1 or value > PriceHistorySystem.max_scaled_price(data.economy, good):
				errors.append("%s history %s[%d]: price out of range" % [ctx, good.id, i])
			prices.append(value)
		record.history[good.id] = prices
	return record


func _migrate_market_books(data: GameData, world: WorldState) -> void:
	@warning_ignore("integer_division")
	var day := world.hour / Simulation.HOURS_PER_DAY
	for trader in world.traders:
		for city in world.cities:
			trader.market_book[city.id] = MarketKnowledgeSystem.current_report(data, city, day)
		for ship in trader.ships:
			var source := ship.docked_at if ship.is_docked() else ship.origin
			if data.has_city(source):
				ship.news = trader.market_book[source].copy_report()


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


## A ship's route must be one of its owner's routes, with the stop index in range.
func _read_ship_route(trader: TraderState, ship: ShipState, raw: Dictionary, ctx: String) -> void:
	ship.route_id = _string(raw, "route", ctx)
	ship.route_stop = _int(raw, "route_stop", ctx)
	ship.route_note = _string(raw, "route_note", ctx)
	if ship.route_id.is_empty():
		if ship.route_stop != 0 or not ship.route_note.is_empty():
			errors.append("%s: route_stop and route_note need a route" % ctx)
		return
	var route := trader.get_route(ship.route_id)
	if route == null:
		errors.append("%s: unknown route '%s'" % [ctx, ship.route_id])
	elif ship.route_stop < 0 or ship.route_stop >= route.stops.size():
		errors.append("%s: route_stop %d outside the route" % [ctx, ship.route_stop])


func _read_route(data: GameData, raw_value: Variant, ctx: String) -> RouteState:
	if not raw_value is Dictionary:
		errors.append("%s: must be an object" % ctx)
		return null
	var raw: Dictionary = raw_value
	var stops: Array[RouteStop] = []
	var raw_stops := _array(raw, "stops", ctx)
	for i in raw_stops.size():
		var stop_ctx := "%s stops[%d]" % [ctx, i]
		if not raw_stops[i] is Dictionary:
			errors.append("%s: must be an object" % stop_ctx)
			continue
		var raw_stop: Dictionary = raw_stops[i]
		var orders: Array[RouteOrder] = []
		var raw_orders := _array(raw_stop, "orders", stop_ctx)
		for j in raw_orders.size():
			var order_ctx := "%s orders[%d]" % [stop_ctx, j]
			if not raw_orders[j] is Dictionary:
				errors.append("%s: must be an object" % order_ctx)
				continue
			var raw_order: Dictionary = raw_orders[j]
			var action := _string(raw_order, "action", order_ctx)
			if not RouteOrder.Action.has(action):
				errors.append("%s: unknown action '%s'" % [order_ctx, action])
				continue
			(
				orders
				. append(
					(
						RouteOrder
						. new(
							RouteOrder.Action[action] as RouteOrder.Action,
							_string(raw_order, "good", order_ctx),
							_int(raw_order, "quantity", order_ctx),
							_int(raw_order, "price_limit", order_ctx),
						)
					)
				)
			)
		stops.append(RouteStop.new(_string(raw_stop, "city", stop_ctx), orders))
	var route := RouteState.new(_string(raw, "id", ctx), _string(raw, "name", ctx), stops)
	var problem := RouteState.check(data, route.name, stops)
	if not problem.is_empty():
		errors.append("%s: %s" % [ctx, problem])
	return route


## A running event: a known type and city, and a span of days that has begun and not ended.
func _read_event(data: GameData, raw_value: Variant, ctx: String) -> EventState:
	if not raw_value is Dictionary:
		errors.append("%s: must be an object" % ctx)
		return null
	var raw: Dictionary = raw_value
	var event := (
		EventState
		. new(
			_string(raw, "id", ctx),
			_string(raw, "type", ctx),
			_string(raw, "city", ctx),
			_int(raw, "start_day", ctx),
			_int(raw, "end_day", ctx),
		)
	)
	if not data.has_event(event.type_id):
		errors.append("%s: unknown event type '%s'" % [ctx, event.type_id])
	if not data.has_city(event.city_id):
		errors.append("%s: unknown city '%s'" % [ctx, event.city_id])
	if event.start_day < 0 or event.end_day <= event.start_day:
		errors.append("%s: days %d to %d are not a span" % [ctx, event.start_day, event.end_day])
	return event


## A hold's spoilage fractions: known goods, each 1..PARTS_PER_UNIT - 1.
func _carry(data: GameData, raw: Dictionary, ctx: String) -> Dictionary[String, int]:
	var carry: Dictionary[String, int] = {}
	var table := _dict(raw, "spoil_carry", ctx)
	for key: Variant in table.keys():
		var good_id := str(key)
		var parts := _int(table, good_id, "%s spoil_carry" % ctx)
		if not data.has_good(good_id):
			errors.append("%s spoil_carry: unknown good '%s'" % [ctx, good_id])
		elif parts <= 0 or parts >= CityEconomy.PARTS_PER_UNIT:
			errors.append("%s spoil_carry: %s %d outside 1 to 999999" % [ctx, good_id, parts])
		else:
			carry[good_id] = parts
	return carry


func _read_kontor(data: GameData, raw_value: Variant, ctx: String, version: int) -> KontorState:
	if not raw_value is Dictionary:
		errors.append("%s: must be an object" % ctx)
		return null
	var raw: Dictionary = raw_value
	var kontor := KontorState.new(_string(raw, "city", ctx))
	if not data.has_city(kontor.city_id):
		errors.append("%s: unknown city '%s'" % [ctx, kontor.city_id])
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
		# The kontor panel names the missing good for NO_INPUTS, so it must exist then and only then.
		workshop.missing_good = _string(entry, "missing_good", workshop_ctx)
		if workshop.status == WorkshopState.Status.NO_INPUTS:
			if not data.has_good(workshop.missing_good):
				var missing := workshop.missing_good
				errors.append("%s: unknown missing good '%s'" % [workshop_ctx, missing])
		elif workshop.missing_good != "":
			errors.append("%s: missing_good is only allowed for NO_INPUTS" % workshop_ctx)
		if version >= 5:
			workshop.progress = _int(entry, "progress", workshop_ctx)
			if workshop.progress < 0 or workshop.progress > CityEconomy.PARTS_PER_UNIT:
				var bounds := [workshop_ctx, workshop.progress, CityEconomy.PARTS_PER_UNIT]
				errors.append("%s: progress %d outside 0 to %d" % bounds)
		kontor.workshops.append(workshop)
	if version >= 10:
		_read_factor(data, kontor, _array(raw, "factor", ctx), ctx)
	return kontor


## Offers from known rivals for the player's assets, each with a known kind and a positive price.
## Whether the asset still exists is checked when the player accepts.
func _read_offers(data: GameData, world: WorldState, entries: Array) -> void:
	for i in entries.size():
		var ctx := "offers[%d]" % i
		if not entries[i] is Dictionary:
			errors.append("%s: must be an object" % ctx)
			continue
		var raw: Dictionary = entries[i]
		var kind := _string(raw, "kind", ctx)
		if not OfferState.Kind.has(kind):
			errors.append("%s: unknown kind '%s'" % [ctx, kind])
			continue
		var offer := OfferState.new(
			_string(raw, "id", ctx),
			_string(raw, "buyer", ctx),
			OfferState.Kind[kind] as OfferState.Kind,
			_string(raw, "asset", ctx),
			_int(raw, "price", ctx),
			_int(raw, "last_day", ctx)
		)
		if not data.has_rival(offer.buyer_id):
			errors.append("%s: unknown buyer '%s'" % [ctx, offer.buyer_id])
		if offer.price <= 0:
			errors.append("%s: price must be positive" % ctx)
		world.offers.append(offer)


func _read_factor(data: GameData, kontor: KontorState, entries: Array, ctx: String) -> void:
	for i in entries.size():
		var order_ctx := "%s factor[%d]" % [ctx, i]
		if not entries[i] is Dictionary:
			errors.append("%s: must be an object" % order_ctx)
			continue
		var raw: Dictionary = entries[i]
		var action := _string(raw, "action", order_ctx)
		if not FactorOrder.Action.has(action):
			errors.append("%s: unknown action '%s'" % [order_ctx, action])
			continue
		(
			kontor
			. factor_orders
			. append(
				(
					FactorOrder
					. new(
						FactorOrder.Action[action] as FactorOrder.Action,
						_string(raw, "good", order_ctx),
						_int(raw, "amount", order_ctx),
						_int(raw, "price_limit", order_ctx),
					)
				)
			)
		)
	var problem := FactorOrder.check(data, kontor.factor_orders)
	if not problem.is_empty():
		errors.append("%s factor: %s" % [ctx, problem])


## A per-good table of whole numbers. With `complete`, every good the save covers must be present
## (cities and the ledger); otherwise only known goods with positive amounts may appear (cargo).
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
			if not table.has(good.id) and _save_goods.has(good.id):
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


func _bool(raw: Dictionary, field: String, ctx: String) -> bool:
	var value: Variant = raw.get(field)
	if value is bool:
		return value as bool
	errors.append("%s: '%s' must be a boolean" % [ctx, field])
	return false


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
