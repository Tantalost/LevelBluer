extends Node
func load_all() -> void:
	await get_tree().process_frame   # TODO: load skills, questions, levels
