class_name TradeCommand
extends Command
## Shared shape and checks of buying and selling: a quantity of one good traded with a city market,
## using either a docked ship (ship_id) or the trader's kontor in a city (city_id, ship_id empty).

var trader_id: String
var ship_id: String
var good_id: String
var quantity: int
## Set instead of ship_id to trade with the trader's kontor in this city.
var city_id: String = ""


func _init(p_trader_id: String, p_ship_id: String, p_good_id: String, p_quantity: int) -> void:
	trader_id = p_trader_id
	ship_id = p_ship_id
	good_id = p_good_id
	quantity = p_quantity


## Checks everything buy and sell have in common. Returns "" if the trade may proceed.
func validate_trade(sim: Simulation) -> String:
	var error := _validate_hold(sim)
	if not error.is_empty():
		return error
	if not sim.data.has_good(good_id):
		return "unknown good '%s'" % good_id
	if quantity <= 0:
		return "quantity must be positive"
	return ""


func _validate_hold(sim: Simulation) -> String:
	if not ship_id.is_empty():
		var ship := Command.find_ship(sim, trader_id, ship_id)
		if ship == null:
			return "unknown ship '%s'" % ship_id
		if not ship.is_docked():
			return "%s is at sea" % ship.name
		return ""
	var trader := sim.world.get_trader(trader_id)
	if trader == null or trader.get_kontor(city_id) == null:
		return "You have no kontor in %s" % Command.city_name(sim, city_id)
	return ""


# Lookup helpers for subclasses. They assume validate_trade() returned "", so the trader and the
# ship or kontor exist and a ship is docked; before that they may return null.


func _trader(sim: Simulation) -> TraderState:
	return sim.world.get_trader(trader_id)


## The ship or kontor the goods go into or come out of.
func _hold(sim: Simulation) -> Hold:
	if ship_id.is_empty():
		return _trader(sim).get_kontor(city_id)
	return Command.find_ship(sim, trader_id, ship_id)


func _hold_capacity(sim: Simulation) -> int:
	if ship_id.is_empty():
		return sim.data.kontor.capacity
	return sim.data.get_ship((_hold(sim) as ShipState).type_id).capacity


## For messages: the ship's name, or "Your kontor".
func _hold_name(sim: Simulation) -> String:
	if ship_id.is_empty():
		return "Your kontor"
	return (_hold(sim) as ShipState).name


func _market(sim: Simulation) -> CityState:
	if ship_id.is_empty():
		return sim.world.get_city(city_id)
	return sim.world.get_city((_hold(sim) as ShipState).docked_at)
