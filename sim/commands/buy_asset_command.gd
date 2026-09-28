class_name BuyAssetCommand
extends Command
## Buys one of another house's ships (with its captain and cargo) or kontors (with its workshops
## and goods) at the asking price (ADR 0016). A rival sells only if it agrees; the player sells
## only by accepting a rival's offer. Buying from a solvent house needs a rank that unlocks it; a
## bankrupt house's sale is open to every rank at a discount. The buyer's rank limits and a
## kontor's reputation rule apply as for new ships and kontors.

var buyer_id: String
var seller_id: String
var kind: OfferState.Kind
## A ship id for SHIP, a city id for KONTOR.
var asset_id: String


func _init(
	p_buyer_id: String, p_seller_id: String, p_kind: OfferState.Kind, p_asset_id: String
) -> void:
	buyer_id = p_buyer_id
	seller_id = p_seller_id
	kind = p_kind
	asset_id = p_asset_id


func validate(sim: Simulation) -> String:
	var buyer := sim.world.get_trader(buyer_id)
	var seller := sim.world.get_trader(seller_id)
	var error := ""
	if buyer == null or seller == null:
		error = "unknown trader '%s'" % (buyer_id if buyer == null else seller_id)
	elif buyer == seller:
		error = "A house can't buy from itself"
	elif buyer.bankrupt:
		error = "%s is bankrupt" % AcquisitionSystem.house_name(buyer)
	elif seller.id == WorldState.PLAYER_ID:
		error = "The player sells only by accepting offers"
	else:
		error = AcquisitionSystem.asset_error(sim.data, seller, kind, asset_id)
	if error.is_empty() and not seller.bankrupt:
		error = RankSystem.unlock_error(
			sim.data, buyer, RankDef.BUY_ASSETS, "Purchases from other houses"
		)
	if error.is_empty():
		error = AcquisitionSystem.take_error(sim.data, buyer, seller, kind, asset_id)
	if error.is_empty():
		error = _price_error(sim, buyer, seller)
	if error.is_empty():
		error = AcquisitionSystem.refusal(sim, seller, kind, asset_id)
	return error


func _price_error(sim: Simulation, buyer: TraderState, seller: TraderState) -> String:
	var price := AcquisitionSystem.asking_price(sim.data, seller, kind, asset_id)
	if price <= buyer.coins:
		return ""
	var what := AcquisitionSystem.asset_name(sim.data, seller, kind, asset_id)
	return (
		"%s costs %d coins, you have %d"
		% [what.left(1).to_upper() + what.substr(1), price, buyer.coins]
	)


func apply(sim: Simulation) -> void:
	var seller := sim.world.get_trader(seller_id)
	var price := AcquisitionSystem.asking_price(sim.data, seller, kind, asset_id)
	AcquisitionSystem.sell_asset(sim, seller, sim.world.get_trader(buyer_id), kind, asset_id, price)
