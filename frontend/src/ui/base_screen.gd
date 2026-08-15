class_name BaseScreen
extends Control
## Every screen in Level Blue extends this. The router calls these hooks; you
## override the ones you need and ignore the rest.
##
## The point of a shared lifecycle is that "refresh the currency pills when the
## player comes back from the Store" becomes on_resume() in one place, instead
## of nine screens each inventing their own way to notice they're visible again.

var screen_id: StringName = &""


## Called once, immediately after the screen is added to the tree.
## `args` carries navigation parameters, e.g. {"module_index": 2}.
func on_enter(_args: Dictionary) -> void:
	pass


## Called when a screen stacked on top of this one is popped and this screen
## becomes visible again. Refresh anything that may have changed while away —
## currency totals, module progress, mastery bars.
func on_resume() -> void:
	pass


## Called before this screen is hidden or freed. Stop timers, cancel any
## in-flight HTTP requests, and unsubscribe from EventBus signals here.
func on_exit() -> void:
	pass


## Return false to block both the header back arrow and the Android back
## gesture. The forced password-change screen returns false until the new
## password is accepted; a screen with unsaved input can return false and
## show a confirmation instead.
func can_go_back() -> bool:
	return true
