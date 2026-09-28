class_name RivalDef
extends RefCounted
## A rival trading house run by the AI (data/rivals.json): who it is and how it starts. In game it
## is an ordinary TraderState with this id, acting only through commands (RivalSystem, ADR 0008).

var id: String
var name: String
## Shown on the map and in the houses list. Presentation only; the simulation never reads it.
var color: Color
## City the house starts in, and where it buys new ships.
var start_city: String
var coins: int
var ships: Array[ScenarioDef.StartingShip] = []
## First save version whose world has this entry (data "since_save", default 1). Saves from before
## it get the entry added as a new game starts it; later saves must contain it (SaveGame).
var since_save: int = 1


func _init(
	p_id: String,
	p_name: String,
	p_color: Color,
	p_start_city: String,
	p_coins: int,
	p_ships: Array[ScenarioDef.StartingShip],
) -> void:
	id = p_id
	name = p_name
	color = p_color
	start_city = p_start_city
	coins = p_coins
	ships = p_ships
