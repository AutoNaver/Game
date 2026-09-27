class_name ShipState
extends RefCounted
## One ship owned by a trader: either docked in a city or on a voyage between two cities.

var id: String
var type_id: String
var name: String
## Units aboard by good id. Goods with zero units have no entry.
var cargo: Dictionary[String, int] = {}
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


func cargo_of(good_id: String) -> int:
	return cargo.get(good_id, 0)


func cargo_total() -> int:
	var total := 0
	for units: int in cargo.values():
		total += units
	return total


## Adds (or with a negative amount removes) cargo, dropping entries that reach zero.
func change_cargo(good_id: String, amount: int) -> void:
	var units := cargo_of(good_id) + amount
	assert(units >= 0, "cargo of %s would go negative" % good_id)
	if units == 0:
		cargo.erase(good_id)
	else:
		cargo[good_id] = units
