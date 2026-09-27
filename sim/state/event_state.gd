class_name EventState
extends RefCounted
## One running world event (EventSystem, ADR 0011): an EventDef hitting one city for a span of days.

## "event_<n>", numbered in the order events start.
var id: String
var type_id: String
var city_id: String
## First day the event is in effect (Simulation.day()).
var start_day: int
## First day it is over again.
var end_day: int


func _init(p_id: String, p_type_id: String, p_city_id: String, p_start: int, p_end: int) -> void:
	id = p_id
	type_id = p_type_id
	city_id = p_city_id
	start_day = p_start
	end_day = p_end


func is_active(day: int) -> bool:
	return start_day <= day and day < end_day
