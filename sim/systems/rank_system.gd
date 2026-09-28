class_name RankSystem
extends RefCounted
## Ranks of the trading houses (ADR 0015): what each house qualifies for, and the gates commands
## check. A house rises daily to the highest rank whose needs it meets and never falls back, so
## the player and the rivals climb under the same rules.


static func rank(data: GameData, trader: TraderState) -> RankDef:
	var index := data.rank_index(trader.rank_id)
	return data.ranks[maxi(index, 0)]


## The city a house started in: its kontor there needs no reputation.
static func home_city(data: GameData, trader: TraderState) -> String:
	if trader.id == WorldState.PLAYER_ID:
		return data.scenario.start_city
	var rival := data.get_rival(trader.id)
	return rival.start_city if rival != null else ""


## True if the house's rank or one below it unlocks `unlock` (a RankDef.UNLOCKS name).
static func has_unlock(data: GameData, trader: TraderState, unlock: String) -> bool:
	for i in data.rank_index(rank(data, trader).id) + 1:
		if data.ranks[i].unlocks.has(unlock):
			return true
	return false


## "" if unlocked, otherwise why not, naming `what` ("Trade routes") and the rank that unlocks it.
static func unlock_error(
	data: GameData, trader: TraderState, unlock: String, what: String
) -> String:
	if has_unlock(data, trader, unlock):
		return ""
	for candidate in data.ranks:
		if candidate.unlocks.has(unlock):
			return "%s need the rank %s" % [what, candidate.name]
	return "%s are not available" % what


## "" if the house's rank lets it buy one more ship of `ship_type`, otherwise why not.
static func ship_error(data: GameData, trader: TraderState, ship_type: ShipDef) -> String:
	var current := rank(data, trader)
	if not ship_type.rank_id.is_empty():
		var needed := data.rank_index(ship_type.rank_id)
		if needed > data.rank_index(current.id):
			return "A %s needs the rank %s" % [ship_type.name, data.ranks[needed].name]
	if current.max_ships > 0 and trader.ships.size() >= current.max_ships:
		return (
			"A %s owns at most %s; %s"
			% [current.name, _count(current.max_ships, "ship"), _next_limit(data, current, true)]
		)
	return ""


## "" if the house's rank and reputation let it buy a kontor in `city_id`, otherwise why not.
static func kontor_error(data: GameData, trader: TraderState, city_id: String) -> String:
	var current := rank(data, trader)
	if current.max_kontors > 0 and trader.kontors.size() >= current.max_kontors:
		return (
			"A %s holds at most %s; %s"
			% [
				current.name,
				_count(current.max_kontors, "kontor"),
				_next_limit(data, current, false)
			]
		)
	var needed := data.reputation.kontor_abroad
	var have := ReputationSystem.of(trader, city_id)
	if city_id != home_city(data, trader) and have < needed:
		var city_name := data.get_city(city_id).name
		return "A kontor in %s needs reputation %d there (you have %d)" % [city_name, needed, have]
	return ""


## Why the house doesn't meet `candidate`'s needs yet, one reason each; empty if it does.
static func missing(
	data: GameData, world: WorldState, trader: TraderState, candidate: RankDef
) -> PackedStringArray:
	var reasons := PackedStringArray()
	var worth := HouseValue.net_worth(data, trader)
	if worth < candidate.net_worth:
		reasons.append("worth %d of %d" % [worth, candidate.net_worth])
	var standing := ReputationSystem.standing_cities(data, trader)
	if standing < candidate.standing_cities:
		reasons.append(
			(
				"reputation %d in %d cities (%d so far)"
				% [data.reputation.standing, candidate.standing_cities, standing]
			)
		)
	if candidate.richest and not _is_richest(data, world, trader, worth):
		reasons.append("the richest house")
	return reasons


## The next rank above the house's, or null at the top.
static func next_rank(data: GameData, trader: TraderState) -> RankDef:
	var index := data.rank_index(rank(data, trader).id) + 1
	return data.ranks[index] if index < data.ranks.size() else null


## Daily and when a world is created or loaded: every house rises to the highest rank it meets.
static func run_day(data: GameData, world: WorldState) -> void:
	for trader in world.traders:
		var index := maxi(data.rank_index(trader.rank_id), 0)
		for i in range(index + 1, data.ranks.size()):
			if missing(data, world, trader, data.ranks[i]).is_empty():
				index = i
		trader.rank_id = data.ranks[index].id


static func _is_richest(data: GameData, world: WorldState, trader: TraderState, worth: int) -> bool:
	for other in world.traders:
		if other != trader and HouseValue.net_worth(data, other) >= worth:
			return false
	return true


## The next rank that raises the limit, for messages.
static func _next_limit(data: GameData, current: RankDef, ships: bool) -> String:
	var limit := current.max_ships if ships else current.max_kontors
	for i in range(data.rank_index(current.id) + 1, data.ranks.size()):
		var higher := data.ranks[i]
		var higher_limit := higher.max_ships if ships else higher.max_kontors
		if higher_limit == 0 or higher_limit > limit:
			return "the rank %s allows more" % higher.name
	return "no rank allows more"


static func _count(amount: int, noun: String) -> String:
	return "%d %s%s" % [amount, noun, "" if amount == 1 else "s"]
