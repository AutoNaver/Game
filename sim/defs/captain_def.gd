class_name CaptainDef
extends RefCounted
## Balance for tavern recruitment, pay and experience.

var daily_wage: int
var tavern_pool_size: int
var hiring_fee: int
var seamanship_hours_per_level: int
var voyages_per_level: int
var max_skill: int
var bankruptcy_grace_days: int


func _init(
	p_daily_wage: int,
	p_tavern_pool_size: int,
	p_hiring_fee: int,
	p_seamanship_hours_per_level: int,
	p_voyages_per_level: int,
	p_max_skill: int,
	p_bankruptcy_grace_days: int,
) -> void:
	daily_wage = p_daily_wage
	tavern_pool_size = p_tavern_pool_size
	hiring_fee = p_hiring_fee
	seamanship_hours_per_level = p_seamanship_hours_per_level
	voyages_per_level = p_voyages_per_level
	max_skill = p_max_skill
	bankruptcy_grace_days = p_bankruptcy_grace_days
