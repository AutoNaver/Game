class_name HousesPanel
extends PanelContainer
## The trading houses ordered by net worth (HouseValue): the player and the rival houses, with
## their rank (ADR 0015), coins, ships, kontors and workshops, and what the player needs for the
## next rank, so the player can measure their progress. Shown over the map's top-right corner; the
## HUD's "Houses" button toggles it.

const COLUMNS: PackedStringArray = [
	"House", "Rank", "Worth", "Coins", "Ships", "Kontors", "Workshops"
]
const NAME_WIDTH: float = 130.0
const RANK_WIDTH: float = 100.0
const NUMBER_WIDTH: float = 64.0
const SWATCH_SIZE: Vector2 = Vector2(10, 10)

var _session: GameSession
var _rows: VBoxContainer = VBoxContainer.new()
var _trader_ids: PackedStringArray = []
var _next_rank: Label = Label.new()


func setup(session: GameSession) -> void:
	_session = session
	visible = false
	var margin := UiStyle.add_padding(self, 8)
	var column := VBoxContainer.new()
	margin.add_child(column)
	column.add_child(UiStyle.label("Trading houses", UiStyle.HEADER_LABEL))
	var header := _row_box()
	for i in COLUMNS.size():
		var label := UiStyle.label(COLUMNS[i], UiStyle.MUTED_LABEL)
		_size_cell(label, i)
		header.add_child(label)
	column.add_child(header)
	_rows.name = "HouseRows"
	column.add_child(_rows)
	_next_rank.name = "NextRank"
	_next_rank.autowrap_mode = TextServer.AUTOWRAP_WORD
	_next_rank.custom_minimum_size = Vector2(NAME_WIDTH + RANK_WIDTH + NUMBER_WIDTH * 5, 0)
	column.add_child(_next_rank)
	var note := UiStyle.label(
		"Worth: coins, ships at resale value, kontors and workshops at cost, goods at base price.",
		UiStyle.MUTED_LABEL
	)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD
	note.custom_minimum_size = Vector2(NAME_WIDTH + RANK_WIDTH + NUMBER_WIDTH * 5, 0)
	column.add_child(note)
	_session.houses_toggled.connect(toggle)
	_session.changed.connect(refresh)
	refresh()


func toggle() -> void:
	visible = not visible
	refresh()


func refresh() -> void:
	if not visible or _session.sim == null:
		return
	var traders := _session.sim.world.traders
	var ids := PackedStringArray()
	for trader in traders:
		ids.append(trader.id)
	if ids != _trader_ids:
		_rebuild(traders)
		_trader_ids = ids
	var data := _session.sim.data
	var worth: Dictionary[String, int] = {}
	for trader in traders:
		worth[trader.id] = HouseValue.net_worth(data, trader)
	var ranked := traders.duplicate()
	# sort_custom isn't stable: break ties by the traders' order so the list never flickers.
	ranked.sort_custom(
		func(a: TraderState, b: TraderState) -> bool:
			if worth[a.id] != worth[b.id]:
				return worth[a.id] > worth[b.id]
			return ids.find(a.id) < ids.find(b.id)
	)
	for i in ranked.size():
		var trader: TraderState = ranked[i]
		var row := _rows.get_node("House_%s" % trader.id) as HBoxContainer
		_rows.move_child(row, i)
		var workshops := 0
		for kontor in trader.kontors_in_order(data.cities):
			workshops += kontor.workshops.size()
		(row.get_child(1) as Label).text = RankSystem.rank(data, trader).name
		var cells := [worth[trader.id], trader.coins, trader.ships.size(), trader.kontors.size()]
		cells.append(workshops)
		for j in cells.size():
			(row.get_child(j + 2) as Label).text = str(cells[j])
	_next_rank.text = next_rank_text(_session.sim, _session.player())


## What the trader's next rank needs and unlocks, or that it holds the highest rank.
static func next_rank_text(sim: Simulation, trader: TraderState) -> String:
	var next := RankSystem.next_rank(sim.data, trader)
	if next == null:
		return "You hold the highest rank."
	var needs := RankSystem.missing(sim.data, sim.world, trader, next)
	var text := "Next rank: %s" % next.name
	if not needs.is_empty():
		text += ", needs %s" % ", ".join(needs)
	var unlocks := PackedStringArray()
	for unlock in next.unlocks:
		unlocks.append(unlock.replace("_", " "))
	if not unlocks.is_empty():
		text += ". Unlocks %s" % ", ".join(unlocks)
	return text + "."


## The trader's display name: "You" for the player.
static func house_name(trader: TraderState) -> String:
	return "You" if trader.id == WorldState.PLAYER_ID else trader.name


func _rebuild(traders: Array[TraderState]) -> void:
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	for trader in traders:
		var row := _row_box()
		row.name = "House_%s" % trader.id
		var name_cell := HBoxContainer.new()
		var swatch := ColorRect.new()
		swatch.custom_minimum_size = SWATCH_SIZE
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		swatch.color = MapView.house_color(_session.sim.data, trader.id)
		name_cell.add_child(swatch)
		var variation := UiStyle.HEADER_LABEL if trader.id == WorldState.PLAYER_ID else &""
		var label := UiStyle.label(house_name(trader), variation)
		label.name = "Name"
		name_cell.add_child(label)
		_size_cell(name_cell, 0)
		row.add_child(name_cell)
		for i in range(1, COLUMNS.size()):
			var cell := Label.new()
			cell.name = COLUMNS[i]
			_size_cell(cell, i)
			row.add_child(cell)
		_rows.add_child(row)


func _row_box() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	return row


func _size_cell(cell: Control, column: int) -> void:
	var width := NUMBER_WIDTH
	if column == 0:
		width = NAME_WIDTH
	elif column == 1:
		width = RANK_WIDTH
	cell.custom_minimum_size = Vector2(width, 0)
	if cell is Label and column > 1:
		(cell as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
