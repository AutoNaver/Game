class_name KontorPanel
extends VBoxContainer
## The player's kontor in the selected city: buy one, see its storage, move goods between it and a
## docked ship, and build and watch workshops. Uses the market panel's trade quantity.

var _session: GameSession
var _buy_button: Button = Button.new()
var _details: VBoxContainer = VBoxContainer.new()
var _storage: Label = Label.new()
var _transfers: GridContainer = GridContainer.new()
var _transfer_rows: Dictionary[String, Array] = {}
var _workforce: Label = Label.new()
var _workshop_list: VBoxContainer = VBoxContainer.new()
var _workshop_key: String = ""
var _build_buttons: Dictionary[String, Button] = {}


func setup(session: GameSession) -> void:
	_session = session
	add_child(UiStyle.label("Kontor", UiStyle.HEADER_LABEL))
	_buy_button.name = "BuyKontor"
	_buy_button.pressed.connect(_buy_kontor)
	add_child(_buy_button)
	add_child(_details)
	_storage.name = "KontorStorage"
	_storage.theme_type_variation = UiStyle.MUTED_LABEL
	_details.add_child(_storage)
	_build_transfer_grid()
	_details.add_child(UiStyle.label("Workshops", UiStyle.HEADER_LABEL))
	_workforce.name = "Workforce"
	_workforce.theme_type_variation = UiStyle.MUTED_LABEL
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
	_session.changed.connect(refresh)
	refresh()


func refresh() -> void:
	var data := _session.sim.data
	var kontor := _session.player().get_kontor(_session.selected_city)
	_buy_button.visible = kontor == null
	_details.visible = kontor != null
	if kontor == null:
		var terms := [data.kontor.price, data.kontor.capacity]
		_buy_button.text = "Buy a kontor here (%d coins, holds %d)" % terms
		_buy_button.disabled = _session.player().coins < data.kontor.price
		return
	_storage.text = "Storage %d/%d" % [kontor.cargo_total(), data.kontor.capacity]
	_refresh_transfers(kontor)
	var city := _session.sim.world.get_city(_session.selected_city)
	var free := CityEconomy.free_workers(data, _session.sim.world, city)
	_workforce.text = "Free workers: %d" % free
	_refresh_workshops(kontor)
	for workshop_type in data.workshops:
		_build_buttons[workshop_type.id].disabled = (
			_session.player().coins < workshop_type.build_cost or free < workshop_type.workers
		)


func _build_transfer_grid() -> void:
	_transfers.name = "Transfers"
	_transfers.columns = 5
	_transfers.add_theme_constant_override("h_separation", 10)
	for heading: String in ["Good", "Ship", "Kontor", "", ""]:
		_transfers.add_child(UiStyle.label(heading, UiStyle.MUTED_LABEL))
	for good in _session.sim.data.goods:
		var name_label := UiStyle.label(good.name)
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
		for control: Control in row:
			control.visible = aboard > 0 or stored > 0
		(row[1] as Label).text = str(aboard) if ship != null else "-"
		(row[2] as Label).text = str(stored)
		(row[3] as Button).disabled = aboard == 0
		(row[4] as Button).disabled = ship == null or stored == 0


func _refresh_workshops(kontor: KontorState) -> void:
	var key := "%s:%d" % [kontor.city_id, kontor.workshops.size()]
	if key != _workshop_key:
		_workshop_key = key
		for child in _workshop_list.get_children():
			child.queue_free()
		for workshop in kontor.workshops:
			var label := Label.new()
			label.name = "Workshop_%s" % workshop.id
			_workshop_list.add_child(label)
	for i in kontor.workshops.size():
		var workshop := kontor.workshops[i]
		var workshop_type := _session.sim.data.get_workshop(workshop.type_id)
		var label := _workshop_list.get_child(i) as Label
		label.text = "%s: %s" % [workshop_type.name, _status_text(workshop)]


func _status_text(workshop: WorkshopState) -> String:
	match workshop.status:
		WorkshopState.Status.WORKED:
			return "working"
		WorkshopState.Status.NO_INPUTS:
			return "idle, needs %s" % _session.sim.data.get_good(workshop.missing_good).name
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
