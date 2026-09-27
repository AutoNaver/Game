class_name EventText
extends RefCounted
## Words for world events and goods losses, shared by the notification log, the city panel and the
## price tooltip.


## "Storm near Visby", "Harvest failure in Danzig", ...
static func headline(data: GameData, event: EventState) -> String:
	var event_type := data.get_event(event.type_id)
	var city := data.get_city(event.city_id).name
	var place := "near" if event_type.kind == EventDef.STORM else "in"
	return "%s %s %s" % [event_type.name, place, city]


## What the event does: "ships to and from Visby sail at 1/2 speed".
static func effect(data: GameData, event: EventState) -> String:
	var event_type := data.get_event(event.type_id)
	match event_type.kind:
		EventDef.STORM:
			return (
				"ships to and from %s sail at 1/%d speed"
				% [_city(data, event), event_type.slowdown]
			)
		EventDef.HARVEST_FAILURE:
			var goods: PackedStringArray = []
			for good_id in event_type.goods:
				goods.append(data.get_good(good_id).name.to_lower())
			var percent := roundi(event_type.factor * 100.0)
			return "local %s output down to %d%%" % [", ".join(goods), percent]
		EventDef.WAR:
			return "overland imports down to %d%%" % roundi(event_type.factor * 100.0)
		EventDef.FIRE:
			return "%d%% of the goods in kontors burned" % roundi(event_type.loss_share * 100.0)
	return ""


## "3 more days" or "last day", counted from `day`.
static func time_left(event: EventState, day: int) -> String:
	var left := event.end_day - day
	return "last day" if left <= 1 else "%d more days" % left


## Whether the event moves `good_id`'s price in its city (the price tooltip lists these).
static func affects_price(data: GameData, event: EventState, good_id: String) -> bool:
	var event_type := data.get_event(event.type_id)
	match event_type.kind:
		EventDef.HARVEST_FAILURE:
			return event_type.goods.has(good_id)
		EventDef.WAR:
			return true
	return false


## "12 Grain, 5 Beer" for a list of losses.
static func goods_list(data: GameData, losses: Array[GoodsLoss]) -> String:
	var parts: PackedStringArray = []
	for loss in losses:
		parts.append("%d %s" % [loss.units, data.get_good(loss.good_id).name])
	return ", ".join(parts)


static func _city(data: GameData, event: EventState) -> String:
	return data.get_city(event.city_id).name
