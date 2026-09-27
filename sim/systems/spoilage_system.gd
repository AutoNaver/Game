class_name SpoilageSystem
extends RefCounted
## Daily spoilage of goods stored in ships and kontors (ADR 0006, ADR 0011).
##
## Each good loses spoilage_per_day of the units stored, counted in exact millionths with a carry
## per hold and good, so a ship with 10 fish at 2% a day loses one fish every five days rather
## than nothing or a rounded amount. City markets don't spoil: their stock turns over through
## consumption and off-map trade. Losses are booked in the goods ledger and listed in
## WorldState.losses for the day.


static func run_day(data: GameData, world: WorldState) -> void:
	for trader in world.traders:
		for ship in trader.ships:
			_spoil(data, world, trader, ship, ship.id)
		for kontor in trader.kontors_in_order(data.cities):
			_spoil(data, world, trader, kontor, kontor.city_id)


## Units of `good` a hold holding `units` loses a day on average.
static func daily_loss(good: GoodDef, units: int) -> float:
	return units * good.spoilage_per_day


static func _spoil(
	data: GameData, world: WorldState, trader: TraderState, hold: Hold, hold_id: String
) -> void:
	for good in data.goods:
		var units := hold.cargo_of(good.id)
		var steps := CityEconomy.rate_steps(good.spoilage_per_day)
		if units == 0 or steps == 0:
			# Nothing left to spoil: a fraction from goods sold or unloaded doesn't follow new ones.
			hold.spoil_carry.erase(good.id)
			continue
		@warning_ignore("integer_division")
		var parts: int = (
			units * steps * (CityEconomy.PARTS_PER_UNIT / CityEconomy.RATE_STEPS)
			+ hold.spoil_carry.get(good.id, 0)
		)
		var lost := mini(CityEconomy.whole_units(parts), units)
		var carry := parts % CityEconomy.PARTS_PER_UNIT
		if carry > 0:
			hold.spoil_carry[good.id] = carry
		else:
			hold.spoil_carry.erase(good.id)
		if lost > 0:
			hold.change_cargo(good.id, -lost)
			world.goods_ledger[good.id] -= lost
			world.losses.append(
				GoodsLoss.new(trader.id, hold_id, good.id, lost, GoodsLoss.SPOILAGE)
			)
