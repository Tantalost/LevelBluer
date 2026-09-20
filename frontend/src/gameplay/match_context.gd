class_name MatchContext
extends RefCounted
## Passed before _ready. Preview code has no account-write capability.
var preview := false
var stage_id := 1
var module_id := "mod_01"
var footprint := 3
var geometric := false
var account_bonuses := true
var persistent := true

static func stage_one_preview() -> MatchContext:
	var context := MatchContext.new()
	context.preview = true
	context.footprint = 1
	context.geometric = true
	context.account_bonuses = false
	context.persistent = false
	return context

static func stage_one_live() -> MatchContext:
	var context := MatchContext.new()
	context.footprint = 1
	context.geometric = true
	return context
