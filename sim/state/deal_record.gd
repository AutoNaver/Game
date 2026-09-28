class_name DealRecord
extends RefCounted
## One completed deal between houses, for the UI's news (ADR 0016). Kept for DEAL_LOG_DAYS and not
## saved: the deal itself is in the ownership it changed.

const DEAL_LOG_DAYS: int = 30

## Numbered in the order deals happen, so the UI can tell which it has already reported.
var number: int
var day: int
var buyer_id: String
var seller_id: String
## True when the buyer took over the whole selling house; kind and asset_id are then unused.
var buy_out: bool
var kind: OfferState.Kind
var asset_id: String
var price: int


func _init(
	p_number: int,
	p_day: int,
	p_buyer_id: String,
	p_seller_id: String,
	p_buy_out: bool,
	p_kind: OfferState.Kind,
	p_asset_id: String,
	p_price: int,
) -> void:
	number = p_number
	day = p_day
	buyer_id = p_buyer_id
	seller_id = p_seller_id
	buy_out = p_buy_out
	kind = p_kind
	asset_id = p_asset_id
	price = p_price
