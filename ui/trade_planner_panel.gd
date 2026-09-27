class_name TradePlannerPanel
extends VBoxContainer
## "Cargo ideas": for the player's ship trading in the selected city, the best load to carry to
## each other city at today's prices (TradePlanner). "Load" buys it through the normal buy command;
## the player still chooses when and where to sail. "Cargo destinations" compares the sale value
## of goods already aboard, and its Sail button uses the ordinary command.

## Suggestions shown, best profit per day first.
const MAX_OPTIONS: int = 3
const MAX_DESTINATIONS: int = 3

var _session: GameSession
var _note: Label = Label.new()
var _rows: Array[HBoxContainer] = []
var _options: Array[TradePlanner.Option] = []
var _destination_rows: Array[HBoxContainer] = []
var _destinations: Array[CargoDestinationPlanner.Option] = []
var _destination_note: Label = Label.new()


func setup(session: GameSession) -> void:
	_session = session
	add_child(UiStyle.label("Cargo ideas", UiStyle.HEADER_LABEL))
	for i in MAX_OPTIONS:
		var row := HBoxContainer.new()
		row.name = "Idea_%d" % i
		var text := Label.new()
		text.name = "Text"
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.autowrap_mode = TextServer.AUTOWRAP_WORD
		row.add_child(text)
		var load_button := Button.new()
		load_button.name = "Load_%d" % i
		load_button.text = "Load"
		load_button.pressed.connect(_load.bind(i))
		row.add_child(load_button)
		add_child(row)
		_rows.append(row)
	_note.name = "PlannerNote"
	_note.theme_type_variation = UiStyle.MUTED_LABEL
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD
	add_child(_note)
	add_child(UiStyle.label("Cargo destinations", UiStyle.HEADER_LABEL))
	for i in MAX_DESTINATIONS:
		var row := HBoxContainer.new()
		row.name = "Destination_%d" % i
		var text := Label.new()
		text.name = "Text"
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.autowrap_mode = TextServer.AUTOWRAP_WORD
		row.add_child(text)
		var sail_button := Button.new()
		sail_button.name = "SailToCargo_%d" % i
		sail_button.text = "Sail"
		sail_button.pressed.connect(_sail_to_destination.bind(i))
		row.add_child(sail_button)
		add_child(row)
		_destination_rows.append(row)
	_destination_note.name = "DestinationNote"
	_destination_note.theme_type_variation = UiStyle.MUTED_LABEL
	_destination_note.autowrap_mode = TextServer.AUTOWRAP_WORD
	add_child(_destination_note)
	_session.changed.connect(refresh)
	refresh()


func refresh() -> void:
	var ship := _session.trading_ship()
	_options = []
	if ship != null:
		var data := _session.sim.data
		var ship_type := data.get_ship(ship.type_id)
		_options = (
			TradePlanner
			. plan(
				data,
				_session.player(),
				ship_type,
				_session.selected_city,
				ship_type.capacity - ship.cargo_total(),
				_session.player().coins,
			)
		)
	for i in MAX_OPTIONS:
		_rows[i].visible = i < _options.size()
		if _rows[i].visible:
			(_rows[i].get_node("Text") as Label).text = _describe(_options[i])
	if ship == null:
		_note.text = "Dock a ship here to see what pays to carry."
	elif _options.is_empty():
		_note.text = "No known profitable load (or %s is full)." % ship.name
	else:
		_note.text = "For %s from last known prices; markets can move." % ship.name
	_refresh_destinations(ship)


func _refresh_destinations(ship: ShipState) -> void:
	_destinations = []
	if ship != null:
		_destinations = CargoDestinationPlanner.plan(_session.sim.data, _session.player(), ship)
	for i in MAX_DESTINATIONS:
		_destination_rows[i].visible = i < _destinations.size()
		if _destination_rows[i].visible:
			(_destination_rows[i].get_node("Text") as Label).text = _describe_destination(
				_destinations[i]
			)
	if ship == null:
		_destination_note.text = "Dock a ship here to compare cargo sale prices."
	elif ship.cargo_total() == 0:
		_destination_note.text = "%s has no cargo to sell." % ship.name
	elif _destinations.is_empty():
		_destination_note.text = "No known port pays more than selling here."
	else:
		_destination_note.text = "For %s from last known prices; markets can move." % ship.name


func _describe_destination(option: CargoDestinationPlanner.Option) -> String:
	var days := float(option.hours) / Simulation.HOURS_PER_DAY
	var report: MarketRecord = _session.player().market_book[option.destination]
	var age := _session.sim.day() - report.day
	return (
		"%s (%dd old): %d coins, +%d vs here in %.1f days (%.1f/day)"
		% [
			_session.sim.data.get_city(option.destination).name,
			age,
			option.sale_value,
			option.extra_value(),
			days,
			option.extra_per_day(),
		]
	)


func _describe(option: TradePlanner.Option) -> String:
	var data := _session.sim.data
	var days := float(option.hours) / Simulation.HOURS_PER_DAY
	var report: MarketRecord = _session.player().market_book[option.destination]
	var age := _session.sim.day() - report.day
	return (
		"%s (%dd old): %d %s, +%d in %.1f days (%d a day)"
		% [
			data.get_city(option.destination).name,
			age,
			option.quantity,
			data.get_good(option.good_id).name.to_lower(),
			option.profit(),
			days,
			roundi(option.profit_per_day()),
		]
	)


func _load(index: int) -> void:
	var ship := _session.trading_ship()
	if ship == null or index >= _options.size():
		return
	var option := _options[index]
	_session.execute(BuyCommand.new(WorldState.PLAYER_ID, ship.id, option.good_id, option.quantity))


func _sail_to_destination(index: int) -> void:
	var ship := _session.trading_ship()
	if ship == null or index >= _destinations.size():
		return
	_session.execute(
		SailCommand.new(WorldState.PLAYER_ID, ship.id, _destinations[index].destination)
	)
