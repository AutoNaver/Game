extends SceneTree
## Headless soak run: simulates the shipped data for N days, checks the economy invariants every
## day, and prints where each market ends up. Exits 1 on any violation, 2 on bad arguments.
##
## Usage: godot --headless -s res://tools/soak.gd -- [--days 365] [--seed 1]

const DEFAULT_DAYS: int = 365
const DEFAULT_SEED: int = 1
const USAGE_ERROR: int = 2


func _initialize() -> void:
	quit(_run())


func _run() -> int:
	var options := {"--days": DEFAULT_DAYS, "--seed": DEFAULT_SEED}
	var args := OS.get_cmdline_user_args()
	# Reject anything unexpected: a typo must fail loudly, never silently shorten the run.
	var i := 0
	while i < args.size():
		var flag := args[i]
		if not options.has(flag) or i + 1 >= args.size() or not args[i + 1].is_valid_int():
			printerr("Usage: soak.gd -- [--days <positive int>] [--seed <int>] (got %s)" % args)
			return USAGE_ERROR
		options[flag] = args[i + 1].to_int()
		i += 2
	var days: int = options["--days"]
	var seed_value: int = options["--seed"]
	if days <= 0:
		printerr("--days must be a positive integer (got %d)" % days)
		return USAGE_ERROR

	var loader := GameDataLoader.new()
	var data := loader.load_dir(GameDataLoader.DEFAULT_DIR)
	if data == null:
		printerr("Game data failed to load:\n%s" % "\n".join(loader.errors))
		return 1

	var sim := Simulation.new_game(data, seed_value)
	for day in days:
		sim.advance_days(1)
		var violations := EconomyInvariants.check(data, sim.world)
		if not violations.is_empty():
			printerr("Invariant violations on day %d:\n%s" % [sim.day(), "\n".join(violations)])
			return 1

	print(
		"Soak OK: %d days, seed %d. Final stock/target and price multiplier:" % [days, seed_value]
	)
	_print_markets(sim)
	return 0


func _print_markets(sim: Simulation) -> void:
	var economy := sim.data.economy
	for city in sim.world.cities:
		var cells: PackedStringArray = []
		for good in sim.data.goods:
			var stock: int = city.stock[good.id]
			var target := CityEconomy.target_stock(economy, city, good)
			var price := Pricing.mid_price(economy, good.base_price, target, stock)
			cells.append("%s %d/%d x%.2f" % [good.id, stock, target, price / good.base_price])
		print("  %-10s %s" % [city.id, ", ".join(cells)])
