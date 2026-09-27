class_name EconomyDef
extends RefCounted
## Global economy tuning, loaded from data/economy.json. See ADR 0003 for how the values are used.

## A city's target stock of a good is this many days of its consumption.
var days_of_cover: int
## Cities stop producing a good once their stock reaches target × this factor.
var stock_cap_factor: float
## Price multiplier on base price when the market is empty.
var price_max_multiplier: float
## Lowest price multiplier, reached when the market is flooded.
var price_min_multiplier: float
## Gap between buy and sell price as a fraction of the mid price (0.1 = ±5%).
var spread: float


func _init(
	p_days_of_cover: int,
	p_stock_cap_factor: float,
	p_price_max_multiplier: float,
	p_price_min_multiplier: float,
	p_spread: float,
) -> void:
	days_of_cover = p_days_of_cover
	stock_cap_factor = p_stock_cap_factor
	price_max_multiplier = p_price_max_multiplier
	price_min_multiplier = p_price_min_multiplier
	spread = p_spread
