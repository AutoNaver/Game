class_name KontorPanel
extends VBoxContainer
## The player's kontor in the selected city: the player's reputation there, buy one (locked with
## the reason when rank or reputation don't allow it), see its storage, move goods between it and
## a docked ship, build, watch and close workshops, and give its factor standing orders
## (ADR 0015). Uses the market panel's trade quantity.

const FACTOR_MODES: PackedStringArray = ["Off", "Buy up to", "Sell down to"]

var _session: GameSession
var _reputation: Label = Label.new()
var _buy_button: Button = Button.new()
var _buy_locked: Label = Label.new()
var _factor_locked: Label = Label.new()
var _factor_grid: GridContainer = GridContainer.new()
var _factor_save: Button = Button.new()
## The kontor and orders the factor grid was last filled from, so edits survive refreshes.
var _factor_key: String = ""
var _details: VBoxContainer = VBoxContainer.new()
var _storage: Label = Label.new()
var _transfers: GridContainer = GridContainer.new()
var _transfer_rows: Dictionary[String, Array] = {}
var _workforce: Label = Label.new()
var _workshop_list: VBoxContainer = VBoxContainer.new()
var _workshop_key: String = ""
## Rows (status label and Close button) for the shown kontor's workshops, in build order. Kept as
## references because queued deletions of old rows stay in the tree until the frame ends.
var _workshop_rows: Array[HBoxContainer] = []
var _build_buttons: Dictionary[String, Button] = {}


func setup(session: GameSession) -> void:
	_session = session
	add_child(UiStyle.label("Kontor", UiStyle.HEADER_LABEL))
	_reputation.name = "Reputation"
	_reputation.theme_type_variation = UiStyle.MUTED_LABEL
	_reputation.autowrap_mode = TextServer.AUTOWRAP_WORD
	add_child(_reputation)
	_buy_button.name = "BuyKontor"
	_buy_button.pressed.connect(_buy_kontor)
	add_child(_buy_button)
	_buy_locked.name = "KontorLocked"
	_buy_locked.theme_type_variation = UiStyle.MUTED_LABEL
	_buy_locked.autowrap_mode = TextServer.AUTOWRAP_WORD
	add_child(_buy_locked)
	add_child(_details)
	_storage.name = "KontorStorage"
	_storage.theme_type_variation = UiStyle.MUTED_LABEL
	_details.add_child(_storage)
	_build_transfer_grid()
	_details.add_child(UiStyle.label("Workshops", UiStyle.HEADER_LABEL))
	_workforce.name = "Workforce"
	_workforce.theme_type_variation = UiStyle.MUTED_LABEL
	_workforce.autowrap_mode = TextServer.AUTOWRAP_WORD
	_details.add_child(_workforce)
	_details.add_child(_workshop_list)
	var build_row := HFlowContainer.new()
	build_row.add_child(UiStyle.label("Build:", UiStyle.MUTED_LABEL))
	for workshop_type in _session.sim.data.workshops:
		var button := Button.new()
		button.name = "Build_%s" % workshop_type.id
		button.text = "%s (%d)" % [workshop_type.name, workshop_type.build_cost]
		button.tooltip_text = _describe_type(workshop_type)
		button.pressed.connect(_build.bind(workshop_type.id))
		build_row.add_child(button)
		_build_buttons[workshop_type.id] = button
	_details.add_child(build_row)
	_build_factor()
	_session.changed.connect(refresh)
	refresh()


func refresh() -> void:
	var data := _session.sim.data
	var player := _session.player()
	var kontor := player.get_kontor(_session.selected_city)
	var points := ReputationSystem.of(player, _session.selected_city)
	_reputation.text = (
		"Your reputation here: %d (standing from %d)" % [points, data.reputation.standing]
	)
	_buy_button.visible = kontor == null
	_details.visible = kontor != null
	var locked := (
		"" if kontor != null else RankSystem.kontor_error(data, player, _session.selected_city)
	)
	_buy_locked.visible = not locked.is_empty()
	_buy_locked.text = "Locked: %s" % locked
	if kontor == null:
		var terms := [data.kontor.price, data.kontor.capacity]
		_buy_button.text = "Buy a kontor here (%d coins, holds %d)" % terms
		_buy_button.disabled = not locked.is_empty() or player.coins < data.kontor.price
		_buy_button.tooltip_text = locked
		return
	_storage.text = "Storage %d/%d" % [kontor.cargo_total(), data.kontor.capacity]
	_refresh_transfers(kontor)
	var city := _session.sim.world.get_city(_session.selected_city)
	var free := CityEconomy.free_workers(data, _session.sim.world, city)
	var staffing := CityEconomy.staffing(data, _session.sim.world, city)
	if staffing < CityEconomy.PARTS_PER_UNIT:
		var percent := roundi(staffing * 100.0 / CityEconomy.PARTS_PER_UNIT)
		_workforce.text = (
			"Short of workers: workshops here are %d%% staffed, so they work and pay slower"
			% percent
		)
		_workforce.modulate = UiStyle.WARNING
	else:
		_workforce.text = "Free workers: %d" % free
		_workforce.modulate = Color.WHITE
	_refresh_workshops(kontor)
	for workshop_type in data.workshops:
		_build_buttons[workshop_type.id].disabled = (
			_session.player().coins < workshop_type.build_cost or free < workshop_type.workers
		)
	_refresh_factor(kontor)


func _build_factor() -> void:
	_details.add_child(UiStyle.label("Factor", UiStyle.HEADER_LABEL))
	_factor_locked.name = "FactorLocked"
	_factor_locked.theme_type_variation = UiStyle.MUTED_LABEL
	_factor_locked.autowrap_mode = TextServer.AUTOWRAP_WORD
	_details.add_child(_factor_locked)
	_factor_grid.name = "FactorOrders"
	_factor_grid.columns = 4
	_factor_grid.add_theme_constant_override("h_separation", 6)
	for heading: String in ["Good", "Order", "Units", "Price limit"]:
		_factor_grid.add_child(UiStyle.label(heading, UiStyle.MUTED_LABEL))
	for good in _session.sim.data.goods:
		_factor_grid.add_child(UiStyle.label(good.name))
		var mode := OptionButton.new()
		mode.name = "FactorMode_%s" % good.id
		for text in FACTOR_MODES:
			mode.add_item(text)
		_factor_grid.add_child(mode)
		var amount := SpinBox.new()
		amount.name = "FactorAmount_%s" % good.id
		amount.max_value = _session.sim.data.kontor.capacity
		amount.tooltip_text = "Buy until the kontor holds this many, or sell down to this many"
		_factor_grid.add_child(amount)
		var limit := SpinBox.new()
		limit.name = "FactorLimit_%s" % good.id
		limit.max_value = 100_000
		limit.tooltip_text = "Most paid or least taken per unit; 0 means any price"
		_factor_grid.add_child(limit)
	_details.add_child(_factor_grid)
	_factor_save.name = "SaveFactor"
	_factor_save.text = "Give the factor these orders"
	_factor_save.tooltip_text = "The factor trades once a day at the kontor's market"
	_factor_save.pressed.connect(_save_factor)
	_details.add_child(_factor_save)


func _refresh_factor(kontor: KontorState) -> void:
	var locked := RankSystem.unlock_error(
		_session.sim.data, _session.player(), RankDef.FACTORS, "Factors"
	)
	_factor_locked.visible = not locked.is_empty()
	_factor_locked.text = "Locked: %s" % locked
	_factor_grid.visible = locked.is_empty()
	_factor_save.visible = locked.is_empty()
	var parts := PackedStringArray([kontor.city_id])
	for order in kontor.factor_orders:
		parts.append("%d:%s:%d:%d" % [order.action, order.good_id, order.amount, order.price_limit])
	var key := ",".join(parts)
	if key == _factor_key:
		return
	_factor_key = key
	for good in _session.sim.data.goods:
		var mode := _factor_grid.get_node("FactorMode_%s" % good.id) as OptionButton
		mode.select(0)
		(_factor_grid.get_node("FactorAmount_%s" % good.id) as SpinBox).value = 0
		(_factor_grid.get_node("FactorLimit_%s" % good.id) as SpinBox).value = 0
	for order in kontor.factor_orders:
		var mode := _factor_grid.get_node("FactorMode_%s" % order.good_id) as OptionButton
		mode.select(1 if order.action == FactorOrder.Action.BUY else 2)
		(_factor_grid.get_node("FactorAmount_%s" % order.good_id) as SpinBox).value = order.amount
		(_factor_grid.get_node("FactorLimit_%s" % order.good_id) as SpinBox).value = (
			order.price_limit
		)


func _save_factor() -> void:
	var orders: Array[FactorOrder] = []
	for good in _session.sim.data.goods:
		var mode := (_factor_grid.get_node("FactorMode_%s" % good.id) as OptionButton).selected
		if mode <= 0:
			continue
		var action := FactorOrder.Action.BUY if mode == 1 else FactorOrder.Action.SELL
		var amount := int((_factor_grid.get_node("FactorAmount_%s" % good.id) as SpinBox).value)
		var limit := int((_factor_grid.get_node("FactorLimit_%s" % good.id) as SpinBox).value)
		orders.append(FactorOrder.new(action, good.id, amount, limit))
	_session.execute(
		SetFactorOrdersCommand.new(WorldState.PLAYER_ID, _session.selected_city, orders)
	)


func _build_transfer_grid() -> void:
	_transfers.name = "Transfers"
	_transfers.columns = 5
	_transfers.add_theme_constant_override("h_separation", 10)
	for heading: String in ["Good", "Ship", "Kontor", "", ""]:
		_transfers.add_child(UiStyle.label(heading, UiStyle.MUTED_LABEL))
	for good in _session.sim.data.goods:
		var name_label := UiStyle.label(good.name)
		# Labels ignore the mouse by default, which would hide the spoilage tooltip.
		name_label.mouse_filter = Control.MOUSE_FILTER_PASS
		var in_ship := Label.new()
		var in_kontor := Label.new()
		var unload := Button.new()
		unload.name = "Unload_%s" % good.id
		unload.text = "To kontor"
		unload.pressed.connect(_transfer.bind(good.id, true))
		var load := Button.new()
		load.name = "Load_%s" % good.id
		load.text = "To ship"
		load.pressed.connect(_transfer.bind(good.id, false))
		for control: Control in [name_label, in_ship, in_kontor, unload, load]:
			_transfers.add_child(control)
		_transfer_rows[good.id] = [name_label, in_ship, in_kontor, unload, load]
	_details.add_child(_transfers)


## Shows a row for every good in the kontor or aboard the docked ship.
func _refresh_transfers(kontor: KontorState) -> void:
	var ship := _session.trading_ship()
	for good in _session.sim.data.goods:
		var row: Array = _transfer_rows[good.id]
		var aboard := ship.cargo_of(good.id) if ship != null else 0
		var stored := kontor.cargo_of(good.id)
		(row[0] as Label).tooltip_text = _spoilage_text(good, stored)
		for control: Control in row:
			control.visible = aboard > 0 or stored > 0
		(row[1] as Label).text = str(aboard) if ship != null else "-"
		(row[2] as Label).text = str(stored)
		(row[3] as Button).disabled = aboard == 0
		(row[4] as Button).disabled = ship == null or stored == 0


## How fast `good` spoils in storage, and about how much of the `stored` units a day.
static func _spoilage_text(good: GoodDef, stored: int) -> String:
	if good.spoilage_per_day <= 0.0:
		return "%s keeps in storage." % good.name
	var parts := [good.name, good.spoilage_per_day * 100.0, SpoilageSystem.daily_loss(good, stored)]
	return "%s spoils %.1f%% a day: about %.1f a day of what is stored here." % parts


func _refresh_workshops(kontor: KontorState) -> void:
	# Workshop ids, not just the count: a loaded game can hold different workshops, and the Close
	# buttons are bound to ids.
	var ids := PackedStringArray()
	for workshop in kontor.workshops:
		ids.append(workshop.id)
	var key := "%s:%s" % [kontor.city_id, ",".join(ids)]
	if key != _workshop_key:
		_workshop_key = key
		for row in _workshop_rows:
			_workshop_list.remove_child(row)
			row.queue_free()
		_workshop_rows.clear()
		for workshop in kontor.workshops:
			var row := HBoxContainer.new()
			var label := Label.new()
			label.name = "Workshop_%s" % workshop.id
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(label)
			var close := Button.new()
			close.name = "Close_%s" % workshop.id
			close.text = "Close"
			close.tooltip_text = "Close the workshop: its workers leave and its wages stop. No refund."
			close.pressed.connect(_close.bind(workshop.id))
			row.add_child(close)
			_workshop_list.add_child(row)
			_workshop_rows.append(row)
	for i in kontor.workshops.size():
		var workshop := kontor.workshops[i]
		var workshop_type := _session.sim.data.get_workshop(workshop.type_id)
		var status := status_text(_session.sim.data, workshop)
		(_workshop_rows[i].get_child(0) as Label).text = "%s: %s" % [workshop_type.name, status]


## How the workshop's last day went, in words. Shared with the notification log.
static func status_text(data: GameData, workshop: WorkshopState) -> String:
	match workshop.status:
		WorkshopState.Status.WORKED:
			return "working"
		WorkshopState.Status.NO_INPUTS:
			return "idle, needs %s" % data.get_good(workshop.missing_good).name
		WorkshopState.Status.KONTOR_FULL:
			return "idle, kontor full"
		WorkshopState.Status.UNPAID:
			return "idle, wages unpaid"
	return "starts tomorrow"


func _describe_type(workshop_type: WorkshopDef) -> String:
	var data := _session.sim.data
	var inputs: PackedStringArray = []
	for good in data.goods:
		if workshop_type.inputs.has(good.id):
			inputs.append("%d %s" % [workshop_type.inputs[good.id], good.name])
	var output := data.get_good(workshop_type.output).name
	var parts := [
		", ".join(inputs),
		workshop_type.output_per_day,
		output,
		workshop_type.workers,
		workshop_type.wages_per_day,
	]
	return "Daily: %s -> %d %s. %d workers, wages %d a day." % parts


func _buy_kontor() -> void:
	_session.execute(BuyKontorCommand.new(WorldState.PLAYER_ID, _session.selected_city))


func _build(workshop_type_id: String) -> void:
	var command := BuildWorkshopCommand.new(
		WorldState.PLAYER_ID, _session.selected_city, workshop_type_id
	)
	_session.execute(command)


func _close(workshop_id: String) -> void:
	_session.execute(
		CloseWorkshopCommand.new(WorldState.PLAYER_ID, _session.selected_city, workshop_id)
	)


## Moves up to the trade quantity, limited by the source and the destination's free space.
func _transfer(good_id: String, to_kontor: bool) -> void:
	var ship := _session.trading_ship()
	var kontor := _session.player().get_kontor(_session.selected_city)
	if ship == null or kontor == null:
		return
	var data := _session.sim.data
	var from: Hold = ship if to_kontor else kontor
	var to: Hold = kontor if to_kontor else ship
	var capacity := data.kontor.capacity if to_kontor else data.get_ship(ship.type_id).capacity
	var quantity := mini(
		_session.trade_quantity, mini(from.cargo_of(good_id), capacity - to.cargo_total())
	)
	if quantity <= 0:
		_session.message_posted.emit("No room left")
		return
	_session.execute(
		TransferCommand.new(WorldState.PLAYER_ID, ship.id, good_id, quantity, to_kontor)
	)
