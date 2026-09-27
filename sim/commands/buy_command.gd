class_name BuyCommand
extends TradeCommand
## Buys goods from the market of the city a ship is docked in and loads them onto that ship.


func validate(sim: Simulation) -> String:
	var error := validate_trade(sim)
	if not error.is_empty():
		return error
	var good := sim.data.get_good(good_id)
	var city := market(sim)
	var boat := ship(sim)
	var room := sim.data.get_ship(boat.type_id).capacity - boat.cargo_total()
	var cost := CityEconomy.buy_cost(
		sim.data.economy, city, good, mini(quantity, city.stock[good_id])
	)
	if quantity > city.stock[good_id]:
		var city_name := sim.data.get_city(city.id).name
		error = "%s has only %d %s" % [city_name, city.stock[good_id], good.name]
	elif quantity > room:
		error = "%s has room for only %d more units" % [boat.name, room]
	elif cost > trader(sim).coins:
		error = "%d %s cost %d coins, you have %d" % [quantity, good.name, cost, trader(sim).coins]
	return error


func apply(sim: Simulation) -> void:
	var city := market(sim)
	var cost := CityEconomy.buy_cost(sim.data.economy, city, sim.data.get_good(good_id), quantity)
	trader(sim).coins -= cost
	city.stock[good_id] -= quantity
	ship(sim).change_cargo(good_id, quantity)
