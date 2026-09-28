class_name RankDef
extends RefCounted
## One rank of a trading house (ADR 0015), loaded from data/ranks.json. Ranks are in ascending
## order; a house holds the highest one it has ever qualified for.

## Things a rank can unlock, as named in data/ranks.json "unlocks".
const ROUTES: String = "routes"
const FACTORS: String = "factors"
const BUY_ASSETS: String = "buy_assets"
const BUY_OUT_HOUSES: String = "buy_out_houses"
const UNLOCKS: PackedStringArray = [ROUTES, FACTORS, BUY_ASSETS, BUY_OUT_HOUSES]

## The fields of its entry in data/ranks.json.
const FIELDS: PackedStringArray = [
	"id",
	"name",
	"net_worth",
	"standing_cities",
	"richest",
	"max_ships",
	"max_kontors",
	"unlocks",
]

var id: String
var name: String
## Net worth (HouseValue) needed.
var net_worth: int
## Cities where the house needs at least the standing reputation.
var standing_cities: int
## True if the house must also be the richest of all houses.
var richest: bool
## Most ships and kontors a house of this rank may own; 0 means no limit.
var max_ships: int
var max_kontors: int
## What this rank adds; higher ranks keep everything lower ranks unlocked.
var unlocks: PackedStringArray


func _init(
	p_id: String,
	p_name: String,
	p_net_worth: int,
	p_standing_cities: int,
	p_richest: bool,
	p_max_ships: int,
	p_max_kontors: int,
	p_unlocks: PackedStringArray,
) -> void:
	id = p_id
	name = p_name
	net_worth = p_net_worth
	standing_cities = p_standing_cities
	richest = p_richest
	max_ships = p_max_ships
	max_kontors = p_max_kontors
	unlocks = p_unlocks
