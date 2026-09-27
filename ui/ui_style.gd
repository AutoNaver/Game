class_name UiStyle
extends RefCounted
## The game's look in one place: a dark slate and gold "Hanseatic ledger" theme, plus small layout
## helpers. Panels pick styles by theme type variation (e.g. "TitleLabel") instead of overriding
## colours and sizes one by one.

const INK: Color = Color("#efe6d2")
const INK_MUTED: Color = Color("#a99f8c")
const GOLD: Color = Color("#d4ae5a")
const WARNING: Color = Color("#f0b060")
const PANEL: Color = Color("#17212a")
const PANEL_RAISED: Color = Color("#202d38")
const BUTTON: Color = Color("#2c3c4a")
const BUTTON_HOVER: Color = Color("#3a5062")
const BUTTON_PRESSED: Color = Color("#7a6230")
const BUTTON_DISABLED: Color = Color("#1f2a33")
const BORDER: Color = Color("#3d4f5e")

## Theme type variations used by the panels.
const TITLE_LABEL: StringName = &"TitleLabel"
const HEADER_LABEL: StringName = &"HeaderLabel"
const MUTED_LABEL: StringName = &"MutedLabel"
const MESSAGE_LABEL: StringName = &"MessageLabel"
const HUD_PANEL: StringName = &"HudPanel"


## Builds the theme applied to the main scene's root.
static func make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 15
	theme.set_color("font_color", "Label", INK)

	_add_label_variation(theme, TITLE_LABEL, GOLD, 26)
	_add_label_variation(theme, HEADER_LABEL, GOLD, 19)
	_add_label_variation(theme, MUTED_LABEL, INK_MUTED, 14)
	_add_label_variation(theme, MESSAGE_LABEL, WARNING, 15)

	theme.set_stylebox("panel", "PanelContainer", _box(PANEL, BORDER, 0, [1, 0, 0, 0]))
	theme.set_type_variation(HUD_PANEL, "PanelContainer")
	theme.set_stylebox("panel", HUD_PANEL, _box(PANEL_RAISED, GOLD, 0, [0, 0, 0, 2]))

	theme.set_stylebox("normal", "Button", _box(BUTTON, BORDER, 4, [1, 1, 1, 1]))
	theme.set_stylebox("hover", "Button", _box(BUTTON_HOVER, GOLD, 4, [1, 1, 1, 1]))
	theme.set_stylebox("pressed", "Button", _box(BUTTON_PRESSED, GOLD, 4, [1, 1, 1, 1]))
	theme.set_stylebox("hover_pressed", "Button", _box(BUTTON_PRESSED, GOLD, 4, [1, 1, 1, 1]))
	theme.set_stylebox(
		"disabled", "Button", _box(BUTTON_DISABLED, BUTTON_DISABLED, 4, [1, 1, 1, 1])
	)
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_color("font_color", "Button", INK)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", Color.WHITE)
	theme.set_color("font_hover_pressed_color", "Button", Color.WHITE)
	theme.set_color("font_disabled_color", "Button", Color(INK_MUTED, 0.45))

	theme.set_stylebox("separator", "HSeparator", _line(BORDER))
	theme.set_constant("separation", "HSeparator", 12)
	return theme


## Wraps `parent`'s content area in a MarginContainer with equal padding and returns it.
static func add_padding(parent: Control, pixels: int) -> MarginContainer:
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, pixels)
	parent.add_child(margin)
	return margin


## A label using one of the theme's label variations.
static func label(text: String, variation: StringName = &"") -> Label:
	var result := Label.new()
	result.text = text
	result.theme_type_variation = variation
	return result


static func _add_label_variation(theme: Theme, name: StringName, color: Color, size: int) -> void:
	theme.set_type_variation(name, "Label")
	theme.set_color("font_color", name, color)
	theme.set_font_size("font_size", name, size)


## A flat box; `borders` are left, top, right, bottom widths.
static func _box(fill: Color, border: Color, radius: int, borders: Array[int]) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.border_width_left = borders[0]
	box.border_width_top = borders[1]
	box.border_width_right = borders[2]
	box.border_width_bottom = borders[3]
	box.set_corner_radius_all(radius)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	return box


static func _line(color: Color) -> StyleBoxLine:
	var line := StyleBoxLine.new()
	line.color = color
	line.thickness = 1
	return line
