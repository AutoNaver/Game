class_name Command
extends RefCounted
## Base class for every action a trader can take. The UI and AI build commands and pass them to
## Simulation.execute(), which is the only way actions change the world.
##
## Subclasses implement validate() and apply(). validate() must not change anything; apply() may
## assume validate() just returned "".


## Returns "" if the command can be applied, otherwise a message for the player.
func validate(_sim: Simulation) -> String:
	return "command does not implement validate()"


func apply(_sim: Simulation) -> void:
	assert(false, "command does not implement apply()")


## A city's display name for messages, or its raw id if the city is unknown.
static func city_name(sim: Simulation, city_id: String) -> String:
	var city := sim.data.get_city(city_id)
	return city.name if city != null else "'%s'" % city_id


## Looks up a trader's ship, returning null if either does not exist.
static func find_ship(sim: Simulation, trader_id: String, ship_id: String) -> ShipState:
	var trader := sim.world.get_trader(trader_id)
	if trader == null:
		return null
	return trader.get_ship(ship_id)
