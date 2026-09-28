class_name DealsPanel
extends VBoxContainer
## Deals with other houses (ADR 0016), inside the houses panel: the rivals' offers for the
## player's ships and kontors with Accept and Refuse, and for the house picked with its Deal button,
## its ships and kontors at their asking price and buying out the whole house. Every button goes
## through its command; one that can't be done now is disabled with the reason as its tooltip.

var _session: GameSession
var _house_id: String = ""
var _offers: VBoxContainer = VBoxContainer.new()
var _deals: VBoxContainer = VBoxContainer.new()


func setup(session: GameSession) -> void:
	_session = session
	_offers.name = "Offers"
	add_child(_offers)
	_deals.name = "Deals"
	add_child(_deals)


## Shows the deals with house `house_id`; the same id again hides them.
func show_house(house_id: String) -> void:
	_house_id = "" if house_id == _house_id else house_id
	refresh()


func refresh() -> void:
	_clear(_offers)
	_clear(_deals)
	var world := _session.sim.world
	if not world.offers.is_empty():
		_offers.add_child(UiStyle.label("Offers for your assets", UiStyle.HEADER_LABEL))
	for offer in world.offers:
		_offers.add_child(_offer_row(offer))
	var house := world.get_trader(_house_id)
	if house == null:
		_house_id = ""
		return
	var title := "Buy from %s" % house.name
	if house.bankrupt:
		title += " (bankrupt: sale until day %d)" % house.sale_end_day
	_deals.add_child(UiStyle.label(title, UiStyle.HEADER_LABEL))
	for ship in house.ships:
		_deals.add_child(_asset_row(house, OfferState.Kind.SHIP, ship.id))
	for kontor in house.kontors_in_order(_session.sim.data.cities):
		_deals.add_child(_asset_row(house, OfferState.Kind.KONTOR, kontor.city_id))
	if house.ships.is_empty() and house.kontors.is_empty():
		_deals.add_child(UiStyle.label("Nothing left to buy.", UiStyle.MUTED_LABEL))
	if not house.bankrupt:
		var command := BuyOutHouseCommand.new(WorldState.PLAYER_ID, house.id)
		var price := AcquisitionSystem.buy_out_price(_session.sim.data, house)
		_deals.add_child(
			_button("BuyOut_%s" % house.id, "Buy out %s (%d)" % [house.name, price], command)
		)


func _offer_row(offer: OfferState) -> HBoxContainer:
	var row := HBoxContainer.new()
	var buyer := _session.sim.world.get_trader(offer.buyer_id)
	var what := AcquisitionSystem.asset_name(
		_session.sim.data, _session.player(), offer.kind, offer.asset_id
	)
	var text := (
		"%s offers %d for %s (until day %d)" % [buyer.name, offer.price, what, offer.last_day + 1]
	)
	var label := UiStyle.label(text)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	row.add_child(label)
	row.add_child(_button("Accept_%s" % offer.id, "Accept", AnswerOfferCommand.new(offer.id, true)))
	row.add_child(
		_button("Refuse_%s" % offer.id, "Refuse", AnswerOfferCommand.new(offer.id, false))
	)
	return row


func _asset_row(house: TraderState, kind: OfferState.Kind, asset_id: String) -> HBoxContainer:
	var data := _session.sim.data
	var row := HBoxContainer.new()
	var text := AcquisitionSystem.asset_name(data, house, kind, asset_id)
	if kind == OfferState.Kind.SHIP:
		var ship := house.get_ship(asset_id)
		var where := data.get_city(ship.docked_at).name if ship.is_docked() else "at sea"
		text += ", %s, cargo %d" % [where, ship.cargo_total()]
	else:
		var kontor := house.get_kontor(asset_id)
		text += ", %d workshops, %d goods" % [kontor.workshops.size(), kontor.cargo_total()]
	var label := UiStyle.label(text.left(1).to_upper() + text.substr(1))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	row.add_child(label)
	var price := AcquisitionSystem.asking_price(data, house, kind, asset_id)
	var command := BuyAssetCommand.new(WorldState.PLAYER_ID, house.id, kind, asset_id)
	row.add_child(_button("BuyAsset_%s" % asset_id, "Buy (%d)" % price, command))
	return row


## A button that executes `command`, disabled with the reason if it can't be done now.
func _button(node_name: String, text: String, command: Command) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	var error := command.validate(_session.sim)
	button.disabled = not error.is_empty()
	button.tooltip_text = error
	button.pressed.connect(_execute.bind(command))
	return button


func _execute(command: Command) -> void:
	_session.execute(command)


func _clear(box: VBoxContainer) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()
