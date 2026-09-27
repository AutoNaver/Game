class_name SidePanel
extends PanelContainer
## Right-hand panel: the selected city with its market, and the player's fleet.

var _session: GameSession
var _title: Label = Label.new()
var _details: Label = Label.new()


func setup(session: GameSession) -> void:
	_session = session
	var margin := UiStyle.add_padding(self, 12)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	_title.name = "CityTitle"
	_title.add_theme_font_size_override("font_size", 24)
	column.add_child(_title)
	_details.name = "CityDetails"
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
	_session.changed.connect(refresh)
	refresh()


func refresh() -> void:
	if _session.sim == null or _session.selected_city.is_empty():
		return
	var city_def := _session.sim.data.get_city(_session.selected_city)
	var city := _session.sim.world.get_city(_session.selected_city)
	_title.text = city_def.name
	_details.text = "Population %d" % city.population
