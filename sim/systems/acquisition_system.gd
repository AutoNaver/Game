class_name AcquisitionSystem
extends RefCounted
## Deals between houses (ADR 0016): prices, who agrees, moving ownership, buying out a whole house,
## bankruptcy sales, rivals' offers to the player, and the rivals' own deals. Deals move only coins
## and ownership: goods never appear or vanish, except that a buy-out's goods that don't fit the
## buyer's kontor are sold into that city's market like any sale.


## What a ship or kontor is worth (HouseValue), or 0 if the seller doesn't own it.
static func asset_value(
	data: GameData, seller: TraderState, kind: OfferState.Kind, asset_id: String
) -> int:
	if kind == OfferState.Kind.SHIP:
		var ship := seller.get_ship(asset_id)
		return HouseValue.ship_value(data, ship) if ship != null else 0
	var kontor := seller.get_kontor(asset_id)
	return HouseValue.kontor_value(data, kontor) if kontor != null else 0


## The asking price: the value times the premium, or times the discount while the seller is
## bankrupt. At least 1 coin.
static func asking_price(
	data: GameData, seller: TraderState, kind: OfferState.Kind, asset_id: String
) -> int:
	var rules := data.acquisitions
	var factor := rules.bankruptcy_discount if seller.bankrupt else rules.asset_premium
	return maxi(1, ceili(asset_value(data, seller, kind, asset_id) * factor))


## What a whole house costs: its net worth times the buy-out premium.
static func buy_out_price(data: GameData, target: TraderState) -> int:
	return maxi(1, ceili(HouseValue.net_worth(data, target) * data.acquisitions.buy_out_premium))


## For messages: "the Cog Adler" or "the kontor in Visby".
static func asset_name(
	data: GameData, seller: TraderState, kind: OfferState.Kind, asset_id: String
) -> String:
	if kind == OfferState.Kind.SHIP:
		var ship := seller.get_ship(asset_id)
		if ship == null:
			return "ship '%s'" % asset_id
		return "the %s %s" % [data.get_ship(ship.type_id).name, ship.name]
	var city := data.get_city(asset_id)
	return "the kontor in %s" % (city.name if city != null else "'%s'" % asset_id)


## "" if the seller owns the asset and it can change hands now, otherwise why not.
static func asset_error(
	data: GameData, seller: TraderState, kind: OfferState.Kind, asset_id: String
) -> String:
	var has := "You have" if seller.id == WorldState.PLAYER_ID else "%s has" % seller.name
	if kind == OfferState.Kind.KONTOR:
		if seller.get_kontor(asset_id) == null:
			return "%s no kontor in %s" % [has, _city_name(data, asset_id)]
		return ""
	var ship := seller.get_ship(asset_id)
	if ship == null:
		return "%s no ship '%s'" % [has, asset_id]
	if not ship.is_docked():
		return "%s is at sea" % ship.name
	if seller.id == WorldState.PLAYER_ID and seller.person_ship_id == ship.id:
		return "Go ashore before selling %s" % ship.name
	return ""


## "" if the buyer's rank, kontors and reputation let it take the asset, otherwise why not.
static func take_error(
	data: GameData, buyer: TraderState, seller: TraderState, kind: OfferState.Kind, asset_id: String
) -> String:
	if kind == OfferState.Kind.SHIP:
		var ship := seller.get_ship(asset_id)
		return RankSystem.ship_error(data, buyer, data.get_ship(ship.type_id))
	if buyer.get_kontor(asset_id) != null:
		var has := (
			"You already have"
			if buyer.id == WorldState.PLAYER_ID
			else "%s already has" % buyer.name
		)
		return "%s a kontor in %s" % [has, _city_name(data, asset_id)]
	return RankSystem.kontor_error(data, buyer, asset_id)


## "" if a rival agrees to sell at the asking price, otherwise its reason. A bankrupt house sells
## anything. Otherwise a rival sells when it is short of coins (below its cash reserve), or a
## kontor whose workshops all lose money at today's prices (or that has none), but never its last
## ship.
static func refusal(
	sim: Simulation, seller: TraderState, kind: OfferState.Kind, asset_id: String
) -> String:
	if seller.bankrupt:
		return ""
	if kind == OfferState.Kind.SHIP and seller.ships.size() <= 1:
		return "%s won't sell its last ship" % seller.name
	if seller.coins < sim.data.rival_ai.cash_reserve:
		return ""
	if kind == OfferState.Kind.KONTOR and not _kontor_pays(sim, seller.get_kontor(asset_id)):
		return ""
	var what := "needs its ships" if kind == OfferState.Kind.SHIP else "its kontor there pays"
	return "%s refuses: it has coins to spare and %s" % [seller.name, what]


## Moves a ship, its captain and cargo from seller to buyer. It leaves any trade route.
static func transfer_ship(seller: TraderState, buyer: TraderState, ship: ShipState) -> void:
	seller.remove_ship(ship.id)
	AssignRouteCommand.clear_route(ship)
	var captain := seller.get_captain(ship.captain_id)
	if captain != null:
		seller.captains.erase(captain)
		buyer.captains.append(captain)
	buyer.ships.append(ship)


## Moves a kontor with its workshops and goods. Its factor orders stay only if the buyer's rank
## unlocks factors.
static func transfer_kontor(
	data: GameData, seller: TraderState, buyer: TraderState, city_id: String
) -> void:
	var kontor := seller.get_kontor(city_id)
	seller.kontors.erase(city_id)
	if not RankSystem.has_unlock(data, buyer, RankDef.FACTORS):
		kontor.factor_orders.clear()
	buyer.kontors[city_id] = kontor


## Carries out a sale of one asset at `price` and logs it.
static func sell_asset(
	sim: Simulation,
	seller: TraderState,
	buyer: TraderState,
	kind: OfferState.Kind,
	asset_id: String,
	price: int,
) -> void:
	buyer.coins -= price
	seller.coins += price
	if kind == OfferState.Kind.SHIP:
		transfer_ship(seller, buyer, seller.get_ship(asset_id))
	else:
		transfer_kontor(sim.data, seller, buyer, asset_id)
	_log(sim, buyer, seller, false, kind, asset_id, price)


## The buyer pays `price` and takes over the whole house: its coins, ships with their captains,
## kontors (merged into the buyer's own kontor in a city where it has one) and what its market
## book knows. The house leaves the game and its debt is written off.
static func buy_out(sim: Simulation, buyer: TraderState, target: TraderState, price: int) -> void:
	var data := sim.data
	buyer.coins -= price
	buyer.coins += target.coins
	target.coins = 0
	for ship: ShipState in target.ships.duplicate():
		transfer_ship(target, buyer, ship)
	for kontor in target.kontors_in_order(data.cities):
		if buyer.get_kontor(kontor.city_id) == null:
			transfer_kontor(data, target, buyer, kontor.city_id)
		else:
			_merge_kontor(sim, buyer, kontor)
	for city in data.cities:
		MarketKnowledgeSystem.learn(buyer, target.market_book.get(city.id))
	_log(sim, buyer, target, true, OfferState.Kind.SHIP, "", price)
	remove_house(sim.world, target)


## Takes a house out of the game, with the offers it made.
static func remove_house(world: WorldState, trader: TraderState) -> void:
	world.traders.erase(trader)
	for offer: OfferState in world.offers.duplicate():
		if offer.buyer_id == trader.id:
			world.offers.erase(offer)


## A rival house goes bankrupt: its assets go up for sale until the sale ends, and its offers lapse.
static func declare_bankrupt(
	data: GameData, world: WorldState, trader: TraderState, day: int
) -> void:
	trader.bankrupt = true
	if trader.id == WorldState.PLAYER_ID:
		return
	trader.sale_end_day = day + data.acquisitions.bankruptcy_sale_days
	for offer: OfferState in world.offers.duplicate():
		if offer.buyer_id == trader.id:
			world.offers.erase(offer)


## Daily: offers past their last day lapse, old deal news is dropped, and bankrupt houses whose
## sale has ended are sold off: their goods go into the local markets and the rest is retired.
static func run_day(data: GameData, world: WorldState, day: int) -> void:
	for offer: OfferState in world.offers.duplicate():
		if offer.last_day < day:
			world.offers.erase(offer)
	for deal: DealRecord in world.deals.duplicate():
		if deal.day < day - DealRecord.DEAL_LOG_DAYS:
			world.deals.erase(deal)
	for trader: TraderState in world.traders.duplicate():
		if trader.bankrupt and trader.id != WorldState.PLAYER_ID and day >= trader.sale_end_day:
			_liquidate(data, world, trader)


## A rival's deals on its expansion days, before it expands: buy out a house it far outgrew, pick
## up a bankrupt house's ships and kontors, buy a ship from another rival, and maybe make the player
## an offer. Everything goes through the same commands the player uses.
static func run_rival(sim: Simulation, trader: TraderState) -> void:
	var ai := sim.data.rival_ai
	for target: TraderState in sim.world.traders.duplicate():
		if target == trader or target.id == WorldState.PLAYER_ID:
			continue
		var buy_out_command := BuyOutHouseCommand.new(trader.id, target.id)
		if trader.coins - buy_out_price(sim.data, target) >= ai.cash_reserve:
			if sim.execute(buy_out_command).is_empty():
				return
	for seller: TraderState in sim.world.traders.duplicate():
		if seller == trader or seller.id == WorldState.PLAYER_ID:
			continue
		for ship: ShipState in seller.ships.duplicate():
			if (
				trader.ships.size() >= ai.max_ships
				or (not seller.bankrupt and not _may_buy(sim, trader))
			):
				break
			_try_buy(sim, trader, seller, OfferState.Kind.SHIP, ship.id)
		if not seller.bankrupt:
			continue
		for kontor in seller.kontors_in_order(sim.data.cities):
			if trader.kontors.size() >= ai.max_kontors:
				break
			_try_buy(sim, trader, seller, OfferState.Kind.KONTOR, kontor.city_id)
	_maybe_offer(sim, trader)


## Makes the player an offer for a kontor the rival could take (one with workshops first), or else
## a docked ship if its fleet has room, at the asking price. At most one standing offer per rival.
static func _maybe_offer(sim: Simulation, trader: TraderState) -> void:
	if not _may_buy(sim, trader):
		return
	for offer in sim.world.offers:
		if offer.buyer_id == trader.id:
			return
	if sim.world.rng.randf() >= sim.data.acquisitions.offer_chance:
		return
	var player := sim.world.player()
	if player == null or player.bankrupt:
		return
	var budget := trader.coins - sim.data.rival_ai.cash_reserve
	var choice := _offer_choice(sim, trader, player, budget)
	if choice.is_empty():
		return
	var kind: OfferState.Kind = choice["kind"]
	var asset_id: String = choice["id"]
	var offer := OfferState.new(
		"offer_%d" % sim.world.next_offer_number,
		trader.id,
		kind,
		asset_id,
		asking_price(sim.data, player, kind, asset_id),
		sim.day() + sim.data.acquisitions.offer_days
	)
	sim.world.next_offer_number += 1
	sim.world.offers.append(offer)


static func _offer_choice(
	sim: Simulation, trader: TraderState, player: TraderState, budget: int
) -> Dictionary:
	var fallback := {}
	for kontor in player.kontors_in_order(sim.data.cities):
		if trader.kontors.size() >= sim.data.rival_ai.max_kontors:
			break
		if not _can_take(sim, trader, player, OfferState.Kind.KONTOR, kontor.city_id, budget):
			continue
		if not kontor.workshops.is_empty():
			return {"kind": OfferState.Kind.KONTOR, "id": kontor.city_id}
		if fallback.is_empty():
			fallback = {"kind": OfferState.Kind.KONTOR, "id": kontor.city_id}
	if not fallback.is_empty():
		return fallback
	if trader.ships.size() >= sim.data.rival_ai.max_ships:
		return {}
	for ship in player.ships:
		if _can_take(sim, trader, player, OfferState.Kind.SHIP, ship.id, budget):
			return {"kind": OfferState.Kind.SHIP, "id": ship.id}
	return {}


static func _can_take(
	sim: Simulation,
	buyer: TraderState,
	seller: TraderState,
	kind: OfferState.Kind,
	asset_id: String,
	budget: int,
) -> bool:
	if not asset_error(sim.data, seller, kind, asset_id).is_empty():
		return false
	if not take_error(sim.data, buyer, seller, kind, asset_id).is_empty():
		return false
	return asking_price(sim.data, seller, kind, asset_id) <= budget


static func _try_buy(
	sim: Simulation,
	trader: TraderState,
	seller: TraderState,
	kind: OfferState.Kind,
	asset_id: String
) -> void:
	var budget := trader.coins - sim.data.rival_ai.cash_reserve
	if asking_price(sim.data, seller, kind, asset_id) > budget:
		return
	sim.execute(BuyAssetCommand.new(trader.id, seller.id, kind, asset_id))


static func _may_buy(sim: Simulation, trader: TraderState) -> bool:
	return RankSystem.has_unlock(sim.data, trader, RankDef.BUY_ASSETS)


## True if the kontor has workshops and at least one makes money at today's prices.
static func _kontor_pays(sim: Simulation, kontor: KontorState) -> bool:
	var city := sim.world.get_city(kontor.city_id)
	for workshop in kontor.workshops:
		if RivalSystem.daily_margin(sim, city, sim.data.get_workshop(workshop.type_id)) >= 0.0:
			return true
	return false


## Moves a bought-out kontor's workshops and goods into the buyer's kontor in the same city. Goods
## beyond its room are sold into the city's market for the buyer.
static func _merge_kontor(sim: Simulation, buyer: TraderState, kontor: KontorState) -> void:
	var own := buyer.get_kontor(kontor.city_id)
	own.workshops.append_array(kontor.workshops)
	var city := sim.world.get_city(kontor.city_id)
	for good in sim.data.goods:
		var amount := kontor.cargo_of(good.id)
		if amount <= 0:
			continue
		var fits := mini(amount, sim.data.kontor.capacity - own.cargo_total())
		own.change_cargo(good.id, fits)
		var rest := amount - fits
		if rest > 0:
			buyer.coins += CityEconomy.sell_revenue(sim.data.economy, city, good, rest)
			city.stock[good.id] += rest
		kontor.change_cargo(good.id, -amount)


## Retires a house whose bankruptcy sale has ended: goods go into the local markets (ships at sea
## unload at their destination), ships and workshops are retired.
static func _liquidate(data: GameData, world: WorldState, trader: TraderState) -> void:
	for ship in trader.ships:
		var city_id := ship.docked_at if ship.is_docked() else ship.destination
		var city := world.get_city(city_id)
		for good in data.goods:
			city.stock[good.id] += ship.cargo_of(good.id)
	for kontor in trader.kontors_in_order(data.cities):
		var city := world.get_city(kontor.city_id)
		for good in data.goods:
			city.stock[good.id] += kontor.cargo_of(good.id)
	remove_house(world, trader)


static func _log(
	sim: Simulation,
	buyer: TraderState,
	seller: TraderState,
	whole: bool,
	kind: OfferState.Kind,
	asset_id: String,
	price: int,
) -> void:
	var deal := DealRecord.new(
		sim.world.next_deal_number, sim.day(), buyer.id, seller.id, whole, kind, asset_id, price
	)
	sim.world.next_deal_number += 1
	sim.world.deals.append(deal)


## "You" for the player, else the house's name.
static func house_name(trader: TraderState) -> String:
	return "You" if trader.id == WorldState.PLAYER_ID else trader.name


static func _city_name(data: GameData, city_id: String) -> String:
	var city := data.get_city(city_id)
	return city.name if city != null else "'%s'" % city_id
