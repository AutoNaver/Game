class_name MarketRecord
extends RefCounted
## What one house last learned about a city. Prices are stored as whole coins, and mid prices as
## hundredths of a coin. History uses -1 for days when this house had no presence there.

var city_id: String
var day: int
var population: int
var satisfaction: int
var stock: Dictionary[String, int] = {}
var shortage: Dictionary[String, int] = {}
var buy_price: Dictionary[String, int] = {}
var sell_price: Dictionary[String, int] = {}
var mid_price: Dictionary[String, int] = {}
var history: Dictionary[String, PackedInt64Array] = {}


func _init(p_city_id: String, p_day: int = 0) -> void:
	city_id = p_city_id
	day = p_day


## The ship carries the departure report, not later updates from its owner's kontor.
func copy_report() -> MarketRecord:
	var copy := MarketRecord.new(city_id, day)
	copy.population = population
	copy.satisfaction = satisfaction
	copy.stock = stock.duplicate()
	copy.shortage = shortage.duplicate()
	copy.buy_price = buy_price.duplicate()
	copy.sell_price = sell_price.duplicate()
	copy.mid_price = mid_price.duplicate()
	return copy


## Overwrite the latest report while retaining the house's own observation history.
func update_from(report: MarketRecord) -> void:
	day = report.day
	population = report.population
	satisfaction = report.satisfaction
	stock = report.stock.duplicate()
	shortage = report.shortage.duplicate()
	buy_price = report.buy_price.duplicate()
	sell_price = report.sell_price.duplicate()
	mid_price = report.mid_price.duplicate()


## A detached city view for price-walk calculations against remembered stock and population.
func as_city() -> CityState:
	var city := CityState.new(city_id, population)
	city.satisfaction = satisfaction
	city.stock = stock.duplicate()
	city.shortage = shortage.duplicate()
	return city
