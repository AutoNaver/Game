class_name ShipState
extends Hold
## One ship owned by a trader: either docked in a city or on a voyage between two cities.
## Its cargo lives in the Hold it extends.

var id: String
var type_id: String
var name: String
## City the ship is docked in; empty while at sea.
var docked_at: String = ""
## The current voyage; only meaningful while at sea.
var origin: String = ""
var destination: String = ""
var voyage_hours: int = 0
var hours_sailed: int = 0


func _init(p_id: String, p_type_id: String, p_name: String, p_docked_at: String) -> void:
	id = p_id
	type_id = p_type_id
	name = p_name
	docked_at = p_docked_at


func is_docked() -> bool:
	return not docked_at.is_empty()
