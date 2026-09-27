class_name MarketPanel
extends VBoxContainer
## The selected city's market: stock and prices per good, and buy/sell buttons that trade with
## the player's ship docked there. Rows are built once and updated on every change, so buttons
## stay clickable while time runs.

const QUANTITIES: Array[int] = [1, 5, 10, 25]
const COLUMNS: Array[String] = ["Good", "Stock", "Buy", "Sell", "Aboard", "", ""]
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
var _quantity: int = QUANTITIES[0]
var _rows: Dictionary[String, Row] = {}
var _note: Label = Label.new()


func setup(session: GameSession) -> void:
	_session = session
	add_child(_build_quantity_picker())
	var grid := GridContainer.new()
	grid.columns = COLUMNS.size()
	grid.add_theme_constant_override("h_separation", 12)
	add_child(grid)
	for heading in COLUMNS:
		var label := Label.new()
		label.text = heading
		label.modulate = Color(1, 1, 1, 0.6)
		grid.add_child(label)
	for good in _session.sim.data.goods:
		_rows[good.id] = _build_row(grid, good)
	_note.name = "TradeNote"
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD
	add_child(_note)
	_session.changed.connect(refresh)
	refresh()


func refresh() -> void:
	var economy := _session.sim.data.economy
	var city := _session.sim.world.get_city(_session.selected_city)
	var ship := _session.trading_ship()
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
		var aboard := ship.cargo_of(good.id) if ship != null else 0
		row.aboard.text = str(aboard) if ship != null else "-"
		row.buy.disabled = ship == null or stock == 0
		row.sell.disabled = ship == null or aboard == 0
	if ship == null:
		_note.text = "None of your ships is docked here. Send one from the fleet list."
	else:
		var capacity := _session.sim.data.get_ship(ship.type_id).capacity
		_note.text = "Trading with %s (cargo %d/%d)" % [ship.name, ship.cargo_total(), capacity]


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
		button.button_pressed = quantity == _quantity
		button.pressed.connect(func() -> void: _quantity = quantity)
		picker.add_child(button)
	return picker


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


## Buys up to the chosen quantity, limited by the market's stock and the ship's free space.
func _buy(good_id: String) -> void:
	var ship := _session.trading_ship()
	if ship == null:
		return
	var city := _session.sim.world.get_city(_session.selected_city)
	var room := _session.sim.data.get_ship(ship.type_id).capacity - ship.cargo_total()
	var quantity := mini(_quantity, mini(city.stock[good_id], room))
	if quantity <= 0:
		_session.message_posted.emit("%s has no room left" % ship.name)
		return
	_session.execute(BuyCommand.new(WorldState.PLAYER_ID, ship.id, good_id, quantity))


## Sells up to the chosen quantity, limited by what the ship carries.
func _sell(good_id: String) -> void:
	var ship := _session.trading_ship()
	if ship == null:
		return
	var quantity := mini(_quantity, ship.cargo_of(good_id))
	if quantity > 0:
		_session.execute(SellCommand.new(WorldState.PLAYER_ID, ship.id, good_id, quantity))


static func _deal_color(price: int, base_price: int, buying: bool) -> Color:
	var ratio := float(price) / float(base_price)
	if ratio < CHEAP:
		return GOOD_DEAL_COLOR if buying else BAD_DEAL_COLOR
	if ratio > DEAR:
		return BAD_DEAL_COLOR if buying else GOOD_DEAL_COLOR
	return Color.WHITE
