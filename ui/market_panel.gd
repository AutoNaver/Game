class_name MarketPanel
extends VBoxContainer
## The selected city's market: stock and prices per good, and buy/sell buttons that trade with
## the player's ship docked there or with their kontor in the city ("Trade with"). Rows are built
## once and updated on every change, so buttons stay clickable while time runs.

const QUANTITIES: Array[int] = [1, 5, 10, 25]
const COLUMNS: Array[String] = ["Good", "Stock", "Buy", "Sell", "Yours", "", ""]
## Prices are coloured by how good a deal they are for the player: green for cheap buys and dear
## sells, red for the opposite. Thresholds are fractions of the good's base price.
const CHEAP: float = 0.8
const DEAR: float = 1.25
const GOOD_DEAL_COLOR: Color = Color(0.55, 0.9, 0.55)
const BAD_DEAL_COLOR: Color = Color(1.0, 0.55, 0.45)


class Row:
	extends RefCounted
	var stock: Label = Label.new()
	var buy_price: Label = Label.new()
	var sell_price: Label = Label.new()
	var aboard: Label = Label.new()
	var buy: Button = Button.new()
	var sell: Button = Button.new()


var _session: GameSession
var _rows: Dictionary[String, Row] = {}
var _note: Label = Label.new()
var _target_row: HBoxContainer = HBoxContainer.new()
var _ship_target: Button = Button.new()
var _kontor_target: Button = Button.new()
var _use_kontor: bool = false


func setup(session: GameSession) -> void:
	_session = session
	add_child(UiStyle.label("Market", UiStyle.HEADER_LABEL))
	add_child(_build_quantity_picker())
	add_child(_build_target_picker())
	var grid := GridContainer.new()
	grid.columns = COLUMNS.size()
	grid.add_theme_constant_override("h_separation", 12)
	add_child(grid)
	for heading in COLUMNS:
		grid.add_child(UiStyle.label(heading, UiStyle.MUTED_LABEL))
	for good in _session.sim.data.goods:
		_rows[good.id] = _build_row(grid, good)
	_note.name = "TradeNote"
	_note.theme_type_variation = UiStyle.MUTED_LABEL
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD
	add_child(_note)
	_session.changed.connect(refresh)
	refresh()


func refresh() -> void:
	var economy := _session.sim.data.economy
	var city := _session.sim.world.get_city(_session.selected_city)
	var hold := _target()
	var kontor := _session.player().get_kontor(_session.selected_city)
	_target_row.visible = kontor != null and _session.trading_ship() != null
	_ship_target.set_pressed_no_signal(hold != null and hold is ShipState)
	_kontor_target.set_pressed_no_signal(hold != null and hold is KontorState)
	for good in _session.sim.data.goods:
		var row := _rows[good.id]
		var stock: int = city.stock[good.id]
		row.stock.text = str(stock)
		if stock > 0:
			var price := CityEconomy.buy_cost(economy, city, good, 1)
			row.buy_price.text = str(price)
			row.buy_price.modulate = _deal_color(price, good.base_price, true)
		else:
			row.buy_price.text = "-"
			row.buy_price.modulate = Color.WHITE
		var sell := CityEconomy.sell_revenue(economy, city, good, 1)
		row.sell_price.text = str(sell)
		row.sell_price.modulate = _deal_color(sell, good.base_price, false)
		var held := hold.cargo_of(good.id) if hold != null else 0
		row.aboard.text = str(held) if hold != null else "-"
		row.buy.disabled = hold == null or stock == 0
		row.sell.disabled = hold == null or held == 0
	if hold == null:
		_note.text = "None of your ships is docked here. Send one from the fleet list."
	else:
		var sizes := [_hold_name(hold), hold.cargo_total(), _capacity(hold)]
		_note.text = "Trading with %s (%d/%d)" % sizes


func _build_quantity_picker() -> HBoxContainer:
	var picker := HBoxContainer.new()
	var label := Label.new()
	label.text = "Trade quantity:"
	picker.add_child(label)
	var group := ButtonGroup.new()
	for quantity in QUANTITIES:
		var button := Button.new()
		button.name = "Quantity_%d" % quantity
		button.text = str(quantity)
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = quantity == _session.trade_quantity
		button.pressed.connect(func() -> void: _session.trade_quantity = quantity)
		picker.add_child(button)
	return picker


func _build_target_picker() -> HBoxContainer:
	_target_row.name = "TradeTarget"
	_target_row.add_child(UiStyle.label("Trade with:", UiStyle.MUTED_LABEL))
	var group := ButtonGroup.new()
	for button: Button in [_ship_target, _kontor_target]:
		button.toggle_mode = true
		button.button_group = group
		_target_row.add_child(button)
	_ship_target.name = "TradeWithShip"
	_ship_target.text = "Ship"
	_ship_target.pressed.connect(_choose_target.bind(false))
	_kontor_target.name = "TradeWithKontor"
	_kontor_target.text = "Kontor"
	_kontor_target.pressed.connect(_choose_target.bind(true))
	return _target_row


func _choose_target(use_kontor: bool) -> void:
	_use_kontor = use_kontor
	refresh()


## Where trades go: the docked ship, or the kontor when chosen or when no ship is in port.
## Null if the player has neither here.
func _target() -> Hold:
	var kontor := _session.player().get_kontor(_session.selected_city)
	var ship := _session.trading_ship()
	if kontor != null and (_use_kontor or ship == null):
		return kontor
	return ship


func _capacity(hold: Hold) -> int:
	if hold is KontorState:
		return _session.sim.data.kontor.capacity
	return _session.sim.data.get_ship((hold as ShipState).type_id).capacity


func _hold_name(hold: Hold) -> String:
	return "your kontor" if hold is KontorState else (hold as ShipState).name


func _build_row(grid: GridContainer, good: GoodDef) -> Row:
	var row := Row.new()
	var name_label := Label.new()
	name_label.text = good.name
	grid.add_child(name_label)
	for label: Label in [row.stock, row.buy_price, row.sell_price, row.aboard]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(label)
	row.buy.name = "Buy_%s" % good.id
	row.buy.text = "Buy"
	row.buy.pressed.connect(_buy.bind(good.id))
	grid.add_child(row.buy)
	row.sell.name = "Sell_%s" % good.id
	row.sell.text = "Sell"
	row.sell.pressed.connect(_sell.bind(good.id))
	grid.add_child(row.sell)
	return row


## Buys up to the chosen quantity, limited by the market's stock and the target's free space.
func _buy(good_id: String) -> void:
	var hold := _target()
	if hold == null:
		return
	var city := _session.sim.world.get_city(_session.selected_city)
	var room := _capacity(hold) - hold.cargo_total()
	var quantity := mini(_session.trade_quantity, mini(city.stock[good_id], room))
	if quantity <= 0:
		var holder := "Your kontor" if hold is KontorState else (hold as ShipState).name
		_session.message_posted.emit("%s has no room left" % holder)
		return
	var player := WorldState.PLAYER_ID
	if hold is KontorState:
		_session.execute(BuyCommand.for_kontor(player, city.id, good_id, quantity))
	else:
		_session.execute(BuyCommand.new(player, (hold as ShipState).id, good_id, quantity))


## Sells up to the chosen quantity, limited by what the target holds.
func _sell(good_id: String) -> void:
	var hold := _target()
	if hold == null:
		return
	var quantity := mini(_session.trade_quantity, hold.cargo_of(good_id))
	if quantity <= 0:
		return
	var player := WorldState.PLAYER_ID
	if hold is KontorState:
		_session.execute(SellCommand.for_kontor(player, _session.selected_city, good_id, quantity))
	else:
		_session.execute(SellCommand.new(player, (hold as ShipState).id, good_id, quantity))


static func _deal_color(price: int, base_price: int, buying: bool) -> Color:
	var ratio := float(price) / float(base_price)
	if ratio < CHEAP:
		return GOOD_DEAL_COLOR if buying else BAD_DEAL_COLOR
	if ratio > DEAR:
		return BAD_DEAL_COLOR if buying else GOOD_DEAL_COLOR
	return Color.WHITE
