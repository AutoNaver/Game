class_name EventDef
extends RefCounted
## A kind of world event from data/events.json (ADR 0011). Each day every event type may start,
## with chance_per_day, in one city that it can hit and that it isn't already hitting; it lasts
## between min_days and max_days. What it does depends on its kind:
## - storm: ships sailing to or from the city move only every `slowdown`-th hour.
## - harvest_failure: the city's own production of `goods` is multiplied by `factor`.
## - war: the city's off-map imports are multiplied by `factor`.
## - fire: on its first day, `loss_share` of every good in the kontors there burns.

const STORM: String = "storm"
const HARVEST_FAILURE: String = "harvest_failure"
const WAR: String = "war"
const FIRE: String = "fire"
const KINDS: PackedStringArray = [STORM, HARVEST_FAILURE, WAR, FIRE]

var id: String
var name: String
var kind: String
## Probability that this event starts somewhere on a given day.
var chance_per_day: float
var min_days: int
var max_days: int
## Storms: ships affected advance one hour of their voyage every this many hours.
var slowdown: int = 1
## Harvest failures: the goods whose production is cut.
var goods: PackedStringArray = []
## Harvest failures (production) and wars (imports): the remaining share, 0..1.
var factor: float = 1.0
## Fires: the share of each good in the city's kontors that is lost.
var loss_share: float = 0.0


func _init(
	p_id: String,
	p_name: String,
	p_kind: String,
	p_chance_per_day: float,
	p_min_days: int,
	p_max_days: int,
) -> void:
	id = p_id
	name = p_name
	kind = p_kind
	chance_per_day = p_chance_per_day
	min_days = p_min_days
	max_days = p_max_days
