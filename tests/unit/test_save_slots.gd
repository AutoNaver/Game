extends GutTest
## Save slot names and listing (SaveGame).

const DIR: String = "user://test_saves/slots"


func after_each() -> void:
	if not DirAccess.dir_exists_absolute(DIR):
		return
	for file_name in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR.path_join(file_name))


func test_slot_names_must_be_safe_file_names() -> void:
	for good_name: String in ["Harbour 1", "day_12", "Lübeck-run"]:
		assert_eq(SaveGame.check_slot_name(good_name), "", good_name)
	var bad_names: Dictionary[String, String] = {
		"": "Enter a name for the save",
		"   ": "Enter a name for the save",
		"a/b": "Save names can only use letters, digits, spaces, - and _",
		"..": "Save names can only use letters, digits, spaces, - and _",
		" padded": "Save names can't start or end with a space",
		"x".repeat(SaveGame.MAX_SLOT_NAME + 1): "Save names can be at most 32 characters",
	}
	for bad_name: String in bad_names:
		assert_eq(SaveGame.check_slot_name(bad_name), bad_names[bad_name], "'%s'" % bad_name)


func test_slots_are_listed_by_name() -> void:
	var sim := Simulation.new_game(GameDataLoader.new().load_dir(GameDataLoader.DEFAULT_DIR), 1)
	for slot: String in ["b", "a"]:
		assert_eq(SaveGame.save_file(sim.world, SaveGame.path_for(slot, DIR)), "")
	var other := FileAccess.open(DIR.path_join("notes.txt"), FileAccess.WRITE)
	other.store_string("not a save")
	other.close()
	assert_eq(Array(SaveGame.list_slots(DIR)), ["a", "b"])
	assert_eq(Array(SaveGame.list_slots("user://test_saves/missing")), [])
