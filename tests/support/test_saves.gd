extends RefCounted
## Keeps UI tests away from the player's real saves: points a session at a test folder and
## empties that folder afterwards.

const DIR: String = "user://test_saves/ui"


static func use(session: GameSession) -> void:
	session.save_dir = DIR
	clear()


static func clear() -> void:
	if not DirAccess.dir_exists_absolute(DIR):
		return
	for file_name in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR.path_join(file_name))
