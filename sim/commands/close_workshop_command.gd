class_name CloseWorkshopCommand
extends Command
## Closes one of the trader's workshops: its workers go back to the city and no more wages are
## due. The build cost is not refunded; goods in the kontor stay there.

var trader_id: String
var city_id: String
var workshop_id: String


func _init(p_trader_id: String, p_city_id: String, p_workshop_id: String) -> void:
	trader_id = p_trader_id
	city_id = p_city_id
	workshop_id = p_workshop_id


func validate(sim: Simulation) -> String:
	var trader := sim.world.get_trader(trader_id)
	if trader == null:
		return "unknown trader '%s'" % trader_id
	var kontor := trader.get_kontor(city_id)
	if kontor == null:
		return "You have no kontor in %s" % Command.city_name(sim, city_id)
	if _index(kontor) < 0:
		return "unknown workshop '%s'" % workshop_id
	return ""


func apply(sim: Simulation) -> void:
	var kontor := sim.world.get_trader(trader_id).get_kontor(city_id)
	kontor.workshops.remove_at(_index(kontor))


func _index(kontor: KontorState) -> int:
	for i in kontor.workshops.size():
		if kontor.workshops[i].id == workshop_id:
			return i
	return -1
