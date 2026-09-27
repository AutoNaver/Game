class_name WorkshopState
extends RefCounted
## One workshop a trader built next to their kontor. What it makes comes from its WorkshopDef.

enum Status { NEW, WORKED, NO_INPUTS, KONTOR_FULL, UNPAID }

var id: String
var type_id: String
## How the last working day went, for the UI. NEW until its first day has passed.
var status: Status = Status.NEW
## For NO_INPUTS: the first input good that was short.
var missing_good: String = ""
## Share of the next batch done, in millionths (0..PARTS_PER_UNIT). A fully staffed workshop
## finishes a batch every day; an understaffed one adds its staffing each day and makes a batch
## whenever this reaches a whole one (WorkshopSystem).
var progress: int = 0


func _init(p_id: String, p_type_id: String) -> void:
	id = p_id
	type_id = p_type_id
