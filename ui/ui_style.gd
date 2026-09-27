class_name UiStyle
extends RefCounted
## Small shared layout helpers so panels look consistent.


## Wraps `parent`'s content area in a MarginContainer with equal padding and returns it.
static func add_padding(parent: Control, pixels: int) -> MarginContainer:
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, pixels)
	parent.add_child(margin)
	return margin
