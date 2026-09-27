class_name BuildWorkshopCommand
extends Command
## Builds a workshop next to the trader's kontor in a city. It hires workers from the city's
## workforce and starts working on the next day (WorkshopSystem).

var trader_id: String
var city_id: String
var workshop_type_id: String


func _init(p_trader_id: String, p_city_id: String, p_workshop_type_id: String) -> void:
	trader_id = p_trader_id
	city_id = p_city_id
	workshop_type_id = p_workshop_type_id


func validate(sim: Simulation) -> String:
	var trader := sim.world.get_trader(trader_id)
	if trader == null:
		return "unknown trader '%s'" % trader_id
	if trader.get_kontor(city_id) == null:
		return "You need a kontor in %s first" % Command.city_name(sim, city_id)
	var workshop_type := sim.data.get_workshop(workshop_type_id)
	if workshop_type == null:
		return "unknown workshop type '%s'" % workshop_type_id
	return _check_costs(sim, trader, workshop_type)


func apply(sim: Simulation) -> void:
	var trader := sim.world.get_trader(trader_id)
	trader.coins -= sim.data.get_workshop(workshop_type_id).build_cost
	sim.world.add_workshop(trader.get_kontor(city_id), workshop_type_id)


func _check_costs(sim: Simulation, trader: TraderState, workshop_type: WorkshopDef) -> String:
	if workshop_type.build_cost > trader.coins:
		var costs := [workshop_type.name, workshop_type.build_cost, trader.coins]
		return "A %s costs %d coins, you have %d" % costs
	var free := CityEconomy.free_workers(sim.data, sim.world, sim.world.get_city(city_id))
	if workshop_type.workers > free:
		var needs := [
			workshop_type.name, workshop_type.workers, Command.city_name(sim, city_id), free
		]
		return "A %s needs %d workers; %s has only %d free" % needs
	return ""
