class_name SidePanel
extends PanelContainer
## Right-hand panel: the selected city with its population, satisfaction and scarce goods, its
## market, the player's fleet with cargo ideas, their trade routes, their kontor and workshops
## there, and the city's shipyard. Scrolls when taller than the window.

## Goods below this share of their normal stock are named as scarce.
const SCARCE_SUPPLY: float = 0.5
## At most this many scarce goods are named under the city title.
const MAX_SCARCE: int = 3

var _session: GameSession
var _title: Label = Label.new()
var _details: Label = Label.new()
var _needs: Label = Label.new()


func setup(session: GameSession) -> void:
	_session = session
	# Scroll rather than grow: a tall panel must never stretch the window and push the map away.
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var margin := UiStyle.add_padding(scroll, 12)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	_title.name = "CityTitle"
	_title.theme_type_variation = UiStyle.TITLE_LABEL
	column.add_child(_title)
	_details.name = "CityDetails"
	_details.theme_type_variation = UiStyle.MUTED_LABEL
	# Labels ignore the mouse by default, which would hide the explanation.
	_details.mouse_filter = Control.MOUSE_FILTER_PASS
	column.add_child(_details)
	_needs.name = "CityNeeds"
	_needs.autowrap_mode = TextServer.AUTOWRAP_WORD
	_needs.mouse_filter = Control.MOUSE_FILTER_PASS
	column.add_child(_needs)
	var market := MarketPanel.new()
	market.name = "Market"
	column.add_child(market)
	market.setup(_session)
	column.add_child(HSeparator.new())
	var fleet := FleetPanel.new()
	fleet.name = "Fleet"
	column.add_child(fleet)
	fleet.setup(_session)
	var planner := TradePlannerPanel.new()
	planner.name = "Planner"
	column.add_child(planner)
	planner.setup(_session)
	column.add_child(HSeparator.new())
	var routes := RoutesPanel.new()
	routes.name = "Routes"
	column.add_child(routes)
	routes.setup(_session)
	column.add_child(HSeparator.new())
	var kontor := KontorPanel.new()
	kontor.name = "Kontor"
	column.add_child(kontor)
	kontor.setup(_session)
	column.add_child(HSeparator.new())
	var shipyard := ShipyardPanel.new()
	shipyard.name = "Shipyard"
	column.add_child(shipyard)
	shipyard.setup(_session)
	_session.changed.connect(refresh)
	refresh()


func refresh() -> void:
	if _session.sim == null or _session.selected_city.is_empty():
		return
	var city_def := _session.sim.data.get_city(_session.selected_city)
	var city := _session.sim.world.get_city(_session.selected_city)
	_title.text = city_def.name
	var data := _session.sim.data
	var change := PopulationSystem.daily_change(data, city)
	var arrow := "▲" if change > 0 else ("▼" if change < 0 else "→")
	_details.text = (
		"Population %d %s   Satisfaction %d%%"
		% [city.population, arrow, _percent(city.satisfaction)]
	)
	_details.tooltip_text = _explain_city(city_def, city, change)
	var scarce := _scarce_goods(data, city)
	if scarce.is_empty():
		_needs.text = "Well supplied"
		_needs.modulate = UiStyle.INK_MUTED
	else:
		_needs.text = "Short of %s" % ", ".join(scarce.slice(0, MAX_SCARCE))
		_needs.modulate = UiStyle.WARNING
	_needs.tooltip_text = _explain_needs(data, city)


## Why the city grows or shrinks: satisfaction against neutral, and where the population heads.
func _explain_city(city_def: CityDef, city: CityState, change: int) -> String:
	var data := _session.sim.data
	var neutral := CityEconomy.to_parts(data.population.neutral_satisfaction)
	var today := PopulationSystem.supply_score(data, city)
	var direction := "rising" if today > city.satisfaction else "falling or steady"
	var sustained := PopulationSystem.sustainable_population(data, city)
	var lines: PackedStringArray = [
		"Satisfaction: how well the market has met the townsfolk's needs lately",
		"At %d%% the city keeps its usual %d people" % [_percent(neutral), city_def.population],
		"Today's supply: %d%%, so satisfaction is %s" % [_percent(today), direction],
		"This satisfaction sustains %d people" % sustained,
	]
	if change > 0:
		lines.append("About %d people move in a day" % change)
	elif change < 0:
		lines.append("About %d people leave a day" % -change)
	var employed := CityEconomy.workers_employed(data, _session.sim.world, city.id)
	var workforce := CityEconomy.workforce(data.economy, city)
	lines.append("Workforce %d, of whom %d work in traders' workshops" % [workforce, employed])
	lines.append("More people want more goods and can work in more workshops.")
	return "\n".join(lines)


## Goods below SCARCE_SUPPLY of their normal stock, scarcest first (data order
## among equals).
func _scarce_goods(data: GameData, city: CityState) -> PackedStringArray:
	var threshold := CityEconomy.to_parts(SCARCE_SUPPLY)
	var scarce: Array[Array] = []
	for i in data.goods.size():
		var supply := PopulationSystem.supply(data.economy, city, data.goods[i])
		if supply < threshold:
			scarce.append([supply, i])
	scarce.sort()
	var names: PackedStringArray = []
	for entry in scarce:
		names.append(data.goods[entry[1] as int].name)
	return names


## Supply of every good the townsfolk use, so the player sees what would please them.
func _explain_needs(data: GameData, city: CityState) -> String:
	var lines: PackedStringArray = [
		"Supply against normal stock (goods weigh by what people spend):"
	]
	for good in data.goods:
		if good.consumption_per_1000 <= 0.0:
			continue
		var supply := PopulationSystem.supply(data.economy, city, good)
		lines.append("%s: %d%%" % [good.name, _percent(supply)])
	lines.append("Bring scarce goods to raise satisfaction and let the city grow.")
	return "\n".join(lines)


static func _percent(parts: int) -> int:
	return roundi(parts * 100.0 / CityEconomy.PARTS_PER_UNIT)
