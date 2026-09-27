class_name WorkshopSystem
extends RefCounted
## Daily run of every trader's workshops: pay the wages, then turn kontor inputs into output.
##
## Wages come first and are paid whenever the owner can afford them, even if the workshop then
## lacks inputs or storage room: the workers turned up. A workshop whose owner cannot pay stays
## idle, so coins never go negative.
##
## When a city has shrunk below the workers its workshops employ (CityEconomy.staffing), each
## workshop there pays only the workers it has (wages × staffing, rounded up) and adds its
## staffing to its progress; it makes a full batch on the days progress reaches a whole one. So a
## workshop at 50% makes a batch every other day, with whole units and an exact goods ledger.


static func run_day(data: GameData, world: WorldState) -> void:
	for trader in world.traders:
		for kontor in trader.kontors_in_order(data.cities):
			var staffing := CityEconomy.staffing(data, world, world.get_city(kontor.city_id))
			for workshop in kontor.workshops:
				_run(data, world, trader, kontor, workshop, staffing)


## Wages due for a day at `staffing` (millionths): the full wages when fully staffed, else that
## share of them, rounded up.
static func wages(workshop_type: WorkshopDef, staffing: int) -> int:
	var scaled := workshop_type.wages_per_day * staffing
	@warning_ignore("integer_division")
	return (scaled + CityEconomy.PARTS_PER_UNIT - 1) / CityEconomy.PARTS_PER_UNIT


static func _run(
	data: GameData,
	world: WorldState,
	trader: TraderState,
	kontor: KontorState,
	workshop: WorkshopState,
	staffing: int,
) -> void:
	var workshop_type := data.get_workshop(workshop.type_id)
	workshop.missing_good = ""
	var due := wages(workshop_type, staffing)
	if trader.coins < due:
		workshop.status = WorkshopState.Status.UNPAID
		return
	trader.coins -= due
	# Capped at one batch: a workshop that can't finish (no inputs, kontor full) doesn't bank days.
	workshop.progress = mini(workshop.progress + staffing, CityEconomy.PARTS_PER_UNIT)
	if workshop.progress < CityEconomy.PARTS_PER_UNIT:
		workshop.status = WorkshopState.Status.WORKED
		return

	var inputs_total := 0
	for good in data.goods:
		var needed: int = workshop_type.inputs.get(good.id, 0)
		if kontor.cargo_of(good.id) < needed:
			workshop.status = WorkshopState.Status.NO_INPUTS
			workshop.missing_good = good.id
			return
		inputs_total += needed
	var room := data.kontor.capacity - kontor.cargo_total() + inputs_total
	if workshop_type.output_per_day > room:
		workshop.status = WorkshopState.Status.KONTOR_FULL
		return

	for good in data.goods:
		var needed: int = workshop_type.inputs.get(good.id, 0)
		if needed > 0:
			kontor.change_cargo(good.id, -needed)
			world.goods_ledger[good.id] -= needed
	kontor.change_cargo(workshop_type.output, workshop_type.output_per_day)
	world.goods_ledger[workshop_type.output] += workshop_type.output_per_day
	workshop.progress = 0
	workshop.status = WorkshopState.Status.WORKED
