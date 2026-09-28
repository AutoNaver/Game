class_name SailCommand
extends Command
## Sends a docked ship to another city.

var trader_id: String
var ship_id: String
var destination: String


func _init(p_trader_id: String, p_ship_id: String, p_destination: String) -> void:
	trader_id = p_trader_id
	ship_id = p_ship_id
	destination = p_destination


func validate(sim: Simulation) -> String:
	var ship := Command.find_ship(sim, trader_id, ship_id)
	if ship == null:
		return "unknown ship '%s'" % ship_id
	if not ship.is_docked():
		return "%s is already at sea" % ship.name
	if ship.captain_id.is_empty():
		return "%s needs a captain to sail" % ship.name
	if not sim.data.has_city(destination):
		return "unknown city '%s'" % destination
	if destination == ship.docked_at:
		return "%s is already in %s" % [ship.name, sim.data.get_city(destination).name]
	return ""


func apply(sim: Simulation) -> void:
	var ship := Command.find_ship(sim, trader_id, ship_id)
	var captain := sim.world.get_trader(trader_id).get_captain(ship.captain_id)
	ship.news = MarketKnowledgeSystem.current_report(
		sim.data, sim.world.get_city(ship.docked_at), sim.day()
	)
	ship.origin = ship.docked_at
	ship.destination = destination
	ship.voyage_hours = CaptainSystem.voyage_hours(sim.data, ship, captain, destination)
	ship.hours_sailed = 0
	ship.docked_at = ""
