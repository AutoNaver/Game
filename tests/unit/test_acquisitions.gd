extends GutTest
## Deals between houses (ADR 0016): buying ships and kontors, rivals' offers to the player,
## buying out a house, and bankruptcy sales. Deals move only coins and ownership.

const SmallWorld := preload("res://tests/support/small_world.gd")
const PLAYER := WorldState.PLAYER_ID
const RIVAL := SmallWorld.RIVAL_ID
const SHIP := OfferState.Kind.SHIP
const KONTOR := OfferState.Kind.KONTOR

var _sim: Simulation


func before_each() -> void:
	_sim = SmallWorld.rival_simulation()
	_player().coins = 20_000


func _player() -> TraderState:
	return _sim.world.player()


func _rival() -> TraderState:
	return _sim.world.get_trader(RIVAL)


func _ok(command: Command) -> void:
	assert_eq(_sim.execute(command), "")


func _healthy() -> void:
	assert_eq(EconomyInvariants.check(_sim.data, _sim.world), PackedStringArray())


## Gives the rival a second boat, docked in port.
func _second_rival_ship() -> ShipState:
	var ship := _sim.world.add_ship(_rival(), "boat", "Spare", "port")
	_sim.world.add_captain(_rival(), "Spare captain", 2, ship)
	return ship


func test_a_rival_keeps_its_last_ship_and_ships_it_needs() -> void:
	var first := _rival().ships[0].id
	assert_eq(
		_sim.execute(BuyAssetCommand.new(PLAYER, RIVAL, SHIP, first)),
		"Hanse won't sell its last ship"
	)
	var spare := _second_rival_ship()
	assert_eq(
		_sim.execute(BuyAssetCommand.new(PLAYER, RIVAL, SHIP, spare.id)),
		"Hanse refuses: it has coins to spare and needs its ships"
	)


func test_a_rival_short_of_coins_sells_a_ship_with_its_captain_and_cargo() -> void:
	var spare := _second_rival_ship()
	SmallWorld.give_cargo(_sim, spare, "grain", 4)
	_rival().coins = SmallWorld.RIVAL_RESERVE - 1
	var value := 300 + 4 * 40
	assert_eq(HouseValue.ship_value(_sim.data, spare), value)
	var price := AcquisitionSystem.asking_price(_sim.data, _rival(), SHIP, spare.id)
	assert_eq(price, ceili(value * 1.5))
	var captain := spare.captain_id
	_ok(BuyAssetCommand.new(PLAYER, RIVAL, SHIP, spare.id))
	assert_eq(_player().coins, 20_000 - price)
	assert_eq(_rival().coins, SmallWorld.RIVAL_RESERVE - 1 + price)
	assert_not_null(_player().get_ship(spare.id))
	assert_null(_rival().get_ship(spare.id))
	assert_not_null(_player().get_captain(captain), "the captain comes with the ship")
	assert_eq(spare.cargo, {"grain": 4})
	var deal: DealRecord = _sim.world.deals[-1]
	assert_eq(
		[deal.buyer_id, deal.seller_id, deal.asset_id, deal.price], [PLAYER, RIVAL, spare.id, price]
	)
	_healthy()


func test_a_rival_sells_a_kontor_that_earns_nothing_but_not_one_that_pays() -> void:
	_rival().coins = 5000
	_ok(BuyKontorCommand.new(RIVAL, "town"))
	_rival().get_kontor("town").change_cargo("wine", 2)
	_sim.world.goods_ledger["wine"] += 2
	var price := AcquisitionSystem.asking_price(_sim.data, _rival(), KONTOR, "town")
	assert_eq(price, ceili((300 + 2 * 220) * 1.5))
	_ok(BuyAssetCommand.new(PLAYER, RIVAL, KONTOR, "town"))
	assert_eq(_player().get_kontor("town").cargo, {"wine": 2})
	assert_null(_rival().get_kontor("town"))
	assert_eq(
		_sim.execute(BuyAssetCommand.new(RIVAL, PLAYER, KONTOR, "town")),
		"The player sells only by accepting offers"
	)
	_healthy()


func test_buyers_keep_to_their_rank_and_kontors() -> void:
	_ok(BuyKontorCommand.new(PLAYER, "town"))
	_rival().coins = 5000
	_ok(BuyKontorCommand.new(RIVAL, "town"))
	assert_eq(
		_sim.execute(BuyAssetCommand.new(PLAYER, RIVAL, KONTOR, "town")),
		"You already have a kontor in Town"
	)
	var ranked := Simulation.new_game(
		SmallWorld.with_ranks(SmallWorld.with_rival(SmallWorld.data())), 1
	)
	ranked.world.get_trader(RIVAL).coins = 5000
	ranked.world.get_trader(RIVAL).rank_id = "merchant"
	assert_eq(ranked.execute(BuyKontorCommand.new(RIVAL, "port")), "")
	ranked.world.player().rank_id = "house"
	ranked.world.player().coins = 10_000
	assert_eq(
		ranked.execute(BuyAssetCommand.new(PLAYER, RIVAL, KONTOR, "port")),
		"Purchases from other houses are not available",
		"no rank of that ladder unlocks buying assets"
	)


func test_rivals_offer_for_the_players_assets_and_the_player_answers() -> void:
	_rival().coins = 50_000
	_ok(BuyKontorCommand.new(PLAYER, "town"))
	AcquisitionSystem.run_rival(_sim, _rival())
	assert_eq(_sim.world.offers.size(), 1)
	var offer := _sim.world.offers[0]
	assert_eq([offer.buyer_id, offer.kind, offer.asset_id], [RIVAL, KONTOR, "town"])
	assert_eq(offer.price, ceili(300 * 1.5))
	assert_eq(offer.last_day, _sim.day() + 3)
	AcquisitionSystem.run_rival(_sim, _rival())
	assert_eq(_sim.world.offers.size(), 1, "one standing offer per rival")
	var coins := _player().coins
	_ok(AnswerOfferCommand.new(offer.id, true))
	assert_eq(_player().coins, coins + offer.price)
	assert_not_null(_rival().get_kontor("town"))
	assert_true(_sim.world.offers.is_empty())
	_healthy()


func test_refused_and_lapsed_offers_end() -> void:
	_rival().coins = 50_000
	_ok(BuyKontorCommand.new(PLAYER, "town"))
	AcquisitionSystem.run_rival(_sim, _rival())
	_ok(AnswerOfferCommand.new(_sim.world.offers[0].id, false))
	assert_true(_sim.world.offers.is_empty())
	assert_not_null(_player().get_kontor("town"))
	AcquisitionSystem.run_rival(_sim, _rival())
	var offer := _sim.world.offers[0]
	AcquisitionSystem.run_day(_sim.data, _sim.world, offer.last_day)
	assert_eq(_sim.world.offers.size(), 1, "still stands on its last day")
	AcquisitionSystem.run_day(_sim.data, _sim.world, offer.last_day + 1)
	assert_true(_sim.world.offers.is_empty())
	assert_eq(_sim.execute(AnswerOfferCommand.new(offer.id, true)), "unknown offer '%s'" % offer.id)


func test_an_offer_fails_if_the_asset_is_no_longer_free() -> void:
	_rival().coins = 50_000
	_ok(BuyKontorCommand.new(PLAYER, "town"))
	AcquisitionSystem.run_rival(_sim, _rival())
	var offer := _sim.world.offers[0]
	_rival().coins = 10
	assert_eq(
		_sim.execute(AnswerOfferCommand.new(offer.id, true)),
		"Hanse can no longer pay %d coins" % offer.price
	)


func test_buying_out_a_house_takes_everything_and_it_leaves() -> void:
	_ok(BuyKontorCommand.new(PLAYER, "port"))
	_rival().coins = 5000
	_ok(BuyKontorCommand.new(RIVAL, "port"))
	_ok(BuildWorkshopCommand.new(RIVAL, "port", "vintner"))
	var rival_kontor := _rival().get_kontor("port")
	rival_kontor.change_cargo("wine", 15)
	_sim.world.goods_ledger["wine"] += 15
	_player().get_kontor("port").change_cargo("grain", 10)
	_sim.world.goods_ledger["grain"] += 10
	_player().coins = 100_000
	var rival_ship := _rival().ships[0]
	var target_worth := HouseValue.net_worth(_sim.data, _rival())
	var price := AcquisitionSystem.buy_out_price(_sim.data, _rival())
	assert_eq(price, ceili(target_worth * 1.5))
	var rival_coins := _rival().coins
	var wine_stock: int = _sim.world.get_city("port").stock["wine"]
	_ok(BuyOutHouseCommand.new(PLAYER, RIVAL))
	assert_null(_sim.world.get_trader(RIVAL))
	assert_not_null(_player().get_ship(rival_ship.id))
	var kontor := _player().get_kontor("port")
	assert_eq(kontor.workshops.size(), 1, "the workshop joins the player's kontor")
	assert_eq(kontor.cargo, {"grain": 10, "wine": 10}, "what fits stays")
	assert_eq(_sim.world.get_city("port").stock["wine"], wine_stock + 5, "the rest is sold")
	assert_gt(_player().coins, 100_000 - price + rival_coins, "plus the sale of the rest")
	assert_true(_sim.world.deals[-1].buy_out)
	_healthy()


func test_a_buy_out_needs_twice_the_worth_and_never_takes_the_player() -> void:
	_player().coins = 1000
	var needed := ceili(HouseValue.net_worth(_sim.data, _rival()) * 2.0)
	assert_eq(
		_sim.execute(BuyOutHouseCommand.new(PLAYER, RIVAL)),
		(
			"Buying out Hanse needs a worth of %d (you have %d)"
			% [needed, HouseValue.net_worth(_sim.data, _player())]
		)
	)
	assert_eq(_sim.execute(BuyOutHouseCommand.new(RIVAL, PLAYER)), "Your house is not for sale")


func test_a_bankrupt_rival_sells_at_a_discount_then_is_sold_off() -> void:
	var spare := _second_rival_ship()
	SmallWorld.give_cargo(_sim, _rival().ships[0], "grain", 3)
	AcquisitionSystem.declare_bankrupt(_sim.data, _sim.world, _rival(), _sim.day())
	assert_eq(_rival().sale_end_day, _sim.day() + 5)
	var price := AcquisitionSystem.asking_price(_sim.data, _rival(), SHIP, spare.id)
	assert_eq(price, ceili(300 * 0.5))
	_ok(BuyAssetCommand.new(PLAYER, RIVAL, SHIP, spare.id))
	_healthy()
	var port_grain: int = _sim.world.get_city("port").stock["grain"]
	AcquisitionSystem.run_day(_sim.data, _sim.world, _rival().sale_end_day - 1)
	assert_not_null(_sim.world.get_trader(RIVAL), "the sale lasts until its end day")
	AcquisitionSystem.run_day(_sim.data, _sim.world, _sim.day() + 5)
	assert_null(_sim.world.get_trader(RIVAL))
	assert_eq(_sim.world.get_city("port").stock["grain"], port_grain + 3, "its goods go to market")
	_healthy()


func test_a_bankrupt_sale_needs_no_rank_unlock() -> void:
	var sim := Simulation.new_game(
		SmallWorld.with_ranks(SmallWorld.with_rival(SmallWorld.data())), 1
	)
	var rival := sim.world.get_trader(RIVAL)
	rival.coins = 5000
	rival.rank_id = "merchant"
	assert_eq(sim.execute(BuyKontorCommand.new(RIVAL, "port")), "")
	AcquisitionSystem.declare_bankrupt(sim.data, sim.world, rival, sim.day())
	sim.world.player().coins = 10_000
	assert_eq(sim.execute(BuyAssetCommand.new(PLAYER, RIVAL, KONTOR, "port")), "")


func test_rivals_buy_from_each_other() -> void:
	var data := SmallWorld.with_rival(SmallWorld.with_rival(SmallWorld.data()), "town", "guild")
	var sim := Simulation.new_game(data, 1)
	var hanse := sim.world.get_trader(RIVAL)
	var guild := sim.world.get_trader("guild")
	hanse.coins = 20_000
	guild.coins = 5000
	assert_eq(sim.execute(BuyKontorCommand.new("guild", "town")), "")
	AcquisitionSystem.declare_bankrupt(sim.data, sim.world, guild, sim.day())
	var guild_ship := guild.ships[0].id
	AcquisitionSystem.run_rival(sim, hanse)
	assert_not_null(hanse.get_ship(guild_ship), "a bankrupt house's ship")
	assert_not_null(hanse.get_kontor("town"), "and its kontor")
	assert_eq(EconomyInvariants.check(sim.data, sim.world), PackedStringArray())


func test_a_far_richer_rival_buys_out_another() -> void:
	var data := SmallWorld.with_rival(SmallWorld.with_rival(SmallWorld.data()), "town", "guild")
	var sim := Simulation.new_game(data, 1)
	sim.world.get_trader(RIVAL).coins = 50_000
	AcquisitionSystem.run_rival(sim, sim.world.get_trader(RIVAL))
	assert_null(sim.world.get_trader("guild"))
	assert_eq(sim.world.get_trader(RIVAL).ships.size(), 2)


func test_offers_and_bankruptcy_sales_save_and_old_saves_have_none() -> void:
	_rival().coins = 50_000
	_ok(BuyKontorCommand.new(PLAYER, "town"))
	AcquisitionSystem.run_rival(_sim, _rival())
	var save := SaveGame.to_dict(_sim.world)
	var loaded := SaveGame.new().from_dict(_sim.data, save)
	assert_eq(loaded.offers.size(), 1)
	assert_eq(SaveGame.to_dict(loaded), save)
	var old: Dictionary = save.duplicate(true)
	old["save_version"] = 10
	var migrated := SaveGame.new().from_dict(_sim.data, old)
	assert_true(migrated.offers.is_empty())
	save["offers"][0]["buyer"] = PLAYER
	var loader := SaveGame.new()
	assert_null(loader.from_dict(_sim.data, save))
	assert_has(loader.errors, "offers[0]: unknown buyer 'player'")


func test_a_version_10_save_keeps_its_reputation() -> void:
	ReputationSystem.add(_sim.data, _player(), "town", 15)
	var save := SaveGame.to_dict(_sim.world)
	save["save_version"] = 10
	save["traders"][0].erase("sale_end_day")
	var loaded := SaveGame.new().from_dict(_sim.data, save)
	assert_not_null(loaded)
	assert_eq(loaded.player().reputation, {"town": 15})


func test_lapsed_offers_and_ended_sales_in_saves_are_rejected() -> void:
	_rival().coins = 50_000
	_ok(BuyKontorCommand.new(PLAYER, "town"))
	AcquisitionSystem.run_rival(_sim, _rival())
	_sim.advance_days(1)
	var save := SaveGame.to_dict(_sim.world)
	save["offers"][0]["last_day"] = 0
	var loader := SaveGame.new()
	assert_null(loader.from_dict(_sim.data, save))
	assert_has(loader.errors, "offers[0]: lapsed on day 0, before day 1")
	AcquisitionSystem.declare_bankrupt(_sim.data, _sim.world, _rival(), _sim.day())
	var sale := SaveGame.to_dict(_sim.world)
	assert_not_null(SaveGame.new().from_dict(_sim.data, sale), "a running sale loads")
	sale["traders"][1]["sale_end_day"] = 1
	var refused := SaveGame.new()
	assert_null(refused.from_dict(_sim.data, sale))
	assert_has(refused.errors, "traders[1]: sale_end_day 1 must be after day 1")
