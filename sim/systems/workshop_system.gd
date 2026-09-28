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
## staffing to its progress; it makes a full batch on the days progress reaches a whole one and
## keeps the remainder. So a workshop at 60% makes three batches in five days, with whole units and
## an exact goods ledger.


static func run_day(data: GameData, world: WorldState) -> void:
	for trader in world.traders:
		if trader.bankrupt:
			continue
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
		trader.debt += due
		return
	trader.coins -= due
	workshop.progress += staffing
	if workshop.progress < CityEconomy.PARTS_PER_UNIT:
		workshop.status = WorkshopState.Status.WORKED
		return

	var inputs_total := 0
	for good in data.goods:
		var needed: int = workshop_type.inputs.get(good.id, 0)
		if kontor.cargo_of(good.id) < needed:
			workshop.status = WorkshopState.Status.NO_INPUTS
			workshop.missing_good = good.id
			_stall(workshop)
			return
		inputs_total += needed
	var room := data.kontor.capacity - kontor.cargo_total() + inputs_total
	if workshop_type.output_per_day > room:
		workshop.status = WorkshopState.Status.KONTOR_FULL
		_stall(workshop)
		return

	for good in data.goods:
		var needed: int = workshop_type.inputs.get(good.id, 0)
		if needed > 0:
			kontor.change_cargo(good.id, -needed)
			world.goods_ledger[good.id] -= needed
	kontor.change_cargo(workshop_type.output, workshop_type.output_per_day)
	world.goods_ledger[workshop_type.output] += workshop_type.output_per_day
	# Keep the remainder: at 60% staffing progress runs 0.6, 1.2 (batch, 0.2 left), 0.8, 1.4
	# (batch, 0.4 left), 1.0 (batch), so three batches in five days.
	workshop.progress -= CityEconomy.PARTS_PER_UNIT
	workshop.status = WorkshopState.Status.WORKED


## A workshop that has a batch due but can't make it keeps at most that one batch, so it doesn't
## bank days for a burst once inputs or room return.
static func _stall(workshop: WorkshopState) -> void:
	workshop.progress = mini(workshop.progress, CityEconomy.PARTS_PER_UNIT)
