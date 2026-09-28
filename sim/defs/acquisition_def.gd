class_name AcquisitionDef
extends RefCounted
## Prices and timing of deals between houses (ADR 0016), from data/acquisitions.json.

## The fields of data/acquisitions.json.
const FIELDS: PackedStringArray = [
	"asset_premium",
	"buy_out_premium",
	"buy_out_worth_factor",
	"bankruptcy_discount",
	"bankruptcy_sale_days",
	"offer_days",
	"offer_chance",
]

## A ship or kontor costs its value (HouseValue) times this.
var asset_premium: float
## A whole house costs its net worth times this.
var buy_out_premium: float
## A buyer must be worth at least this many times the house it buys out.
var buy_out_worth_factor: float
## A bankrupt house's assets sell at their value times this.
var bankruptcy_discount: float
## Days a bankrupt house's assets stay for sale before the rest is sold off.
var bankruptcy_sale_days: int
## Days a rival's offer to the player stands.
var offer_days: int
## Chance a rival that may buy assets makes the player an offer on one of its expansion days.
var offer_chance: float


func _init(
	p_asset_premium: float,
	p_buy_out_premium: float,
	p_buy_out_worth_factor: float,
	p_bankruptcy_discount: float,
	p_bankruptcy_sale_days: int,
	p_offer_days: int,
	p_offer_chance: float,
) -> void:
	asset_premium = p_asset_premium
	buy_out_premium = p_buy_out_premium
	buy_out_worth_factor = p_buy_out_worth_factor
	bankruptcy_discount = p_bankruptcy_discount
	bankruptcy_sale_days = p_bankruptcy_sale_days
	offer_days = p_offer_days
	offer_chance = p_offer_chance
