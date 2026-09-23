class_name DialogueScreenShake
extends RefCounted
## One generic, reusable screen-shake helper for decision-story dialogue
## scenes (see DialogueEmotion.shake_profile). This only ever shakes the
## Control passed in by the caller — the dialogue panel itself — never a
## Tower Defense camera or any other gameplay node.
##
## Safe to call once per dialogue line: any shake already running on `node`
## is cancelled and its position restored before the new one (if any) starts,
## so offsets can never accumulate across lines.
const Emotion = preload("res://src/gameplay/decision/dialogue_emotion.gd")

static func apply(node: Control, emotion: String) -> void:
	cancel(node)
	var settings: Node = Engine.get_main_loop().root.get_node_or_null("SettingsService")
	if settings != null and bool(settings.reduced_motion):
		return
	var profile: Dictionary = Emotion.shake_profile(emotion)
	if profile.is_empty():
		return
	var intensity: float = float(profile.get("intensity", 0.0))
	var duration: float = float(profile.get("duration", 0.0))
	if intensity <= 0.0 or duration <= 0.0:
		return
	var base: Vector2 = node.position
	node.set_meta("_shake_base_position", base)
	var tween: Tween = node.create_tween()
	node.set_meta("_shake_tween", tween)
	var steps: int = 5
	for i in steps:
		var offset := Vector2(
			(randf() * 2.0 - 1.0) * intensity,
			(randf() * 2.0 - 1.0) * intensity * 0.4
		)
		tween.tween_property(node, "position", base + offset, duration / steps)
	tween.tween_property(node, "position", base, duration / steps)


## Kills any in-flight shake tween on `node` and snaps its position back to
## the pre-shake base, so a new line (of any emotion, including neutral)
## always begins from a clean, unshaken state.
static func cancel(node: Control) -> void:
	if node.has_meta("_shake_tween"):
		var previous: Variant = node.get_meta("_shake_tween")
		if previous is Tween and (previous as Tween).is_valid():
			(previous as Tween).kill()
		node.remove_meta("_shake_tween")
	if node.has_meta("_shake_base_position"):
		var base: Variant = node.get_meta("_shake_base_position")
		if base is Vector2:
			node.position = base
		node.remove_meta("_shake_base_position")
