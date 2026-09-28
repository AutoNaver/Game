class_name ReputationDef
extends RefCounted
## How a house earns and loses reputation in a city (ADR 0015), from data/ranks.json. Reputation
## is whole points from 0 to `max`.

## The fields of its entry in data/ranks.json.
const FIELDS: PackedStringArray = [
	"max",
	"standing",
	"kontor_abroad",
	"per_shortage_unit",
	"per_kontor_day",
	"per_workshop_day",
	"per_idle_workshop_day",
]

var max: int
## Reputation that counts a city towards a rank's standing_cities.
var standing: int
## Reputation needed to buy a kontor outside the house's home city.
var kontor_abroad: int
## Points per unit sold while the city holds less than its target stock of the good.
var per_shortage_unit: int
## Points per day for holding a kontor, and per workshop that worked that day.
var per_kontor_day: int
var per_workshop_day: int
## Points lost per day for each workshop that stood idle (unpaid, no inputs, or kontor full).
var per_idle_workshop_day: int


func _init(
	p_max: int,
	p_standing: int,
	p_kontor_abroad: int,
	p_per_shortage_unit: int,
	p_per_kontor_day: int,
	p_per_workshop_day: int,
	p_per_idle_workshop_day: int,
) -> void:
	max = p_max
	standing = p_standing
	kontor_abroad = p_kontor_abroad
	per_shortage_unit = p_per_shortage_unit
	per_kontor_day = p_per_kontor_day
	per_workshop_day = p_per_workshop_day
	per_idle_workshop_day = p_per_idle_workshop_day
