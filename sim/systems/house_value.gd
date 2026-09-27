class_name HouseValue
extends RefCounted
## What a trading house is worth, for comparing the player with the rivals. A read-only query.
##
## Net worth = coins + ships at their resale value + kontors and workshops at what they cost +
## goods in ships and kontors at base price. Market prices are left out on purpose: the figure
## shouldn't jump when a ship docks in a dear market.


static func net_worth(data: GameData, trader: TraderState) -> int:
	var worth := trader.coins
	for ship in trader.ships:
		worth += SellShipCommand.resale_price(data, data.get_ship(ship.type_id))
		worth += goods_value(data, ship)
	for kontor in trader.kontors_in_order(data.cities):
		worth += data.kontor.price + goods_value(data, kontor)
		for workshop in kontor.workshops:
			worth += data.get_workshop(workshop.type_id).build_cost
	return worth


## The goods in a ship or kontor at base price.
static func goods_value(data: GameData, hold: Hold) -> int:
	var value := 0
	for good in data.goods:
		value += hold.cargo_of(good.id) * good.base_price
	return value
