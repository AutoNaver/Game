class_name MovePersonCommand
extends Command
## Moves the player between a docked ship and shore, or between ships in the same port.

var ship_id: String


func _init(p_ship_id: String = "") -> void:
	ship_id = p_ship_id


func validate(sim: Simulation) -> String:
	var player := sim.world.player()
	var city := player.person_city_id
	if not player.person_ship_id.is_empty():
		var current := player.get_ship(player.person_ship_id)
		if not current.is_docked():
			return "You cannot change ships at sea"
		city = current.docked_at
	if ship_id.is_empty():
		return "" if not player.person_ship_id.is_empty() else "You are already ashore"
	var target := player.get_ship(ship_id)
	if target == null:
		return "unknown ship '%s'" % ship_id
	if not target.is_docked() or target.docked_at != city:
		return "The ship must be in your port"
	if target.id == player.person_ship_id:
		return "You are already aboard %s" % target.name
	return ""


func apply(sim: Simulation) -> void:
	var player := sim.world.player()
	if ship_id.is_empty():
		player.person_city_id = player.get_ship(player.person_ship_id).docked_at
	player.person_ship_id = ship_id
	if not ship_id.is_empty():
		player.person_city_id = ""
