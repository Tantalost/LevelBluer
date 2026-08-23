extends Node
## Autoload singleton, registered as "ContentDB".
## Loads authored stage and question JSON at boot. FastAPI swap comes later.

var questions: Dictionary = {}
var stages: Dictionary = {}


func _ready() -> void:
	_load_json_data("res://data/questions.json", questions)
	_load_json_data("res://data/stages.json", stages)
	print("[ContentDB] Parsed skills=", questions.size(), " stages=", stages.size())


func load_all() -> void:
	if questions.is_empty():
		_load_json_data("res://data/questions.json", questions)
	if stages.is_empty():
		_load_json_data("res://data/stages.json", stages)
	await get_tree().process_frame


func get_questions() -> Dictionary:
	return questions.duplicate(true)


func get_stage(stage_id: String) -> Dictionary:
	if stage_id.is_empty() or not stages.has(stage_id):
		return {}
	var stored: Variant = stages[stage_id]
	if typeof(stored) != TYPE_DICTIONARY:
		return {}
	var config: Dictionary = stored as Dictionary
	if config.is_empty():
		return {}
	return config.duplicate(true)


func _load_json_data(file_path: String, target_dict: Dictionary) -> void:
	if not FileAccess.file_exists(file_path):
		push_error("ContentDB: Missing file " + file_path)
		return
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("ContentDB: Failed to open " + file_path)
		return
	var json_string: String = file.get_as_text()
	file.close()
	var json: JSON = JSON.new()
	var error: Error = json.parse(json_string)
	if error != OK:
		push_error("ContentDB: JSON Parse Error in " + file_path)
		return
	var data: Variant = json.data
	if typeof(data) != TYPE_DICTIONARY:
		push_error("ContentDB: Root is not a Dictionary in " + file_path)
		return
	target_dict.merge(data as Dictionary, true)
