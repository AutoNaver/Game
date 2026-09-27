class_name SidePanel
extends PanelContainer
## Right-hand panel: the selected city with its market, the player's fleet with cargo ideas, their
## trade routes, their kontor and workshops there, and the city's shipyard. Scrolls when taller
## than the window.

var _session: GameSession
var _title: Label = Label.new()
var _details: Label = Label.new()


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
	column.add_child(_details)
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
	_details.text = "Population %d" % city.population
