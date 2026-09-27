extends GutTest

const BASE_PRICE: int = 100
const TARGET: int = 200

var _economy: EconomyDef = EconomyDef.new(20, 3.0, 2.5, 0.35, 0.1)


func test_mid_price_at_target_is_base_price() -> void:
	assert_almost_eq(Pricing.mid_price(_economy, BASE_PRICE, TARGET, TARGET), 100.0, 0.001)


func test_mid_price_of_empty_market_is_max_multiplier() -> void:
	assert_almost_eq(Pricing.mid_price(_economy, BASE_PRICE, TARGET, 0), 250.0, 0.001)


func test_mid_price_bottoms_out_at_min_multiplier() -> void:
	assert_almost_eq(Pricing.mid_price(_economy, BASE_PRICE, TARGET, TARGET * 10), 35.0, 0.001)


func test_mid_price_never_rises_with_stock() -> void:
	var previous := INF
	for position: int in range(0, TARGET * 5, 7):
		var price := Pricing.mid_price(_economy, BASE_PRICE, TARGET, position)
		assert_true(price <= previous, "price rose at position %d" % position)
		assert_true(price >= 35.0 and price <= 250.0, "price out of bounds at %d" % position)
		previous = price


func test_zero_target_does_not_divide_by_zero() -> void:
	var price := Pricing.mid_price(_economy, BASE_PRICE, 0, 5)
	assert_true(is_finite(price))
	assert_almost_eq(price, 35.0, 0.001)


func test_single_unit_buy_and_sell_straddle_mid_price() -> void:
	# At stock == target, the next unit to buy sits just below target, the next to sell at it.
	var buy := Pricing.buy_cost(_economy, BASE_PRICE, TARGET, TARGET, 1)
	var sell := Pricing.sell_revenue(_economy, BASE_PRICE, TARGET, TARGET, 1)
	assert_eq(buy, 106)
	assert_eq(sell, 95)


func test_buying_walks_the_price_up() -> void:
	var first_ten := Pricing.buy_cost(_economy, BASE_PRICE, TARGET, TARGET, 10)
	var next_ten := Pricing.buy_cost(_economy, BASE_PRICE, TARGET, TARGET - 10, 10)
	assert_gt(next_ten, first_ten)


func test_selling_walks_the_price_down() -> void:
	var first_ten := Pricing.sell_revenue(_economy, BASE_PRICE, TARGET, TARGET, 10)
	var next_ten := Pricing.sell_revenue(_economy, BASE_PRICE, TARGET, TARGET + 10, 10)
	assert_lt(next_ten, first_ten)


func test_dumping_cargo_crashes_the_price() -> void:
	var dump := Pricing.sell_revenue(_economy, BASE_PRICE, TARGET, TARGET, 1000)
	var last_unit := Pricing.sell_revenue(_economy, BASE_PRICE, TARGET, TARGET + 999, 1)
	assert_lt(dump, 1000 * 60, "a 1000-unit dump should average well under the base price")
	assert_eq(last_unit, floori(35.0 * 0.95))


func test_round_trip_never_makes_money() -> void:
	for stock: int in [1, 10, TARGET, TARGET * 4]:
		for quantity: int in [1, 5, stock]:
			if quantity > stock:
				continue
			var cost := Pricing.buy_cost(_economy, BASE_PRICE, TARGET, stock, quantity)
			var back := Pricing.sell_revenue(
				_economy, BASE_PRICE, TARGET, stock - quantity, quantity
			)
			assert_true(back < cost, "stock %d qty %d: %d >= %d" % [stock, quantity, back, cost])


func test_zero_quantity_costs_nothing() -> void:
	assert_eq(Pricing.buy_cost(_economy, BASE_PRICE, TARGET, 0, 0), 0)
	assert_eq(Pricing.sell_revenue(_economy, BASE_PRICE, TARGET, 0, 0), 0)
