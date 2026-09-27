class_name HireCaptainCommand
extends Command
## Hires a tavern candidate to command an uncrewed docked ship in the same port.

var trader_id: String
var ship_id: String
var captain_id: String


func _init(p_trader_id: String, p_ship_id: String, p_captain_id: String) -> void:
	trader_id = p_trader_id
	ship_id = p_ship_id
	captain_id = p_captain_id


func validate(sim: Simulation) -> String:
	var ship := Command.find_ship(sim, trader_id, ship_id)
	if ship == null:
		return "unknown ship '%s'" % ship_id
	if not ship.is_docked():
		return "%s is at sea" % ship.name
	if not ship.captain_id.is_empty():
		return "%s already has a captain" % ship.name
	var pool: Array = sim.world.taverns.get(ship.docked_at, [])
	if _candidate(pool) == null:
		return "captain '%s' is not available in this port" % captain_id
	if sim.world.get_trader(trader_id).coins < sim.data.captains.hiring_fee:
		return "Hiring costs %d coins" % sim.data.captains.hiring_fee
	return ""


func apply(sim: Simulation) -> void:
	var ship := Command.find_ship(sim, trader_id, ship_id)
	var trader := sim.world.get_trader(trader_id)
	var pool: Array = sim.world.taverns[ship.docked_at]
	var captain := _candidate(pool)
	pool.erase(captain)
	trader.coins -= sim.data.captains.hiring_fee
	captain.city_id = ""
	captain.ship_id = ship.id
	ship.captain_id = captain.id
	trader.captains.append(captain)


func _candidate(pool: Array) -> CaptainState:
	for captain: CaptainState in pool:
		if captain.id == captain_id:
			return captain
	return null
