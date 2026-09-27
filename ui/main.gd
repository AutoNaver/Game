extends Control
## Placeholder entry scene. Loads the game data and shows a summary, so broken data is visible
## right away on launch. The map UI replaces this in M3.

@onready var _status_label: Label = %StatusLabel


func _ready() -> void:
	var loader := GameDataLoader.new()
	var data := loader.load_dir(GameDataLoader.DEFAULT_DIR)
	if data == null:
		for message in loader.errors:
			push_error(message)
		_status_label.text = "Game data failed to load:\n%s" % "\n".join(loader.errors)
		return
	var summary := "Loaded %d goods and %d cities."
	_status_label.text = summary % [data.goods.size(), data.cities.size()]
