class_name Hold
extends RefCounted
## A store of goods owned by a trader: a ship's cargo hold or a kontor's warehouse. Goods move
## between holds and markets only through commands; capacity comes from the owner's definition.

## Units stored by good id. Goods with zero units have no entry.
var cargo: Dictionary[String, int] = {}


func cargo_of(good_id: String) -> int:
	return cargo.get(good_id, 0)


func cargo_total() -> int:
	var total := 0
	for units: int in cargo.values():
		total += units
	return total


## Adds (or with a negative amount removes) goods, dropping entries that reach zero.
## Refuses to go below zero: returns false and changes nothing. Commands validate first.
func change_cargo(good_id: String, amount: int) -> bool:
	var units := cargo_of(good_id) + amount
	if units < 0:
		return false
	if units == 0:
		cargo.erase(good_id)
	else:
		cargo[good_id] = units
	return true
