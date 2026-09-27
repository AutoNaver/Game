extends SceneTree
## Balance probe: a greedy bot plays the player's starting fleet on the shipped data and reports
## coins over time, so balance changes can be compared by numbers rather than by feel.
##
## On each arrival the bot sells all cargo, then buys the good with the best estimated profit per
## hour of sailing (full load, price walk included) and sails there. Not an AI trader: no kontors,
## no workshops, one ship. The rival houses (data/rivals.json, ADR 0008) play alongside it as in a
## real game, and their coins, ships and workshops are reported too. Exits 1 if the economy
## invariants break.
##
## Usage: godot --headless -s res://tools/balance.gd -- [--days 365] [--seed 1]

const DEFAULT_DAYS: int = 365
## The seed only matters for the rivals' choices; the bot itself draws nothing from the RNG.
const DEFAULT_SEED: int = 1
const USAGE_ERROR: int = 2
const REPORT_EVERY_DAYS: int = 30


func _initialize() -> void:
	quit(_run())


func _run() -> int:
	var options := {"--days": DEFAULT_DAYS, "--seed": DEFAULT_SEED}
	var args := OS.get_cmdline_user_args()
	var i := 0
	while i < args.size():
		if not options.has(args[i]) or i + 1 >= args.size() or not args[i + 1].is_valid_int():
			printerr("Usage: balance.gd -- [--days <positive int>] [--seed <int>] (got %s)" % args)
			return USAGE_ERROR
		options[args[i]] = args[i + 1].to_int()
		i += 2
	var days: int = options["--days"]
	var data := GameDataLoader.new().load_dir(GameDataLoader.DEFAULT_DIR)
	if data == null:
		printerr("Game data failed to load")
		return 1
	var sim := Simulation.new_game(data, options["--seed"])
	var voyages := 0
	for day in days:
		for hour in Simulation.HOURS_PER_DAY:
			for ship in sim.world.player().ships:
				if ship.is_docked() and _trade_and_sail(sim, ship):
					voyages += 1
			sim.tick()
		if (day + 1) % REPORT_EVERY_DAYS == 0:
			print("day %3d: %6d coins, %d voyages" % [day + 1, sim.world.player().coins, voyages])
			_print_rivals(sim)
		var violations := EconomyInvariants.check(data, sim.world)
		if not violations.is_empty():
			printerr("\n".join(violations))
			return 1
	return 0


## Sells everything aboard, buys the most profitable load and sails. False if nothing pays.
func _trade_and_sail(sim: Simulation, ship: ShipState) -> bool:
	var player := WorldState.PLAYER_ID
	for good in sim.data.goods:
		if ship.cargo_of(good.id) > 0:
			sim.execute(SellCommand.new(player, ship.id, good.id, ship.cargo_of(good.id)))
	var best := _best_trade(sim, ship)
	if best.is_empty():
		return false
	sim.execute(BuyCommand.new(player, ship.id, best["good"], best["quantity"]))
	return sim.execute(SailCommand.new(player, ship.id, best["to"])).is_empty()


func _best_trade(sim: Simulation, ship: ShipState) -> Dictionary:
	var economy := sim.data.economy
	var ship_type := sim.data.get_ship(ship.type_id)
	var here := sim.world.get_city(ship.docked_at)
	var coins := sim.world.player().coins
	var best := {}
	var best_rate := 0.0
	for good in sim.data.goods:
		var quantity := mini(ship_type.capacity, here.stock[good.id])
		while quantity > 0 and CityEconomy.buy_cost(economy, here, good, quantity) > coins:
			quantity -= 1
		if quantity == 0:
			continue
		var cost := CityEconomy.buy_cost(economy, here, good, quantity)
		for city in sim.world.cities:
			if city.id == here.id:
				continue
			var profit := CityEconomy.sell_revenue(economy, city, good, quantity) - cost
			var hours := Navigation.travel_hours(sim.data, ship_type, here.id, city.id)
			var rate := float(profit) / hours
			if rate > best_rate:
				best_rate = rate
				best = {"good": good.id, "quantity": quantity, "to": city.id}
	return best


func _print_rivals(sim: Simulation) -> void:
	for trader in sim.world.traders:
		if trader.id == WorldState.PLAYER_ID:
			continue
		var workshops := 0
		for kontor in trader.kontors_in_order(sim.data.cities):
			workshops += kontor.workshops.size()
		var line := "         %-14s %6d coins, %d ships, %d kontors, %d workshops, worth %d"
		var worth := HouseValue.net_worth(sim.data, trader)
		print(
			(
				line
				% [
					trader.name,
					trader.coins,
					trader.ships.size(),
					trader.kontors.size(),
					workshops,
					worth
				]
			)
		)
