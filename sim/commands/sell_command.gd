class_name SellCommand
extends TradeCommand
## Sells goods from a docked ship, or from the trader's kontor, to that city's market.


## Sells from the trader's kontor in `p_city_id` instead of a ship.
static func for_kontor(
	p_trader_id: String, p_city_id: String, p_good_id: String, p_quantity: int
) -> SellCommand:
	var command := SellCommand.new(p_trader_id, "", p_good_id, p_quantity)
	command.city_id = p_city_id
	return command


func validate(sim: Simulation) -> String:
	var error := validate_trade(sim)
	if not error.is_empty():
		return error
	var hold := _hold(sim)
	if quantity > hold.cargo_of(good_id):
		var good_name := sim.data.get_good(good_id).name
		return "%s carries only %d %s" % [_hold_name(sim), hold.cargo_of(good_id), good_name]
	return ""


func apply(sim: Simulation) -> void:
	var city := _market(sim)
	var good := sim.data.get_good(good_id)
	var spread := CaptainSystem.trade_spread(sim.data, _trader(sim), ship_id)
	_trader(sim).coins += CityEconomy.sell_revenue(sim.data.economy, city, good, quantity, spread)
	city.stock[good_id] += quantity
	_hold(sim).change_cargo(good_id, -quantity)
