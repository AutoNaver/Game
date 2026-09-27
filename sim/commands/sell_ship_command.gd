class_name SellShipCommand
extends Command
## Sells an empty, docked ship to the shipyard for part of its price (economy ship_resale_factor).

var trader_id: String
var ship_id: String


func _init(p_trader_id: String, p_ship_id: String) -> void:
	trader_id = p_trader_id
	ship_id = p_ship_id


## Coins the shipyard pays for a ship of `ship_type`.
static func resale_price(data: GameData, ship_type: ShipDef) -> int:
	var factor := CityEconomy.rate_steps(data.economy.ship_resale_factor)
	@warning_ignore("integer_division")
	return ship_type.price * factor / CityEconomy.RATE_STEPS


func validate(sim: Simulation) -> String:
	var ship := Command.find_ship(sim, trader_id, ship_id)
	if ship == null:
		return "unknown ship '%s'" % ship_id
	if not ship.is_docked():
		return "%s is at sea" % ship.name
	if ship.cargo_total() > 0:
		return "Unload %s before selling it" % ship.name
	var trader := sim.world.get_trader(trader_id)
	if trader.id == WorldState.PLAYER_ID and trader.person_ship_id == ship_id:
		return "Go ashore before selling %s" % ship.name
	return ""


func apply(sim: Simulation) -> void:
	var trader := sim.world.get_trader(trader_id)
	var ship := trader.get_ship(ship_id)
	trader.coins += resale_price(sim.data, sim.data.get_ship(ship.type_id))
	if not ship.captain_id.is_empty():
		var captain := trader.get_captain(ship.captain_id)
		captain.ship_id = ""
		captain.city_id = ship.docked_at
		trader.captains.erase(captain)
		var pool: Array = sim.world.taverns[ship.docked_at]
		pool.append(captain)
	trader.remove_ship(ship_id)
