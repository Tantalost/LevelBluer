@tool
extends Node2D
## Paint Ground / FloorDetails / Scenery. Scenery cells store module anchors;
## the metadata on each scene reserves its full footprint.

@export var validate_placement: bool = false:
	get:
		return false
	set(value):
		if value and is_inside_tree():
			var issues := placement_issues()
			if issues.is_empty():
				print("Isometric map: all scenery footprints are supported and non-overlapping.")
			else:
				for issue in issues:
					push_warning(issue)


func _ready() -> void:
	if Engine.is_editor_hint():
		for layer_name in ["Ground", "Scenery"]:
			var layer := get_node_or_null(layer_name) as TileMapLayer
			if layer != null and not layer.changed.is_connected(_on_layer_changed):
				layer.changed.connect(_on_layer_changed)


func _on_layer_changed() -> void:
	update_configuration_warnings()


func _get_configuration_warnings() -> PackedStringArray:
	return placement_issues() if is_inside_tree() else PackedStringArray()


func _module_at(layer: TileMapLayer, cell: Vector2i) -> PackedScene:
	var source_id := layer.get_cell_source_id(cell)
	if source_id < 0:
		return null
	var source := layer.tile_set.get_source(source_id) as TileSetScenesCollectionSource
	if source == null:
		return null
	return source.get_scene_tile_scene(layer.get_cell_alternative_tile(cell))


func _footprint(packed: PackedScene) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in _scene_property(packed, &"occupied_cells", [Vector2i.ZERO]):
		result.append(Vector2i(cell))
	return result


func _scene_property(packed: PackedScene, property: StringName, fallback: Variant) -> Variant:
	# PackedScene resource metadata is not persisted by the .tscn format.
	# Read the saved root exports without instantiating a physics/render node.
	var state := packed.get_state()
	for index in state.get_node_property_count(0):
		if state.get_node_property_name(0, index) == property:
			return state.get_node_property_value(0, index)
	return fallback


func occupied_cells(blocking_only: bool = false, ignored_anchor: Variant = null) -> Dictionary:
	var result: Dictionary = {}
	var layer := get_node_or_null("Scenery") as TileMapLayer
	if layer == null:
		return result
	for anchor in layer.get_used_cells():
		if ignored_anchor != null and anchor == ignored_anchor:
			continue
		var packed := _module_at(layer, anchor)
		if packed == null or (blocking_only and not _scene_property(packed, &"blocks_movement", true)):
			continue
		for offset in _footprint(packed):
			result[anchor + offset] = anchor
	return result


func can_place_module(packed: PackedScene, anchor: Vector2i) -> bool:
	var ground := get_node_or_null("Ground") as TileMapLayer
	var scenery := get_node_or_null("Scenery") as TileMapLayer
	if ground == null or scenery == null or packed == null:
		return false
	# Native scene tiles occupy a single anchor; never overwrite another anchor.
	if scenery.get_cell_source_id(anchor) != -1:
		return false
	var occupied := occupied_cells()
	for offset in _footprint(packed):
		var cell: Vector2i = anchor + offset
		if ground.get_cell_source_id(cell) == -1 or occupied.has(cell):
			return false
	return true


func place_module(source_id: int, scene_id: int, anchor: Vector2i) -> bool:
	var scenery := get_node_or_null("Scenery") as TileMapLayer
	if scenery == null or not scenery.tile_set.has_source(source_id):
		return false
	var source := scenery.tile_set.get_source(source_id) as TileSetScenesCollectionSource
	if source == null or not source.has_scene_tile_id(scene_id):
		return false
	if not can_place_module(source.get_scene_tile_scene(scene_id), anchor):
		return false
	scenery.set_cell(anchor, source_id, Vector2i.ZERO, scene_id)
	return true


func is_buildable(cell: Vector2i) -> bool:
	var ground := get_node_or_null("Ground") as TileMapLayer
	if ground == null:
		return false
	var data := ground.get_cell_tile_data(cell)
	return data != null and data.get_custom_data("is_buildable") and not occupied_cells().has(cell)


func placement_issues() -> PackedStringArray:
	var issues := PackedStringArray()
	var ground := get_node_or_null("Ground") as TileMapLayer
	var scenery := get_node_or_null("Scenery") as TileMapLayer
	if ground == null or scenery == null:
		return issues
	var owners: Dictionary = {}
	for anchor in scenery.get_used_cells():
		var packed := _module_at(scenery, anchor)
		if packed == null:
			continue
		for offset in _footprint(packed):
			var cell: Vector2i = anchor + offset
			if ground.get_cell_source_id(cell) == -1:
				issues.append("Scenery at %s extends off Ground at %s." % [anchor, cell])
			if owners.has(cell):
				issues.append("Scenery anchors %s and %s overlap at %s." % [owners[cell], anchor, cell])
			owners[cell] = anchor
	return issues
