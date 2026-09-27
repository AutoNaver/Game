class_name SidePanel
extends PanelContainer
## Right-hand panel for the selected city. For now it shows the city's name and population;
## the market table and fleet controls come next (M3).

var _session: GameSession
var _title: Label = Label.new()
var _details: Label = Label.new()


func setup(session: GameSession) -> void:
	_session = session
	var margin := UiStyle.add_padding(self, 12)
	var column := VBoxContainer.new()
	margin.add_child(column)
	_title.name = "CityTitle"
	_title.add_theme_font_size_override("font_size", 24)
	column.add_child(_title)
	_details.name = "CityDetails"
	column.add_child(_details)
	_session.changed.connect(refresh)


func refresh() -> void:
	if _session.sim == null or _session.selected_city.is_empty():
		return
	var city_def := _session.sim.data.get_city(_session.selected_city)
	var city := _session.sim.world.get_city(_session.selected_city)
	_title.text = city_def.name
	_details.text = "Population %d" % city.population
