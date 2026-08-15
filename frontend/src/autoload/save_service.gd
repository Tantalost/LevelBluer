extends Node
func load_local() -> void:
	await get_tree().process_frame   # TODO: read profile + attempt log
func flush() -> void:
	await get_tree().process_frame   # TODO: write pending rows to disk
