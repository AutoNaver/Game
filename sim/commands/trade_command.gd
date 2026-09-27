class_name TradeCommand
extends Command
## Shared shape and checks of buying and selling: a quantity of one good, traded by a docked ship
## with the market of the city it is docked in.

var trader_id: String
var ship_id: String
var good_id: String
var quantity: int


func _init(p_trader_id: String, p_ship_id: String, p_good_id: String, p_quantity: int) -> void:
	trader_id = p_trader_id
	ship_id = p_ship_id
	good_id = p_good_id
	quantity = p_quantity


## Checks everything buy and sell have in common. Returns "" if the trade may proceed.
func validate_trade(sim: Simulation) -> String:
	var ship := Command.find_ship(sim, trader_id, ship_id)
	if ship == null:
		return "unknown ship '%s'" % ship_id
	if not ship.is_docked():
		return "%s is at sea" % ship.name
	if not sim.data.has_good(good_id):
		return "unknown good '%s'" % good_id
	if quantity <= 0:
		return "quantity must be positive"
	return ""


func ship(sim: Simulation) -> ShipState:
	return Command.find_ship(sim, trader_id, ship_id)


func trader(sim: Simulation) -> TraderState:
	return sim.world.get_trader(trader_id)


## The market the ship trades with. Only valid once validate_trade() passed.
func market(sim: Simulation) -> CityState:
	return sim.world.get_city(ship(sim).docked_at)
