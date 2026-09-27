class_name CityState
extends RefCounted
## Mutable economic state of one city. The rules that change it live in sim/systems.
##
## Every dictionary has an entry for every good in GameData, created by Simulation.new_game().

var id: String
var population: int
## Units in the city market, by good id. Never negative.
var stock: Dictionary[String, int] = {}
## Fractions of a unit carried to the next day, so fractional daily rates add up exactly.
var production_carry: Dictionary[String, float] = {}
var consumption_carry: Dictionary[String, float] = {}
## Units the population wanted but could not get on the last day, by good id.
var shortage: Dictionary[String, int] = {}


func _init(p_id: String, p_population: int) -> void:
	id = p_id
	population = p_population
