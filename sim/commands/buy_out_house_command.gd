class_name BuyOutHouseCommand
extends Command
## Buys a whole rival house for its net worth times the buy-out premium (ADR 0016). Needs a rank
## that unlocks it and a net worth at least `buy_out_worth_factor` times the target's. The buyer
## takes over the house's coins, ships, captains, kontors and market knowledge, and the house
## leaves the game. The player's house is never for sale, and a bankrupt house sells its assets
## one by one instead.

var buyer_id: String
var target_id: String


func _init(p_buyer_id: String, p_target_id: String) -> void:
	buyer_id = p_buyer_id
	target_id = p_target_id


func validate(sim: Simulation) -> String:
	var buyer := sim.world.get_trader(buyer_id)
	var target := sim.world.get_trader(target_id)
	var error := ""
	if buyer == null or target == null:
		error = "unknown trader '%s'" % (buyer_id if buyer == null else target_id)
	elif target == buyer:
		error = "A house can't buy itself"
	elif buyer.bankrupt:
		error = "%s is bankrupt" % AcquisitionSystem.house_name(buyer)
	elif target.id == WorldState.PLAYER_ID:
		error = "Your house is not for sale"
	elif target.bankrupt:
		error = "%s is bankrupt: buy its ships and kontors instead" % target.name
	else:
		error = RankSystem.unlock_error(sim.data, buyer, RankDef.BUY_OUT_HOUSES, "Buy-outs")
	if error.is_empty():
		error = _worth_error(sim, buyer, target)
	return error


## "" if the buyer is worth enough and can pay, otherwise why not.
func _worth_error(sim: Simulation, buyer: TraderState, target: TraderState) -> String:
	var needed := ceili(
		HouseValue.net_worth(sim.data, target) * sim.data.acquisitions.buy_out_worth_factor
	)
	var worth := HouseValue.net_worth(sim.data, buyer)
	if worth < needed:
		return "Buying out %s needs a worth of %d (you have %d)" % [target.name, needed, worth]
	var price := AcquisitionSystem.buy_out_price(sim.data, target)
	if price > buyer.coins:
		return "Buying out %s costs %d coins, you have %d" % [target.name, price, buyer.coins]
	return ""


func apply(sim: Simulation) -> void:
	var target := sim.world.get_trader(target_id)
	var price := AcquisitionSystem.buy_out_price(sim.data, target)
	AcquisitionSystem.buy_out(sim, sim.world.get_trader(buyer_id), target, price)
