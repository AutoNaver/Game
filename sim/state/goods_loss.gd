class_name GoodsLoss
extends RefCounted
## Goods a trader lost on the last day, to spoilage or to an event (ADR 0006). Kept only until the
## next day's run and not saved: it exists so the UI can announce losses, which the goods ledger
## has already booked.

const SPOILAGE: String = "spoilage"

var trader_id: String
## A ship id, or the city id of a kontor.
var hold_id: String
var good_id: String
var units: int
## SPOILAGE, or the id of the event type that caused it.
var cause: String


func _init(
	p_trader_id: String, p_hold_id: String, p_good_id: String, p_units: int, p_cause: String
) -> void:
	trader_id = p_trader_id
	hold_id = p_hold_id
	good_id = p_good_id
	units = p_units
	cause = p_cause
