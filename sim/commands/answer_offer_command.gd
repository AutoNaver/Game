class_name AnswerOfferCommand
extends Command
## The player accepts or refuses a rival's offer for one of their ships or kontors (ADR 0016).
## Accepting sells at the offered price if the deal can still happen: the asset is still the
## player's and free to go, and the rival can still take it and pay. Either answer ends the offer.

var offer_id: String
var accept: bool


func _init(p_offer_id: String, p_accept: bool) -> void:
	offer_id = p_offer_id
	accept = p_accept


func validate(sim: Simulation) -> String:
	var offer := find_offer(sim.world, offer_id)
	if offer == null:
		return "unknown offer '%s'" % offer_id
	if not accept:
		return ""
	var player := sim.world.player()
	var buyer := sim.world.get_trader(offer.buyer_id)
	var error := ""
	if buyer == null or buyer.bankrupt:
		error = "%s can no longer buy" % (offer.buyer_id if buyer == null else buyer.name)
	else:
		error = AcquisitionSystem.asset_error(sim.data, player, offer.kind, offer.asset_id)
	if error.is_empty():
		error = AcquisitionSystem.take_error(sim.data, buyer, player, offer.kind, offer.asset_id)
	if error.is_empty() and offer.price > buyer.coins:
		error = "%s can no longer pay %d coins" % [buyer.name, offer.price]
	return error


func apply(sim: Simulation) -> void:
	var offer := find_offer(sim.world, offer_id)
	sim.world.offers.erase(offer)
	if accept:
		AcquisitionSystem.sell_asset(
			sim,
			sim.world.player(),
			sim.world.get_trader(offer.buyer_id),
			offer.kind,
			offer.asset_id,
			offer.price
		)


static func find_offer(world: WorldState, id: String) -> OfferState:
	for offer in world.offers:
		if offer.id == id:
			return offer
	return null
