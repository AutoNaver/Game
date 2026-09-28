class_name CaptainState
extends RefCounted
## A hired sailor. A captain belongs to one house and commands at most one ship.

var id: String
var name: String
var wage: int
var seamanship: int = 0
var trading: int = 0
var voyages: int = 0
## Empty while waiting in a port for assignment.
var city_id: String = ""
## Empty while unassigned.
var ship_id: String = ""


func _init(p_id: String, p_name: String, p_wage: int, p_city_id: String = "") -> void:
	id = p_id
	name = p_name
	wage = p_wage
	city_id = p_city_id
