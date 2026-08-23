extends Node
## Autoload singleton, registered as "SaveService".
## Per-account snapshots on this device. Cloud sync is out of scope.

func load_local() -> void:
	load_game()
	await get_tree().process_frame


func flush() -> void:
	save_game()
	await get_tree().process_frame


func save_game() -> void:
	var data: Dictionary = PlayerManager.get_save_data()
	var json_string: String = JSON.stringify(data)
	var path: String = _resolve_save_path()
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("[SaveService] Failed to open save file for writing: " + path)
		return
	file.store_string(json_string)
	file.close()
	print("[SaveService] Game saved successfully. path=", path)


func load_game() -> void:
	var path: String = _resolve_save_path()
	if not FileAccess.file_exists(path):
		print("[SaveService] No save file found. Starting fresh. path=", path)
		return
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("[SaveService] Failed to open save file for reading: " + path)
		return
	var json_string: String = file.get_as_text()
	file.close()
	var json: JSON = JSON.new()
	var error: Error = json.parse(json_string)
	if error != OK:
		push_error("[SaveService] JSON Parse Error in save file: " + path)
		return
	var data: Variant = json.data
	if typeof(data) != TYPE_DICTIONARY:
		push_error("[SaveService] Save root is not a Dictionary: " + path)
		return
	PlayerManager.apply_save_data(data as Dictionary)
	print("[SaveService] Save loaded successfully. path=", path)


func _resolve_save_path() -> String:
	var user_id: String = "guest"
	if AuthService.is_signed_in():
		var raw_id: String = AuthService.participant_code().strip_edges()
		var safe_id: String = raw_id.validate_filename()
		if not safe_id.is_empty():
			user_id = safe_id
	return "user://player_save_" + user_id + ".json"
