class_name CaptainSystem
extends RefCounted
## Tavern recruitment, captain experience and wages. All draws use the world's seeded RNG.

const NAMES: PackedStringArray = [
	"Albrecht",
	"Bernd",
	"Claus",
	"Dietrich",
	"Erik",
	"Friedrich",
	"Gerd",
	"Henrik",
	"Ingrid",
	"Johann",
	"Karin",
	"Lars",
	"Marta",
	"Nils",
	"Oskar",
	"Pieter"
]
const TAVERN_WEEK_DAYS: int = 7


## The initial crews make existing starting scenarios immediately playable.
static func crew_starting_ships(data: GameData, world: WorldState) -> void:
	for trader in world.traders:
		for ship in trader.ships:
			world.add_captain(trader, "Captain of %s" % ship.name, data.captains.daily_wage, ship)
	refresh_taverns(data, world)


## Replaces all unclaimed tavern candidates in data city order once a week.
static func refresh_taverns(data: GameData, world: WorldState) -> void:
	for city in data.cities:
		var pool: Array[CaptainState] = []
		for i in data.captains.tavern_pool_size:
			var number := world.next_captain_number
			world.next_captain_number += 1
			var name := NAMES[world.rng.randi_range(0, NAMES.size() - 1)]
			var candidate := CaptainState.new(
				"captain_%d" % number, "%s %d" % [name, number], data.captains.daily_wage, city.id
			)
			pool.append(candidate)
		world.taverns[city.id] = pool


## Pays what each house can afford and carries any shortfall as debt. Debt can be repaid later.
static func run_day(data: GameData, world: WorldState, day: int) -> void:
	if day % TAVERN_WEEK_DAYS == 0:
		refresh_taverns(data, world)
	for trader in world.traders:
		if trader.bankrupt:
			continue
		var due := trader.debt
		for captain in trader.captains:
			due += captain.wage
		var paid := mini(due, trader.coins)
		trader.coins -= paid
		trader.debt = due - paid
		if trader.debt > 0:
			trader.debt_days += 1
		else:
			trader.debt_days = 0
		if trader.debt_days >= data.captains.bankruptcy_grace_days:
			trader.bankrupt = true
	for trader: TraderState in world.traders.duplicate():
		if trader.bankrupt and trader.id != WorldState.PLAYER_ID:
			_liquidate(data, world, trader)


## Assets of a failed rival return to their local city markets; M15 can replace this with sales.
static func _liquidate(data: GameData, world: WorldState, trader: TraderState) -> void:
	for ship in trader.ships:
		var city_id := ship.docked_at if ship.is_docked() else ship.destination
		var city := world.get_city(city_id)
		for good in data.goods:
			city.stock[good.id] += ship.cargo_of(good.id)
	for kontor in trader.kontors_in_order(data.cities):
		var city := world.get_city(kontor.city_id)
		for good in data.goods:
			city.stock[good.id] += kontor.cargo_of(good.id)
	world.traders.erase(trader)


## Progress after a completed voyage, capped at the configured skill limit.
static func complete_voyage(data: GameData, trader: TraderState, ship: ShipState) -> void:
	var captain := trader.get_captain(ship.captain_id)
	if captain == null:
		return
	captain.voyages += 1
	var level: int = captain.voyages / data.captains.voyages_per_level
	captain.seamanship = mini(level, data.captains.max_skill)
	captain.trading = mini(level, data.captains.max_skill)


## Voyage hours saved by a captain, while every journey still lasts at least one hour.
static func voyage_hours(
	data: GameData, ship: ShipState, captain: CaptainState, destination: String
) -> int:
	var base := Navigation.travel_hours(
		data, data.get_ship(ship.type_id), ship.docked_at, destination
	)
	return maxi(1, base - captain.seamanship * data.captains.seamanship_hours_per_level)


## Experienced captains reduce their ship's spread; kontors use the full spread.
static func trade_spread(data: GameData, trader: TraderState, ship_id: String) -> float:
	if ship_id.is_empty():
		return data.economy.spread
	var ship := trader.get_ship(ship_id)
	var captain := trader.get_captain(ship.captain_id)
	if captain == null:
		return data.economy.spread
	return (
		data.economy.spread
		* float(data.captains.max_skill - captain.trading)
		/ data.captains.max_skill
	)
