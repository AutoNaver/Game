class_name RivalSystem
extends RefCounted
## The rival trading houses' decisions (ADR 0008). Rivals are ordinary traders: everything they do
## goes through the same commands the player uses, and every random choice draws on the world RNG.
##
## Hourly, after ships move: a rival ship docked in a city sells all its cargo, picks a load among
## the best few TradePlanner options (weighted by profit per day) and sails for it. If nothing
## pays, it sails empty to a random other city.
##
## Daily, after the daily systems: each rival sells its workshops' output from its kontors and
## buys their inputs for a few days ahead. Every `expansion_days` days it closes workshops that
## lose money at today's prices, then may buy a ship or set up a workshop (buying a kontor for it
## if needed), keeping `cash_reserve` coins back. A rival runs at most one workshop per kontor and
## never opens a workshop type in a city where any house already runs one.

## Coins that never limit a purchase, for asking only whether a market can supply goods.
const UNLIMITED_COINS: int = 1 << 62


static func run_hour(sim: Simulation) -> void:
	for trader in sim.world.traders:
		if not sim.data.has_rival(trader.id):
			continue
		for ship in trader.ships:
			if ship.captain_id.is_empty() and ship.is_docked():
				var pool: Array = sim.world.taverns.get(ship.docked_at, [])
				if not pool.is_empty():
					sim.execute(HireCaptainCommand.new(trader.id, ship.id, pool[0].id))
			if ship.is_docked() and ship.route_id.is_empty() and not ship.captain_id.is_empty():
				_trade_and_sail(sim, trader, ship)


static func run_day(sim: Simulation) -> void:
	var ai := sim.data.rival_ai
	for trader in sim.world.traders:
		if not sim.data.has_rival(trader.id):
			continue
		_run_kontors(sim, trader)
		if sim.day() % ai.expansion_days == 0:
			_close_losing_workshops(sim, trader)
			_expand(sim, trader)


## A workshop a rival could set up in `city_id`, in its kontor there or a new one.
class Venture:
	extends RefCounted
	var city_id: String
	var type: WorkshopDef
	## Estimated coins per day at today's prices, after wages.
	var margin: float

	func _init(p_city_id: String, p_type: WorkshopDef, p_margin: float) -> void:
		city_id = p_city_id
		type = p_type
		margin = p_margin


## The best new workshop the trader can afford with `budget` coins, or null if none pays. Only
## cities where the trader has an empty kontor, or none yet while it has fewer than `max_kontors`.
static func best_venture(sim: Simulation, trader: TraderState, budget: int) -> Venture:
	var ai := sim.data.rival_ai
	var best: Venture = null
	for city_def in sim.data.cities:
		var kontor := trader.get_kontor(city_def.id)
		var cost := 0
		if kontor == null:
			if trader.kontors.size() >= ai.max_kontors:
				continue
			cost = sim.data.kontor.price
		elif not kontor.workshops.is_empty():
			continue
		var city := sim.world.get_city(city_def.id)
		var workforce := CityEconomy.workforce(sim.data.economy, city)
		var free := CityEconomy.free_workers(sim.data, sim.world, city)
		for type in sim.data.workshops:
			if cost + type.build_cost > budget or _runs_workshop(sim, city_def.id, type.id):
				continue
			if free - type.workers < workforce * ai.keep_free_workers:
				continue
			var margin := daily_margin(sim, city, type)
			if margin > 0.0 and (best == null or margin > best.margin):
				best = Venture.new(city_def.id, type, margin)
	return best


## True if any house runs a workshop of `type_id` in the city.
static func _runs_workshop(sim: Simulation, city_id: String, type_id: String) -> bool:
	for trader in sim.world.traders:
		var kontor := trader.get_kontor(city_id)
		if kontor == null:
			continue
		for workshop in kontor.workshops:
			if workshop.type_id == type_id:
				return true
	return false


## Coins a workshop of `type` makes per day here when it buys one day's inputs from this market
## and sells one day's output into it at today's stock, after wages. Minus infinity if the market
## can't supply the inputs within the rivals' price limit, since the workshop would sit idle.
static func daily_margin(sim: Simulation, city: CityState, type: WorkshopDef) -> float:
	var economy := sim.data.economy
	var output := sim.data.get_good(type.output)
	var margin := float(
		CityEconomy.sell_revenue(economy, city, output, type.output_per_day) - type.wages_per_day
	)
	for good in sim.data.goods:
		var needed: int = type.inputs.get(good.id, 0)
		if needed == 0:
			continue
		var limit := good.base_price * sim.data.rival_ai.input_price_limit
		if (
			CityEconomy.affordable_quantity(economy, city, good, needed, limit, UNLIMITED_COINS)
			< needed
		):
			return -INF
		margin -= CityEconomy.buy_cost(economy, city, good, needed)
	return margin


static func _trade_and_sail(sim: Simulation, trader: TraderState, ship: ShipState) -> void:
	for good in sim.data.goods:
		var held := ship.cargo_of(good.id)
		if held > 0:
			sim.execute(SellCommand.new(trader.id, ship.id, good.id, held))
	var ship_type := sim.data.get_ship(ship.type_id)
	var space := ship_type.capacity - ship.cargo_total()
	var options := TradePlanner.plan(
		sim.data, sim.world, ship_type, ship.docked_at, space, trader.coins
	)
	var choice := pick_option(sim.world.rng, options, sim.data.rival_ai.top_choices)
	var destination := ""
	if choice != null:
		sim.execute(BuyCommand.new(trader.id, ship.id, choice.good_id, choice.quantity))
		destination = choice.destination
	else:
		destination = _random_other_city(sim, ship.docked_at)
	if not destination.is_empty():
		sim.execute(SailCommand.new(trader.id, ship.id, destination))


## One of the first `top` options (best first, as TradePlanner sorts them), drawn with a chance
## in proportion to its profit per day. Null if there are none.
static func pick_option(
	rng: RandomNumberGenerator, options: Array[TradePlanner.Option], top: int
) -> TradePlanner.Option:
	var count := mini(top, options.size())
	if count == 0:
		return null
	var total := 0.0
	for i in count:
		total += options[i].profit_per_day()
	var roll := rng.randf() * total
	for i in count:
		roll -= options[i].profit_per_day()
		if roll < 0.0:
			return options[i]
	return options[count - 1]


## A random city other than `city_id`, or "" in a world with only one city (the ship stays).
static func _random_other_city(sim: Simulation, city_id: String) -> String:
	var others: Array[String] = []
	for city in sim.data.cities:
		if city.id != city_id:
			others.append(city.id)
	if others.is_empty():
		return ""
	return others[sim.world.rng.randi_range(0, others.size() - 1)]


## Sells each workshop's output and buys its inputs for `workshop_input_days` days, within the
## price limit, the kontor's room and the coins left after a day's wages.
static func _run_kontors(sim: Simulation, trader: TraderState) -> void:
	var ai := sim.data.rival_ai
	var economy := sim.data.economy
	for kontor in trader.kontors_in_order(sim.data.cities):
		var city := sim.world.get_city(kontor.city_id)
		for workshop in kontor.workshops:
			var type := sim.data.get_workshop(workshop.type_id)
			var output := kontor.cargo_of(type.output)
			if output > 0:
				sim.execute(SellCommand.for_kontor(trader.id, city.id, type.output, output))
			for good in sim.data.goods:
				var needed: int = type.inputs.get(good.id, 0)
				var wanted := needed * ai.workshop_input_days - kontor.cargo_of(good.id)
				var room := sim.data.kontor.capacity - kontor.cargo_total()
				var most := mini(wanted, room)
				if needed == 0 or most <= 0:
					continue
				var limit := good.base_price * ai.input_price_limit
				var coins := maxi(0, trader.coins - type.wages_per_day)
				var quantity := CityEconomy.affordable_quantity(
					economy, city, good, most, limit, coins
				)
				if quantity > 0:
					sim.execute(BuyCommand.for_kontor(trader.id, city.id, good.id, quantity))


## Closes the trader's workshops that lose money at today's prices (see daily_margin).
static func _close_losing_workshops(sim: Simulation, trader: TraderState) -> void:
	for kontor in trader.kontors_in_order(sim.data.cities):
		var city := sim.world.get_city(kontor.city_id)
		for workshop: WorkshopState in kontor.workshops.duplicate():
			if daily_margin(sim, city, sim.data.get_workshop(workshop.type_id)) < 0.0:
				sim.execute(CloseWorkshopCommand.new(trader.id, kontor.city_id, workshop.id))


## Buys a ship, or a workshop (with a kontor if needed), if the trader can spare the coins. When
## both are possible, a coin toss on the world RNG decides.
static func _expand(sim: Simulation, trader: TraderState) -> void:
	var budget := trader.coins - sim.data.rival_ai.cash_reserve
	var ship_type := ship_to_buy(sim, trader, budget)
	var venture := best_venture(sim, trader, budget)
	if ship_type != null and venture != null:
		if sim.world.rng.randi_range(0, 1) == 0:
			venture = null
		else:
			ship_type = null
	if venture != null:
		if trader.get_kontor(venture.city_id) == null:
			sim.execute(BuyKontorCommand.new(trader.id, venture.city_id))
		sim.execute(BuildWorkshopCommand.new(trader.id, venture.city_id, venture.type.id))
	elif ship_type != null:
		var home := sim.data.get_rival(trader.id).start_city
		sim.execute(BuyShipCommand.new(trader.id, home, ship_type.id))


## The biggest ship type the trader can buy with `budget`, or null if none, or the fleet is full.
static func ship_to_buy(sim: Simulation, trader: TraderState, budget: int) -> ShipDef:
	if trader.ships.size() >= sim.data.rival_ai.max_ships:
		return null
	var best: ShipDef = null
	for type in sim.data.ships:
		if type.price <= budget and (best == null or type.capacity > best.capacity):
			best = type
	return best
