extends Node
func load_local() -> void:
	await get_tree().process_frame   # TODO: read language + audio prefs
