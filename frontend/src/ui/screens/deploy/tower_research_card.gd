extends Button
## Native controls keep the reusable dossier readable and keyboard/touch accessible.
const UI = preload("res://src/ui/screens/intel/study_ui.gd")
const Portrait = preload("res://src/ui/screens/deploy/research_portrait.gd")
var tower_id := "base"
var unlocked := true
var accent := UI.TEAL
var heading := "BASIC NODE"
var role := "DPS"
var cost := 2
var damage := 1
var rate := 0.55
var slots := 2
var ranks := 0
var total_ranks := 9
var requirement := ""
var body_font := 28

func _ready() -> void:
	mouse_default_cursor_shape = CURSOR_POINTING_HAND
	refresh()

func refresh() -> void:
	UI.clear(self)
	for state in ["normal", "hover", "pressed", "focus"]:
		add_theme_stylebox_override(state, UI.box(Color("203a40") if state == "hover" else UI.PANEL, UI.GOLD if state == "focus" else accent, 0))
	var pad := MarginContainer.new()
	pad.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + edge, 20)
	pad.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(pad)
	var content := UI.column(pad, 12)
	content.mouse_filter = MOUSE_FILTER_IGNORE
	var status := UI.label("%s / %s" % [role, "ONLINE" if unlocked else "LOCKED"], body_font, accent if unlocked else UI.MUTED)
	content.add_child(status)
	var portrait := Portrait.new()
	portrait.tower_id = tower_id
	portrait.accent = accent if unlocked else UI.MUTED
	portrait.custom_minimum_size.y = 160
	portrait.size_flags_vertical = SIZE_EXPAND_FILL
	content.add_child(portrait)
	content.add_child(UI.label(heading, body_font + 8))
	var stats := "DMG %d  /  RATE %.2f/s\nDEPLOY %dG  /  SLOTS %d" % [damage, rate, cost, slots]
	if tower_id == "sandbox":
		stats = "SLOW %d%%\nDEPLOY %dG  /  SLOTS %d" % [roundi((1 - float(ContentDB.get_tower(tower_id).get("zone_slow", 1))) * 100), cost, slots]
	content.add_child(UI.label(stats, body_font, UI.MUTED))
	content.add_child(UI.label("%d / %d UPGRADES" % [ranks, total_ranks] if total_ranks > 0 else "UPGRADES COMING SOON", body_font - 2, accent))
	content.add_child(UI.label("OPEN RESEARCH >" if unlocked else requirement, body_font, UI.TEAL if unlocked else UI.GOLD))
