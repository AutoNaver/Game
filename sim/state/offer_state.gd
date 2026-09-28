class_name OfferState
extends RefCounted
## A rival's standing offer to buy one of the player's ships or kontors (ADR 0016). The player
## accepts or refuses it; it lapses after its last day.

## What a deal between houses is about: a ship (by ship id) or a kontor (by city id).
enum Kind { SHIP, KONTOR }

var id: String
var buyer_id: String
var kind: Kind
## A ship id for SHIP, a city id for KONTOR.
var asset_id: String
var price: int
## The last day the offer stands.
var last_day: int


func _init(
	p_id: String,
	p_buyer_id: String,
	p_kind: Kind,
	p_asset_id: String,
	p_price: int,
	p_last_day: int
) -> void:
	id = p_id
	buyer_id = p_buyer_id
	kind = p_kind
	asset_id = p_asset_id
	price = p_price
	last_day = p_last_day
