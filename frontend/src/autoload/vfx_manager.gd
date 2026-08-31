extends Node
## Autoload singleton, registered as "VfxManager".
## Spawns one-shot CPUParticles2D bursts and frees them on `finished`.

var _prefabs: Dictionary = {}


func _ready() -> void:
	_prefabs["impact"] = preload("res://src/gameplay/vfx/impact_spark.tscn")
	_prefabs["aoe"] = preload("res://src/gameplay/vfx/aoe_burst.tscn")
	_prefabs["death"] = preload("res://src/gameplay/vfx/data_deletion.tscn")


func spawn_vfx(effect_id: String, pos: Vector2) -> void:
	if not _prefabs.has(effect_id):
		push_warning("[VfxManager] Unknown effect: " + effect_id)
		return
	var packed: PackedScene = _prefabs[effect_id] as PackedScene
	if packed == null:
		push_warning("[VfxManager] Prefab is not a PackedScene: " + effect_id)
		return
	var emitter: CPUParticles2D = packed.instantiate() as CPUParticles2D
	if emitter == null:
		push_warning("[VfxManager] Prefab is not CPUParticles2D: " + effect_id)
		return
	var host: Node = _resolve_host()
	host.add_child(emitter)
	emitter.global_position = pos
	if not emitter.finished.is_connected(emitter.queue_free):
		emitter.finished.connect(emitter.queue_free)
	emitter.emitting = true
	if effect_id == "aoe" or effect_id == "death":
		AudioManager.play_sfx("explosion")


func _resolve_host() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return self
	var level: Node = tree.get_first_node_in_group("level_root")
	if level != null:
		return level
	var current: Node = tree.current_scene
	if current != null:
		return current
	return self
