class_name WorkshopSystem
extends RefCounted
## Daily run of every trader's workshops: pay the wages, then turn kontor inputs into output.
##
## Wages come first and are paid whenever the owner can afford them, even if the workshop then
## lacks inputs or storage room: the workers turned up. A workshop whose owner cannot pay stays
## idle, so coins never go negative.


static func run_day(data: GameData, world: WorldState) -> void:
	for trader in world.traders:
		for kontor in trader.kontors_in_order(data.cities):
			for workshop in kontor.workshops:
				_run(data, world, trader, kontor, workshop)


static func _run(
	data: GameData,
	world: WorldState,
	trader: TraderState,
	kontor: KontorState,
	workshop: WorkshopState,
) -> void:
	var workshop_type := data.get_workshop(workshop.type_id)
	workshop.missing_good = ""
	if trader.coins < workshop_type.wages_per_day:
		workshop.status = WorkshopState.Status.UNPAID
		return
	trader.coins -= workshop_type.wages_per_day

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
	workshop.status = WorkshopState.Status.WORKED
