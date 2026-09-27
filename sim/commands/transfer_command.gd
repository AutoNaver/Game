class_name TransferCommand
extends Command
## Moves goods between a docked ship and its owner's kontor in the same city.

var trader_id: String
var ship_id: String
var good_id: String
var quantity: int
## True: ship to kontor (unload). False: kontor to ship (load).
var to_kontor: bool


func _init(
	p_trader_id: String, p_ship_id: String, p_good_id: String, p_quantity: int, p_to_kontor: bool
) -> void:
	trader_id = p_trader_id
	ship_id = p_ship_id
	good_id = p_good_id
	quantity = p_quantity
	to_kontor = p_to_kontor


func validate(sim: Simulation) -> String:
	var ship := Command.find_ship(sim, trader_id, ship_id)
	if ship == null:
		return "unknown ship '%s'" % ship_id
	if not ship.is_docked():
		return "%s is at sea" % ship.name
	var kontor := sim.world.get_trader(trader_id).get_kontor(ship.docked_at)
	if kontor == null:
		return "You have no kontor in %s" % Command.city_name(sim, ship.docked_at)
	if not sim.data.has_good(good_id) or quantity <= 0:
		return "invalid goods or quantity"
	return _check_amounts(sim, ship, kontor)


func apply(sim: Simulation) -> void:
	var ship := Command.find_ship(sim, trader_id, ship_id)
	var kontor := sim.world.get_trader(trader_id).get_kontor(ship.docked_at)
	var from: Hold = ship if to_kontor else kontor
	var to: Hold = kontor if to_kontor else ship
	from.change_cargo(good_id, -quantity)
	to.change_cargo(good_id, quantity)


func _check_amounts(sim: Simulation, ship: ShipState, kontor: KontorState) -> String:
	var from: Hold = ship if to_kontor else kontor
	var to: Hold = kontor if to_kontor else ship
	var from_name := ship.name if to_kontor else "Your kontor"
	var to_name := "Your kontor" if to_kontor else ship.name
	var capacity := (
		sim.data.kontor.capacity if to_kontor else sim.data.get_ship(ship.type_id).capacity
	)
	var good_name := sim.data.get_good(good_id).name
	if quantity > from.cargo_of(good_id):
		return "%s holds only %d %s" % [from_name, from.cargo_of(good_id), good_name]
	if quantity > capacity - to.cargo_total():
		return "%s has room for only %d more units" % [to_name, capacity - to.cargo_total()]
	return ""
