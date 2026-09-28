class_name GameData
extends RefCounted
## All static definitions the simulation runs on.
##
## The arrays keep file order so iteration is deterministic; use the getters for lookups by id.

var economy: EconomyDef
var captains: CaptainDef
## City satisfaction and population change (data/population.json).
var population: PopulationDef
var scenario: ScenarioDef
var map: MapDef
var sea_chart: SeaChart
var kontor: KontorDef
## In file order.
var workshops: Array[WorkshopDef] = []
var goods: Array[GoodDef] = []
var cities: Array[CityDef] = []
var ships: Array[ShipDef] = []
## Rival trading houses, in file order. Empty means the player trades alone.
var rivals: Array[RivalDef] = []
## Shared rules for the rivals' decisions. Null only when there are no rivals.
var rival_ai: RivalAiDef
## World event types (data/events.json), in file order. Empty means a world without events.
var events: Array[EventDef] = []
## Ranks of a trading house in ascending order, and how reputation works (data/ranks.json).
var ranks: Array[RankDef] = []
var reputation: ReputationDef

var _goods_by_id: Dictionary[String, GoodDef] = {}
var _cities_by_id: Dictionary[String, CityDef] = {}
var _ships_by_id: Dictionary[String, ShipDef] = {}
var _workshops_by_id: Dictionary[String, WorkshopDef] = {}
var _rivals_by_id: Dictionary[String, RivalDef] = {}
var _events_by_id: Dictionary[String, EventDef] = {}


func add_good(good: GoodDef) -> void:
	assert(not has_good(good.id), "duplicate good id '%s'" % good.id)
	goods.append(good)
	_goods_by_id[good.id] = good


func add_city(city: CityDef) -> void:
	assert(not has_city(city.id), "duplicate city id '%s'" % city.id)
	cities.append(city)
	_cities_by_id[city.id] = city


func add_ship(ship: ShipDef) -> void:
	assert(not has_ship(ship.id), "duplicate ship id '%s'" % ship.id)
	ships.append(ship)
	_ships_by_id[ship.id] = ship


func has_good(id: String) -> bool:
	return _goods_by_id.has(id)


func has_city(id: String) -> bool:
	return _cities_by_id.has(id)


func has_ship(id: String) -> bool:
	return _ships_by_id.has(id)


## Returns null for unknown ids.
func get_good(id: String) -> GoodDef:
	return _goods_by_id.get(id)


## Returns null for unknown ids.
func get_city(id: String) -> CityDef:
	return _cities_by_id.get(id)


## Returns null for unknown ids.
func get_ship(id: String) -> ShipDef:
	return _ships_by_id.get(id)


func add_workshop(workshop: WorkshopDef) -> void:
	assert(not has_workshop(workshop.id), "duplicate workshop id '%s'" % workshop.id)
	workshops.append(workshop)
	_workshops_by_id[workshop.id] = workshop


func has_workshop(id: String) -> bool:
	return _workshops_by_id.has(id)


## Returns null for unknown ids.
func get_workshop(id: String) -> WorkshopDef:
	return _workshops_by_id.get(id)


func add_rival(rival: RivalDef) -> void:
	assert(not has_rival(rival.id), "duplicate rival id '%s'" % rival.id)
	rivals.append(rival)
	_rivals_by_id[rival.id] = rival


func has_rival(id: String) -> bool:
	return _rivals_by_id.has(id)


## Returns null for unknown ids (including the player's).
func get_rival(id: String) -> RivalDef:
	return _rivals_by_id.get(id)


func add_event(event: EventDef) -> void:
	assert(not has_event(event.id), "duplicate event id '%s'" % event.id)
	events.append(event)
	_events_by_id[event.id] = event


func has_event(id: String) -> bool:
	return _events_by_id.has(id)


## Returns null for unknown ids.
func get_event(id: String) -> EventDef:
	return _events_by_id.get(id)


## Position of a rank in ascending order, or -1 for unknown ids.
func rank_index(id: String) -> int:
	for i in ranks.size():
		if ranks[i].id == id:
			return i
	return -1
