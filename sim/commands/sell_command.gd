class_name SellCommand
extends TradeCommand
## Sells goods from a ship's cargo to the market of the city the ship is docked in.


func validate(sim: Simulation) -> String:
	var error := validate_trade(sim)
	if not error.is_empty():
		return error
	var boat := _ship(sim)
	if quantity > boat.cargo_of(good_id):
		var good_name := sim.data.get_good(good_id).name
		return "%s carries only %d %s" % [boat.name, boat.cargo_of(good_id), good_name]
	return ""


func apply(sim: Simulation) -> void:
	var city := _market(sim)
	var good := sim.data.get_good(good_id)
	_trader(sim).coins += CityEconomy.sell_revenue(sim.data.economy, city, good, quantity)
	city.stock[good_id] += quantity
	_ship(sim).change_cargo(good_id, -quantity)
