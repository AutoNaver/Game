class_name RivalAiDef
extends RefCounted
## How the rival houses decide (data/rivals.json "ai"), shared by all of them. See ADR 0008.

## A ship picks its load at random among this many best options (by profit per day), weighted by
## profit per day, so rivals don't all chase the same trade.
var top_choices: int
## Coins a house keeps back when it buys ships, kontors and workshops.
var cash_reserve: int
## A house stops buying ships at this fleet size.
var max_ships: int
## A house stops buying kontors at this many.
var max_kontors: int
## A house considers expanding once every this many days.
var expansion_days: int
## Days of workshop inputs a house keeps in stock at each kontor.
var workshop_input_days: int
## A house doesn't buy workshop inputs dearer than this multiple of their base price.
var input_price_limit: float
## A house only builds a workshop if at least this share of the city's workforce stays free after
## it, so rivals never crowd the player out of a city's workers.
var keep_free_workers: float
## Chance that a ship leaving port sails for the city its house has the oldest report of (or none),
## to refresh its market book, instead of taking the best known trade. 0 when missing from data.
var explore_chance: float = 0.0


func _init(
	p_top_choices: int,
	p_cash_reserve: int,
	p_max_ships: int,
	p_max_kontors: int,
	p_expansion_days: int,
	p_workshop_input_days: int,
	p_input_price_limit: float,
	p_keep_free_workers: float,
) -> void:
	top_choices = p_top_choices
	cash_reserve = p_cash_reserve
	max_ships = p_max_ships
	max_kontors = p_max_kontors
	expansion_days = p_expansion_days
	workshop_input_days = p_workshop_input_days
	input_price_limit = p_input_price_limit
	keep_free_workers = p_keep_free_workers
