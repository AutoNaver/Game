class_name GameSession
extends Node
## The UI's handle on a running game. Advances time at the chosen speed, executes the player's
## commands and remembers what is selected. Panels read from here and redraw on `changed`;
## they never modify simulation state themselves.

signal changed
signal game_over
signal message_posted(text: String)
## A new entry in the notification log (already dated).
signal notified(entry: String)
## The HUD asks for the save menu, for saving (`saving`) or loading.
signal save_menu_requested(saving: bool)
## The HUD's "Houses" button: show or hide the trading houses ranking.
signal houses_toggled
## A panel asks for the route editor, on route `route_id` or a new route ("").
signal route_editor_requested(route_id: String)

## Selectable game speeds, as multipliers of HOURS_PER_SECOND. 0 is paused.
const SPEEDS: Array[int] = [0, 1, 2, 4]
## In-game hours per real second at 1× speed.
const HOURS_PER_SECOND: float = 2.0
## Notification log entries kept.
const MAX_LOG: int = 50
## The running game is saved to AUTOSAVE_SLOT every this many in-game days.
const AUTOSAVE_DAYS: int = 3
const AUTOSAVE_SLOT: String = "autosave"
## A hold losing at least this many units to spoilage in a day is worth a notification.
const LARGE_SPOILAGE: int = 5

var sim: Simulation
var speed: int = 1
var selected_city: String = ""
var selected_ship: String = ""
## Where saves live. Tests point this at their own folder so they never touch real saves.
var save_dir: String = SaveGame.SAVE_DIR
## The slot last saved to or loaded from; the save menu suggests it.
var save_slot: String = ""
## Units per click for trades and transfers, chosen in the market panel.
var trade_quantity: int = 1
## Pause the game when one of the player's ships arrives, so arrivals aren't missed at speed.
var pause_on_arrival: bool = true
## Dated notifications, oldest first: arrivals and workshops that stopped. The last MAX_LOG
## entries of the running game; not saved, and cleared when a game is loaded.
var notification_log: PackedStringArray = []

var _pending_hours: float = 0.0
## Deals and offers already reported (ADR 0016), so each is reported once.
var _seen_deal: int = 0
var _seen_offers: PackedStringArray = []


func start(data: GameData, seed_value: int) -> void:
	sim = Simulation.new_game(data, seed_value)
	notification_log.clear()
	save_slot = ""
	_pending_hours = 0.0
	selected_city = data.scenario.start_city
	var ships := sim.world.player().ships
	selected_ship = ships[0].id if not ships.is_empty() else ""
	_reset_deal_news()
	changed.emit()


## Writes the running game to `slot`. Posts the outcome as a message.
func save_game(slot: String) -> bool:
	var error := SaveGame.check_slot_name(slot)
	if error.is_empty():
		error = SaveGame.save_file(sim.world, SaveGame.path_for(slot, save_dir))
	if not error.is_empty():
		message_posted.emit("Save failed: %s" % error)
		return false
	if slot != AUTOSAVE_SLOT:
		save_slot = slot
	message_posted.emit('Game saved as "%s"' % slot)
	return true


## Replaces the running game with the one saved in `slot`, if it loads cleanly. Posts the outcome.
func load_game(slot: String) -> bool:
	var loader := SaveGame.new()
	var world := loader.load_file(sim.data, SaveGame.path_for(slot, save_dir))
	if world == null:
		message_posted.emit("Load failed: %s" % loader.errors[0])
		return false
	sim = Simulation.new(sim.data, world)
	# The log belongs to the game that was running; the loaded one starts with a fresh log.
	notification_log.clear()
	if slot != AUTOSAVE_SLOT:
		save_slot = slot
	var ships := player().ships
	if player().get_ship(selected_ship) == null:
		selected_ship = ships[0].id if not ships.is_empty() else ""
	_reset_deal_news()
	message_posted.emit("Game loaded (day %d)" % (sim.day() + 1))
	changed.emit()
	return true


## The saves in save_dir, newest first by file time (ties by name).
func list_saves() -> PackedStringArray:
	var slots := SaveGame.list_slots(save_dir)
	var times: Dictionary[String, int] = {}
	for slot in slots:
		times[slot] = FileAccess.get_modified_time(SaveGame.path_for(slot, save_dir))
	var ordered := Array(slots)
	ordered.sort_custom(
		func(a: String, b: String) -> bool:
			return times[a] > times[b] if times[a] != times[b] else a < b
	)
	return PackedStringArray(ordered)


func player() -> TraderState:
	return sim.world.player()


## Sets how many units a Buy or Sell click trades; panels that show per-click values refresh.
func set_trade_quantity(value: int) -> void:
	trade_quantity = value
	changed.emit()


## Changes how fast time runs from now on. Time already accumulated towards the next hour is
## kept, so switching speeds never loses or stalls time.
func set_speed(value: int) -> void:
	assert(SPEEDS.has(value), "unsupported speed %d" % value)
	speed = value
	changed.emit()


## Runs up to `hours` ticks immediately, regardless of speed. Notifies about ships that arrive,
## workshops that stop working or run short of workers, world events starting and ending, the
## player's goods lost to fires and large spoilage, and the rival houses' new ships and workshops,
## each dated when it happened. If pause_on_arrival is set and
## time is running, stops right after the tick in which a ship arrives, even mid-batch. Ships on
## trade routes leave again in the hour they arrive, so they neither notify nor pause; their
## problems are reported instead (_notify_route_problems).
func advance(hours: int) -> void:
	var at_sea: Array[ShipState] = []
	for ship in player().ships:
		if not ship.is_docked():
			at_sea.append(ship)
	var statuses := _workshop_statuses()
	var short_staffed := _short_staffed_cities()
	var rival_assets := _rival_assets()
	var events := _event_ids()
	var day_before := sim.day()
	for i in hours:
		var notes := _route_notes()
		sim.tick()
		if player().bankrupt:
			speed = 0
			_pending_hours = 0.0
			notify("Your trading house is bankrupt")
			game_over.emit()
			break
		_notify_route_problems(notes)
		var arrived := false
		for ship: ShipState in at_sea.duplicate():
			if ship.is_docked():
				arrived = true
				at_sea.erase(ship)
				notify("%s arrived in %s" % [ship.name, _city_name(ship.docked_at)])
		if sim.world.hour % Simulation.HOURS_PER_DAY == 0:
			_notify_stopped_workshops(statuses)
			statuses = _workshop_statuses()
			_notify_staffing(short_staffed)
			short_staffed = _short_staffed_cities()
			_notify_deals()
			_notify_offers()
			_notify_rival_news(rival_assets)
			rival_assets = _rival_assets()
			_notify_events(events)
			events = _event_ids()
			_notify_losses()
		if arrived and pause_on_arrival and speed != 0:
			speed = 0
			_pending_hours = 0.0
			break
	# Once per AUTOSAVE_DAYS boundary crossed, however many hours this step covered.
	@warning_ignore("integer_division")
	if sim.day() / AUTOSAVE_DAYS > day_before / AUTOSAVE_DAYS:
		var error := SaveGame.save_file(sim.world, SaveGame.path_for(AUTOSAVE_SLOT, save_dir))
		if not error.is_empty():
			message_posted.emit("Autosave failed: %s" % error)
	changed.emit()


## Adds a dated entry to the notification log and shows it as the latest message.
func notify(text: String) -> void:
	var entry := "Day %d: %s" % [sim.day() + 1, text]
	notification_log.append(entry)
	if notification_log.size() > MAX_LOG:
		notification_log = notification_log.slice(notification_log.size() - MAX_LOG)
	message_posted.emit(text)
	notified.emit(entry)


## Executes a player command. Failures are posted as a message instead of changing anything.
func execute(command: Command) -> bool:
	if player().bankrupt:
		message_posted.emit("Your trading house is bankrupt")
		return false
	var error := sim.execute(command)
	if error.is_empty():
		# A sold ship may have been the selected one.
		if player().get_ship(selected_ship) == null:
			selected_ship = player().ships[0].id if not player().ships.is_empty() else ""
		_notify_deals()
		_notify_offers()
		changed.emit()
		return true
	message_posted.emit(error)
	return false


## The player's ship that trades in the selected city: the selected ship if it is docked there,
## otherwise the first of the player's ships docked there. Null if there is none.
func trading_ship() -> ShipState:
	var selected := player().get_ship(selected_ship)
	if selected != null and selected.docked_at == selected_city:
		return selected
	for ship in player().ships:
		if ship.docked_at == selected_city:
			return ship
	return null


func select_city(city_id: String) -> void:
	selected_city = city_id
	changed.emit()


func select_ship(ship_id: String) -> void:
	selected_ship = ship_id
	changed.emit()


func _process(delta: float) -> void:
	if sim == null or speed == 0:
		return
	_pending_hours += delta * HOURS_PER_SECOND * speed
	var hours := floori(_pending_hours)
	if hours > 0:
		_pending_hours -= hours
		advance(hours)


## The route note of each of the player's ships on a route, by ship id.
func _route_notes() -> Dictionary[String, String]:
	var notes: Dictionary[String, String] = {}
	for ship in player().ships:
		if not ship.route_id.is_empty():
			notes[ship.id] = ship.route_note
	return notes


## Notifies when a route ship reports a new problem at a stop. Ships clear their note at each stop
## that goes smoothly, so a repeated problem is reported again only after a good stop.
func _notify_route_problems(before: Dictionary[String, String]) -> void:
	for ship in player().ships:
		if ship.route_note.is_empty() or before.get(ship.id, "") == ship.route_note:
			continue
		var route := player().get_route(ship.route_id)
		notify("%s (%s): %s" % [ship.name, route.name, ship.route_note])


## "status/missing good" per workshop id of the player's, to spot changes across a step.
func _workshop_statuses() -> Dictionary[String, String]:
	var statuses: Dictionary[String, String] = {}
	for kontor in player().kontors_in_order(sim.data.cities):
		for workshop in kontor.workshops:
			statuses[workshop.id] = "%d/%s" % [workshop.status, workshop.missing_good]
	return statuses


## Notifies once when a workshop goes idle, or idles for a different reason than before.
func _notify_stopped_workshops(before: Dictionary[String, String]) -> void:
	var idle: Array[WorkshopState.Status] = [
		WorkshopState.Status.NO_INPUTS,
		WorkshopState.Status.KONTOR_FULL,
		WorkshopState.Status.UNPAID,
	]
	for kontor in player().kontors_in_order(sim.data.cities):
		for workshop in kontor.workshops:
			var now := "%d/%s" % [workshop.status, workshop.missing_good]
			if not idle.has(workshop.status) or before.get(workshop.id, now) == now:
				continue
			var workshop_type := sim.data.get_workshop(workshop.type_id)
			var status := KontorPanel.status_text(sim.data, workshop)
			notify("%s in %s: %s" % [workshop_type.name, _city_name(kontor.city_id), status])


## Headlines of the running events by id, so an event that ends can still be named.
func _event_ids() -> Dictionary[String, String]:
	var headlines: Dictionary[String, String] = {}
	for event in sim.world.events:
		headlines[event.id] = EventText.headline(sim.data, event)
	return headlines


## Notifies when a world event starts, and when one that was running is over.
func _notify_events(before: Dictionary[String, String]) -> void:
	var data := sim.data
	var now := _event_ids()
	for event in sim.world.events:
		if not before.has(event.id):
			var effect := EventText.effect(data, event)
			var days := event.end_day - event.start_day
			var text := "%s: %s" % [EventText.headline(data, event), effect]
			if data.get_event(event.type_id).kind != EventDef.FIRE:
				text += " for %d days" % days
			notify(text)
	for id: String in before:
		if not now.has(id):
			notify("Over: %s" % before[id])


## Notifies about the player's goods lost on the last day: every fire, and spoilage of at least
## LARGE_SPOILAGE units in one ship or kontor.
func _notify_losses() -> void:
	var by_hold: Dictionary[String, Array] = {}
	var holds := PackedStringArray()
	for loss in sim.world.losses:
		if loss.trader_id != WorldState.PLAYER_ID:
			continue
		var key := "%s|%s" % [loss.cause, loss.hold_id]
		if not by_hold.has(key):
			by_hold[key] = [] as Array[GoodsLoss]
			holds.append(key)
		by_hold[key].append(loss)
	for key in holds:
		var losses: Array[GoodsLoss] = []
		losses.assign(by_hold[key])
		var cause := key.get_slice("|", 0)
		var hold_id := key.get_slice("|", 1)
		var place := _hold_name(hold_id)
		var goods := EventText.goods_list(sim.data, losses)
		if cause == GoodsLoss.SPOILAGE:
			var units := 0
			for loss in losses:
				units += loss.units
			if units >= LARGE_SPOILAGE:
				notify("Spoiled %s: %s" % [place, goods])
		else:
			notify("%s destroyed %s: %s" % [sim.data.get_event(cause).name, place, goods])


## "aboard Adler" for a ship id, "in your kontor in Lübeck" for a city id.
func _hold_name(hold_id: String) -> String:
	var ship := player().get_ship(hold_id)
	if ship != null:
		return "aboard %s" % ship.name
	return "in your kontor in %s" % _city_name(hold_id)


## Cities where the player has workshops that are short of workers (CityEconomy.staffing).
func _short_staffed_cities() -> PackedStringArray:
	var cities := PackedStringArray()
	for kontor in player().kontors_in_order(sim.data.cities):
		var city := sim.world.get_city(kontor.city_id)
		var full := CityEconomy.staffing(sim.data, sim.world, city) == CityEconomy.PARTS_PER_UNIT
		if not kontor.workshops.is_empty() and not full:
			cities.append(kontor.city_id)
	return cities


## Notifies once when the player's workshops in a city run short of workers, and when they are
## fully staffed again.
func _notify_staffing(before: PackedStringArray) -> void:
	var now := _short_staffed_cities()
	for city_id in now:
		if not before.has(city_id):
			var city := sim.world.get_city(city_id)
			var staffing := CityEconomy.staffing(sim.data, sim.world, city)
			var percent := roundi(staffing * 100.0 / CityEconomy.PARTS_PER_UNIT)
			var text := "%s has shrunk: your workshops there are %d%% staffed and work slower"
			notify(text % [_city_name(city_id), percent])
	for city_id in before:
		if not now.has(city_id) and player().get_kontor(city_id) != null:
			if not player().get_kontor(city_id).workshops.is_empty():
				notify("Your workshops in %s are fully staffed again" % _city_name(city_id))


## The rival houses' ships and workshops as keys ("ship/<id>/<type>",
## "workshop/<id>/<city>/<type>"), to spot what they bought or closed across a step.
func _rival_assets() -> Dictionary[String, PackedStringArray]:
	var assets: Dictionary[String, PackedStringArray] = {}
	for trader in sim.world.traders:
		if trader.id == WorldState.PLAYER_ID:
			continue
		var keys := PackedStringArray()
		for ship in trader.ships:
			keys.append("ship/%s/%s" % [ship.id, ship.type_id])
		for kontor in trader.kontors_in_order(sim.data.cities):
			for workshop in kontor.workshops:
				keys.append("workshop/%s/%s/%s" % [workshop.id, kontor.city_id, workshop.type_id])
		if trader.bankrupt:
			keys.append("bankrupt")
		assets[trader.id] = keys
	return assets


## Notifies when a rival house bought a ship, opened or closed a workshop, went bankrupt, or was
## sold off. Ships and workshops that changed hands in a deal are reported as deals instead.
func _notify_rival_news(before: Dictionary[String, PackedStringArray]) -> void:
	var now := _rival_assets()
	var known := PackedStringArray()
	for keys: PackedStringArray in before.values():
		for key in keys:
			known.append(key.get_slice("/", 1))
	for rival in sim.data.rivals:
		var trader := sim.world.get_trader(rival.id)
		if before.has(rival.id) and trader == null and not _bought_out(rival.id):
			notify("%s's last assets were sold off" % rival.name)
		if (
			trader != null
			and trader.bankrupt
			and before.has(rival.id)
			and not before[rival.id].has("bankrupt")
		):
			notify(
				(
					"%s is bankrupt: its ships and kontors are for sale until day %d (Houses)"
					% [rival.name, trader.sale_end_day]
				)
			)
	for trader in sim.world.traders:
		if not before.has(trader.id) or not now.has(trader.id):
			continue
		for key in now[trader.id]:
			if not before[trader.id].has(key) and not known.has(key.get_slice("/", 1)):
				notify("%s %s" % [trader.name, _describe_asset(key, true)])
		for key in before[trader.id]:
			if (
				not now[trader.id].has(key)
				and key.begins_with("workshop/")
				and not _still_owned(key)
			):
				notify("%s %s" % [trader.name, _describe_asset(key, false)])


## True if the house left the game in a buy-out, which _notify_deals reports.
func _bought_out(house_id: String) -> bool:
	for deal in sim.world.deals:
		if deal.buy_out and deal.seller_id == house_id:
			return true
	return false


## True if a workshop with this key's id still runs in any house (it changed hands).
func _still_owned(key: String) -> bool:
	var id := key.get_slice("/", 1)
	for trader in sim.world.traders:
		for kontor in trader.kontors_in_order(sim.data.cities):
			for workshop in kontor.workshops:
				if workshop.id == id:
					return true
	return false


func _reset_deal_news() -> void:
	_seen_deal = sim.world.next_deal_number - 1
	_seen_offers.clear()
	for offer in sim.world.offers:
		_seen_offers.append(offer.id)


## Reports every deal since the last report: the player's own, and the rivals'.
func _notify_deals() -> void:
	for deal in sim.world.deals:
		if deal.number <= _seen_deal:
			continue
		_seen_deal = deal.number
		notify(deal_text(deal))


## Reports each new offer for the player's assets once.
func _notify_offers() -> void:
	for offer in sim.world.offers:
		if _seen_offers.has(offer.id):
			continue
		_seen_offers.append(offer.id)
		var buyer := sim.world.get_trader(offer.buyer_id)
		var what := AcquisitionSystem.asset_name(sim.data, player(), offer.kind, offer.asset_id)
		notify("%s offers %d for %s (see Houses)" % [buyer.name, offer.price, what])


## A deal in words: "You bought the kontor in Visby from Castorp for 1200".
func deal_text(deal: DealRecord) -> String:
	var buyer := _house_name(deal.buyer_id)
	var seller := _house_name(deal.seller_id)
	if deal.buy_out:
		return "%s bought out %s for %d" % [buyer, seller, deal.price]
	var what := "a ship"
	if deal.kind == OfferState.Kind.KONTOR:
		what = "the kontor in %s" % _city_name(deal.asset_id)
	else:
		for trader in sim.world.traders:
			var ship := trader.get_ship(deal.asset_id)
			if ship != null:
				what = "the %s %s" % [sim.data.get_ship(ship.type_id).name, ship.name]
	return "%s bought %s from %s for %d" % [buyer, what, seller, deal.price]


func _house_name(house_id: String) -> String:
	if house_id == WorldState.PLAYER_ID:
		return "You"
	var rival := sim.data.get_rival(house_id)
	return rival.name if rival != null else house_id


func _describe_asset(key: String, added: bool) -> String:
	var parts := key.split("/")
	if parts[0] == "ship":
		return "bought a %s" % sim.data.get_ship(parts[2]).name
	var workshop := sim.data.get_workshop(parts[3]).name
	return "%s a %s in %s" % ["opened" if added else "closed", workshop, _city_name(parts[2])]


func _city_name(city_id: String) -> String:
	return sim.data.get_city(city_id).name
