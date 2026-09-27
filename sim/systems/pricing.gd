class_name Pricing
extends RefCounted
## Market price rules (ADR 0003). Stateless: callers pass one good's stock and target in one city.
##
## Every unit of stock has a position: the unit that raises stock from p to p + 1 sits at
## position p. Its mid price falls exponentially as the position grows relative to the target:
##     mid(p) = base_price * max(min_mult, max_mult ^ (1 - p / target))
## so an empty market asks max_mult × base, a market at target asks base, and a flooded market
## bottoms out at min_mult × base. Buying takes the top units (positions stock-1, stock-2, ...),
## selling adds units on top (positions stock, stock+1, ...). Large trades therefore walk the
## curve, and buying then selling the same units always loses the spread.


## Mid price of the unit at `position` in a market whose target stock is `target`.
static func mid_price(economy: EconomyDef, base_price: int, target: int, position: int) -> float:
	var fill := float(position) / float(maxi(target, 1))
	var multiplier := pow(economy.price_max_multiplier, 1.0 - fill)
	return base_price * maxf(economy.price_min_multiplier, multiplier)


## Coins a trader pays for `quantity` units from a market holding `stock`.
## Rounded up, so rounding never favors the trader.
static func buy_cost(
	economy: EconomyDef, base_price: int, target: int, stock: int, quantity: int
) -> int:
	assert(quantity >= 0 and quantity <= stock, "cannot buy %d of %d" % [quantity, stock])
	var total := 0.0
	for i in quantity:
		total += mid_price(economy, base_price, target, stock - 1 - i)
	return ceili(total * (1.0 + economy.spread / 2.0))


## Coins a trader receives for selling `quantity` units into a market holding `stock`.
## Rounded down, so rounding never favors the trader.
static func sell_revenue(
	economy: EconomyDef, base_price: int, target: int, stock: int, quantity: int
) -> int:
	assert(quantity >= 0 and stock >= 0, "invalid sale of %d into %d" % [quantity, stock])
	var total := 0.0
	for i in quantity:
		total += mid_price(economy, base_price, target, stock + i)
	return floori(total * (1.0 - economy.spread / 2.0))
