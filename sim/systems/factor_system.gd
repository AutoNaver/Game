class_name FactorSystem
extends RefCounted
## Daily, after the rivals: each kontor's factor carries out its standing orders (ADR 0015) in
## order, through BuyCommand and SellCommand like any other trade. An order that can't be carried
## out today (no stock, no room, no coins, price beyond its limit) simply waits for tomorrow.


static func run_day(sim: Simulation) -> void:
	for trader in sim.world.traders:
		if trader.bankrupt:
			continue
		for kontor in trader.kontors_in_order(sim.data.cities):
			for order in kontor.factor_orders:
				var command := order_command(sim, trader, kontor, order)
				if command != null:
					sim.execute(command)


## The trade that carries out `order` today, or null if there is nothing to do.
static func order_command(
	sim: Simulation, trader: TraderState, kontor: KontorState, order: FactorOrder
) -> Command:
	var economy := sim.data.economy
	var city := sim.world.get_city(kontor.city_id)
	var good := sim.data.get_good(order.good_id)
	var held := kontor.cargo_of(good.id)
	var quantity := 0
	if order.action == FactorOrder.Action.BUY:
		var room := sim.data.kontor.capacity - kontor.cargo_total()
		var most := mini(order.amount - held, room)
		if most > 0:
			quantity = CityEconomy.affordable_quantity(
				economy, city, good, most, order.price_limit, trader.coins
			)
		if quantity > 0:
			return BuyCommand.for_kontor(trader.id, city.id, good.id, quantity)
		return null
	if held > order.amount:
		quantity = CityEconomy.sellable_quantity(
			economy, city, good, held - order.amount, order.price_limit
		)
	if quantity > 0:
		return SellCommand.for_kontor(trader.id, city.id, good.id, quantity)
	return null
