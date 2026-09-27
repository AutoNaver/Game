class_name BuyCommand
extends TradeCommand
## Buys goods from a city market into a docked ship, or into the trader's kontor there.


## Buys into the trader's kontor in `p_city_id` instead of a ship.
static func for_kontor(
	p_trader_id: String, p_city_id: String, p_good_id: String, p_quantity: int
) -> BuyCommand:
	var command := BuyCommand.new(p_trader_id, "", p_good_id, p_quantity)
	command.city_id = p_city_id
	return command


func validate(sim: Simulation) -> String:
	var error := validate_trade(sim)
	if not error.is_empty():
		return error
	var good := sim.data.get_good(good_id)
	var city := _market(sim)
	var room := _hold_capacity(sim) - _hold(sim).cargo_total()
	var cost := CityEconomy.buy_cost(
		sim.data.economy, city, good, mini(quantity, city.stock[good_id])
	)
	if quantity > city.stock[good_id]:
		var city_name := sim.data.get_city(city.id).name
		error = "%s has only %d %s" % [city_name, city.stock[good_id], good.name]
	elif quantity > room:
		error = "%s has room for only %d more units" % [_hold_name(sim), room]
	elif cost > _trader(sim).coins:
		error = "%d %s cost %d coins, you have %d" % [quantity, good.name, cost, _trader(sim).coins]
	return error


func apply(sim: Simulation) -> void:
	var city := _market(sim)
	var cost := CityEconomy.buy_cost(sim.data.economy, city, sim.data.get_good(good_id), quantity)
	_trader(sim).coins -= cost
	city.stock[good_id] -= quantity
	_hold(sim).change_cargo(good_id, quantity)
