class_name WorkshopDef
extends RefCounted
## A workshop type a trader can build in a city where they own a kontor (data/buildings.json).
## Each day it pays its workers and, if the kontor holds the inputs, turns them into its output.

var id: String
var name: String
## Good id produced.
var output: String
## Whole units produced per working day.
var output_per_day: int
## Whole units of each input good used per working day, by good id.
var inputs: Dictionary[String, int]
## Workers taken from the city's workforce while the workshop exists.
var workers: int
## One-off coins to build.
var build_cost: int
## Coins paid every day; a workshop whose owner cannot pay stays idle that day.
var wages_per_day: int


func _init(
	p_id: String,
	p_name: String,
	p_output: String,
	p_output_per_day: int,
	p_inputs: Dictionary[String, int],
	p_workers: int,
	p_build_cost: int,
	p_wages_per_day: int,
) -> void:
	id = p_id
	name = p_name
	output = p_output
	output_per_day = p_output_per_day
	inputs = p_inputs
	workers = p_workers
	build_cost = p_build_cost
	wages_per_day = p_wages_per_day
