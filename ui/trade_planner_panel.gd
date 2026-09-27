class_name TradePlannerPanel
extends VBoxContainer
## "Cargo ideas": for the player's ship trading in the selected city, the best load to carry to
## each other city at today's prices (TradePlanner). "Load" buys it through the normal buy command;
## the player still chooses when and where to sail.

## Suggestions shown, best profit per day first.
const MAX_OPTIONS: int = 3

var _session: GameSession
var _note: Label = Label.new()
var _rows: Array[HBoxContainer] = []
var _options: Array[TradePlanner.Option] = []


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
				_session.sim.world,
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
		_note.text = "Nothing here pays to carry right now (or %s is full)." % ship.name
	else:
		_note.text = "For %s at today's prices; markets can move before you arrive." % ship.name


func _describe(option: TradePlanner.Option) -> String:
	var data := _session.sim.data
	var days := float(option.hours) / Simulation.HOURS_PER_DAY
	return (
		"%s: %d %s, +%d in %.1f days (%d a day)"
		% [
			data.get_city(option.destination).name,
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
