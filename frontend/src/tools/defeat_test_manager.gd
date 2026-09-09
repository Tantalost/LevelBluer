extends "res://src/gameplay/level_manager.gd"
## Test-only persistence boundary: exercise the real loss flow without saving.
var test_awards := 0
var test_actions: Array[StringName] = []

func _award_loss_credits() -> void:
	test_awards += 1

func _on_defeat_action(action: StringName) -> void:
	test_actions.append(action)
