class_name TraderState
extends RefCounted
## A trading house: the player now, AI competitors later. Both act only through commands.

var id: String
var name: String
## Never negative.
var coins: int
var ships: Array[ShipState] = []


func _init(p_id: String, p_name: String, p_coins: int) -> void:
	id = p_id
	name = p_name
	coins = p_coins


## Returns null if this trader has no ship with that id.
func get_ship(ship_id: String) -> ShipState:
	for ship in ships:
		if ship.id == ship_id:
			return ship
	return null
