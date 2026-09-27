extends SceneTree
## Headless soak run: simulates the shipped data for N days, checks the economy invariants every
## day, and prints where each market ends up. Then checks that no city exploded or starved without
## the player (check_populations). Exits 1 on any violation, 2 on bad arguments.
##
## Usage: godot --headless -s res://tools/soak.gd -- [--days 365] [--seed 1]

const DEFAULT_DAYS: int = 365
const DEFAULT_SEED: int = 1
const USAGE_ERROR: int = 2
## Without the player, every city must end within this band around its home population
## (data/cities.json), and never at the hard bounds of data/population.json (ADR 0010).
const SETTLED_LOW: float = 0.8
const SETTLED_HIGH: float = 1.25


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
	var lost: Dictionary[String, int] = {}
	for day in days:
		sim.advance_days(1)
		for loss in sim.world.losses:
			lost[loss.cause] = lost.get(loss.cause, 0) + loss.units
		var violations := EconomyInvariants.check(data, sim.world)
		if not violations.is_empty():
			printerr("Invariant violations on day %d:\n%s" % [sim.day(), "\n".join(violations)])
			return 1

	print("Final stock/target and price multiplier after %d days, seed %d:" % [days, seed_value])
	_print_markets(sim)
	_print_cities(sim)
	print("  events started: %d; goods lost by cause: %s" % [sim.world.next_event_number - 1, lost])
	var problems := check_populations(data, sim.world)
	if not problems.is_empty():
		printerr("Cities out of balance:\n%s" % "\n".join(problems))
		return 1
	print("Soak OK")
	return 0


## One message per city whose population left the settled band or sits at a hard bound.
static func check_populations(data: GameData, world: WorldState) -> PackedStringArray:
	var problems: PackedStringArray = []
	for city in world.cities:
		var home := data.get_city(city.id).population
		var ratio := float(city.population) / home
		if ratio < SETTLED_LOW or ratio > SETTLED_HIGH:
			var band := [city.id, city.population, ratio, SETTLED_LOW, SETTLED_HIGH]
			problems.append("%s: population %d is %.2fx home, outside %.2f to %.2f" % band)
		var lowest := data.population.min_population(home)
		var highest := data.population.max_population(home)
		if city.population <= lowest or city.population >= highest:
			problems.append("%s: population %d at a hard bound" % [city.id, city.population])
	return problems


func _print_cities(sim: Simulation) -> void:
	for city in sim.world.cities:
		var home := sim.data.get_city(city.id).population
		var sizes := [
			city.id,
			city.population,
			float(city.population) / home,
			city.satisfaction / float(CityEconomy.PARTS_PER_UNIT) * 100.0,
		]
		print("  %-10s population %d (%.2fx home), satisfaction %.0f%%" % sizes)


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
