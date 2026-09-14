extends BaseScreen
## Operator dossier: identity, useful next steps and earned service milestones.
const UI = preload("res://src/ui/screens/intel/study_ui.gd")
const Data = preload("res://src/ui/screens/progress/progress_data.gd")
const Briefing = preload("res://src/ui/screens/profile/profile_briefing.gd")
const Badge = preload("res://src/ui/screens/progress/rank_badge.gd")
var _body: HBoxContainer
var _identity: VBoxContainer
var _briefing: VBoxContainer
var _back: Button
var _title: Label
var _sync: Label
var _snapshot: Dictionary = {}
var _dossier: Dictionary = {}
var _details_open := false
var _details_button: Button
var _next_button: Button
var _details_content: VBoxContainer
var _actions: Array[Button] = []
var _font := 28
var _touch := 64.0
var _active := true
var _queued := false
var _server_busy := false
var _sync_copy := "CACHED PROFILE"

func _ready() -> void:
	var shell := UI.shell(self, "OPERATOR DOSSIER", func() -> void: Router.request_back())
	_back = shell.back
	_title = shell.title
	_sync = UI.label(_sync_copy, 24, UI.MUTED)
	_sync.autowrap_mode = TextServer.AUTOWRAP_OFF
	_title.get_parent().add_child(_sync)
	_body = HBoxContainer.new()
	_body.add_theme_constant_override("separation", 22)
	_body.size_flags_vertical = SIZE_EXPAND_FILL
	shell.layout.add_child(_body)
	_identity = UI.scroll_column(_body)
	_identity.get_parent().size_flags_stretch_ratio = 0.36
	_briefing = UI.scroll_column(_body)
	_briefing.get_parent().size_flags_stretch_ratio = 0.64
	_briefing.add_theme_constant_override("separation", 18)
	AuthService.progress_changed.connect(_request_refresh)
	AuthService.session_changed.connect(_session_changed)
	get_viewport().size_changed.connect(_request_refresh)
	_refresh()

func on_enter(_args: Dictionary) -> void:
	_active = true
	visible = true
	_details_open = false
	_refresh()
	_refresh_from_server()

func on_resume() -> void:
	_active = true
	visible = true
	_refresh()
	_refresh_from_server()

func on_exit() -> void:
	_active = false
	visible = false

func _session_changed(_signed_in: bool) -> void:
	_details_open = false
	_sync_copy = "CACHED PROFILE"
	_request_refresh()

func _request_refresh() -> void:
	if _queued or not _active:
		return
	_queued = true
	_refresh.call_deferred()

func _refresh_from_server() -> void:
	if _server_busy or not AuthService.is_signed_in() or AuthService.auth_token().is_empty():
		return
	_server_busy = true
	var account := AuthService.participant_code()
	var success := await AuthService.refresh_profile()
	_server_busy = false
	if not is_inside_tree() or not _active or account != AuthService.participant_code():
		return
	_sync_copy = "PROFILE REFRESHED" if success else "CACHED PROFILE"
	_request_refresh()

func _refresh() -> void:
	_queued = false
	if not _active or not is_inside_tree():
		return
	var ratio := maxf(0.1, get_viewport().get_final_transform().get_scale().y)
	_font = maxi(28, ceili(16 / ratio))
	_touch = maxf(64, ceilf(48 / ratio))
	_back.custom_minimum_size = Vector2(_font * 5.5, _touch)
	_back.autowrap_mode = TextServer.AUTOWRAP_OFF
	_back.add_theme_font_size_override("font_size", _font)
	_title.add_theme_font_size_override("font_size", maxi(20, ceili(12 / ratio)))
	_sync.text = _sync_copy
	var left_scroll := (_identity.get_parent() as ScrollContainer).scroll_vertical
	var right_scroll := (_briefing.get_parent() as ScrollContainer).scroll_vertical
	_snapshot = Data.snapshot()
	_dossier = Briefing.build(_snapshot)
	UI.clear(_identity)
	UI.clear(_briefing)
	_actions.clear()
	_build_identity()
	_build_briefing()
	(_identity.get_parent() as ScrollContainer).set_deferred("scroll_vertical", left_scroll)
	(_briefing.get_parent() as ScrollContainer).set_deferred("scroll_vertical", right_scroll)

func _label(text: String, color: Color = UI.TEXT, extra: int = 0) -> Label:
	return UI.label(text, _font + extra, color)

func _button(text: String, callback: Callable, primary: bool = false) -> Button:
	var button := UI.button(text, callback, primary)
	button.custom_minimum_size.y = _touch
	button.add_theme_font_size_override("font_size", _font)
	_actions.append(button)
	return button

func _panel(parent: Node, accent: Color = Color("3b626a"), fill: Color = UI.PANEL) -> VBoxContainer:
	var panel := UI.panel(parent, fill)
	panel.add_theme_stylebox_override("panel", UI.box(fill, accent, 20))
	return UI.column(panel, 14)

func _bar(parent: Node, value: float, total: float) -> void:
	var bar := ProgressBar.new()
	bar.max_value = maxf(1, total)
	bar.value = value
	bar.show_percentage = false
	bar.custom_minimum_size.y = 12
	bar.mouse_filter = MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background", UI.box(UI.BG, UI.BG, 0))
	bar.add_theme_stylebox_override("fill", UI.box(UI.TEAL, UI.TEAL, 0))
	parent.add_child(bar)

func _build_identity() -> void:
	var card := _panel(_identity, UI.TEAL, Color("182c32"))
	card.add_child(_label("LEVEL BLUE / PERSONNEL", UI.TEAL, -2))
	var portrait_row := HBoxContainer.new()
	portrait_row.add_theme_constant_override("separation", 18)
	card.add_child(portrait_row)
	var frame := UI.panel(portrait_row, UI.BG)
	frame.size_flags_horizontal = SIZE_EXPAND_FILL
	var avatar := TextureRect.new()
	avatar.name = "AvatarImage"
	avatar.custom_minimum_size = Vector2(96, 150)
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame.add_child(avatar)
	AssetManager.bind_texture(avatar, "ui_pfp")
	var badge := Badge.new()
	badge.rank_index = int(_snapshot.rank_index)
	portrait_row.add_child(badge)
	card.add_child(_label(AuthService.display_name().to_upper(), UI.TEXT, 10))
	card.add_child(_label(str(_snapshot.rank), UI.GOLD, 2))
	card.add_child(_label("SIGNED IN" if AuthService.is_signed_in() else "LOCAL PROFILE", UI.TEAL, -2))
	card.add_child(_label("%d RANK POINTS" % _snapshot.points, UI.TEXT, 2))
	_bar(card, _snapshot.rank_value, _snapshot.rank_span)
	card.add_child(_label("Maximum rank / Commander" if _snapshot.max_rank else "%d points to %s" % [maxi(0, int(_snapshot.next_points) - int(_snapshot.points)), AuthService.RANKS[mini(int(_snapshot.rank_index) + 1, AuthService.RANKS.size() - 1)]], UI.MUTED))
	_details_button = _button(("HIDE" if _details_open else "VIEW") + " PERSONAL RECORD", _toggle_details)
	_identity.add_child(_details_button)
	_details_content = _panel(_identity)
	_details_content.get_parent().visible = _details_open
	_details_content.add_child(_label("ACCOUNT RECORD", UI.GOLD))
	for field in [["Name", AuthService.full_name()], ["Section", AuthService.section()], ["Email", AuthService.email()], ["Reported status", AuthService.status_label()]]:
		_details_content.add_child(_label(str(field[0]).to_upper(), UI.MUTED, -2))
		_details_content.add_child(_label(str(field[1]) if not str(field[1]).is_empty() else "Not provided"))
	_details_content.add_child(_label("Sessions recorded / %d" % AuthService.sessions(), UI.MUTED))
	_details_content.add_child(_label("Threat points / %d" % maxi(0, AuthService.threat_points()), UI.MUTED))
	_details_content.add_child(_label("Reported system levels\nTower %d / Glade %d / Forge %d" % [AuthService.tower_level(), AuthService.glade_level(), AuthService.forge_level()], UI.MUTED))
	# A server's numeric zero alone does not establish that a test was taken.
	_details_content.add_child(_label("Reported pre-test / %d%%" % AuthService.pre_score() if AuthService.has_pre_test_completed() else "Pre-test / Not assessed", UI.MUTED))
	if AuthService.post_score() > 0:
		_details_content.add_child(_label("Reported post-test / %d%%" % AuthService.post_score(), UI.MUTED))
	else:
		_details_content.add_child(_label("Post-test / No confirmed result", UI.MUTED))
	_details_content.add_child(_label("Account records are separate from mastery estimates and stage completion.", UI.MUTED, -2))

func _toggle_details() -> void:
	_details_open = not _details_open
	_details_content.get_parent().visible = _details_open
	_details_button.text = ("HIDE" if _details_open else "VIEW") + " PERSONAL RECORD"
	if _details_open:
		_reveal_details.call_deferred()

func _reveal_details() -> void:
	# A resize/session refresh may replace the button before this deferred call runs.
	if _active and _details_open and is_instance_valid(_details_button):
		var scroll := _identity.get_parent() as ScrollContainer
		if scroll.is_ancestor_of(_details_button):
			scroll.scroll_vertical = roundi(_details_button.position.y)

func _build_briefing() -> void:
	var next: Dictionary = _dossier.next
	var assignment := _panel(_briefing, UI.GOLD, Color("25302f"))
	assignment.add_child(_label("YOUR NEXT ASSIGNMENT", UI.GOLD, -2))
	assignment.add_child(_label(str(next.title), UI.TEXT, 8))
	assignment.add_child(_label(str(next.body), UI.MUTED))
	_next_button = _button(str(next.action) + "  >", _navigate.bind(next.route), true)
	assignment.add_child(_next_button)
	var shortcuts := HBoxContainer.new()
	shortcuts.add_theme_constant_override("separation", 12)
	_briefing.add_child(shortcuts)
	_summary(shortcuts, "FIELD RECORD", "%d / %d STAGES" % [_snapshot.stage_done, _snapshot.stage_total], "%d / %d lesson topics" % [_snapshot.lesson_done, _snapshot.lesson_total], &"progress")
	_summary(shortcuts, "TOWER ARMORY", "%d CREDITS" % maxi(PlayerManager.credits, 0), "Inspect your tower upgrades", &"upgrades")
	var intel := _panel(_briefing)
	intel.add_child(_label("PERSONAL INTELLIGENCE", UI.TEAL))
	if _dossier.strongest.is_empty():
		intel.add_child(_label("Your knowledge profile starts with an assessment.", UI.TEXT))
		intel.add_child(_label("Complete a module pre-test to establish your baseline. Unassessed topics are not counted as zero.", UI.MUTED))
	else:
		var strongest: Dictionary = _dossier.strongest
		intel.add_child(_label("Highest estimate / %s  %d%%%s" % [strongest.name, roundi(float(strongest.value) * 100), " / Awaiting sync" if strongest.pending else ""]))
		var practice: Dictionary = _dossier.practice
		var prefix := "Practice focus" if float(practice.value) < PlayerManager.PROFICIENT_MASTERY else "Keep sharp"
		intel.add_child(_label("%s / %s  %d%%%s" % [prefix, practice.name, roundi(float(practice.value) * 100), " / Awaiting sync" if practice.pending else ""], UI.GOLD))
		intel.add_child(_label("BKT estimates knowledge from responses; it is not quiz accuracy or lesson completion.", UI.MUTED, -2))
	intel.add_child(_button("EXPLORE MASTERY & JOURNEY  >", _navigate.bind(&"progress")))
	_build_milestones()
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	_briefing.add_child(footer)
	for item in [["LESSONS", &"lessons"], ["CODEX", &"codex"], ["SETTINGS", &"settings"]]:
		var button := _button(item[0], _navigate.bind(item[1]))
		button.size_flags_horizontal = SIZE_EXPAND_FILL
		footer.add_child(button)

func _summary(parent: Node, title: String, value: String, caption: String, route: StringName) -> void:
	var button := _button("", _navigate.bind(route))
	button.size_flags_horizontal = SIZE_EXPAND_FILL
	button.custom_minimum_size.y = 156
	for state in ["normal", "hover", "pressed"]:
		button.add_theme_stylebox_override(state, UI.box(Color("203a40") if state == "hover" else UI.PANEL, UI.TEAL, 0))
	parent.add_child(button)
	var pad := MarginContainer.new()
	pad.mouse_filter = MOUSE_FILTER_IGNORE
	pad.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + edge, 16)
	button.add_child(pad)
	var text := UI.column(pad, 10)
	text.mouse_filter = MOUSE_FILTER_IGNORE
	text.add_child(_label(title, UI.TEAL, -2))
	text.add_child(_label(value, UI.TEXT, 4))
	text.add_child(_label(caption + "  >", UI.MUTED, -2))

func _build_milestones() -> void:
	var panel := _panel(_briefing)
	var earned := 0
	for milestone in _dossier.milestones:
		if milestone.earned:
			earned += 1
	panel.add_child(_label("SERVICE MILESTONES / %d OF 4" % earned, UI.GOLD))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	panel.add_child(grid)
	for milestone in _dossier.milestones:
		var entry := _panel(grid, UI.TEAL if milestone.earned else Color("43545b"), UI.BG)
		entry.get_parent().size_flags_horizontal = SIZE_EXPAND_FILL
		var icon := IntelPixelIcon.new()
		icon.kind = IntelPixelIcon.Kind.BADGE if milestone.earned else IntelPixelIcon.Kind.LOCK
		icon.ink_override = UI.TEAL if milestone.earned else UI.MUTED
		icon.custom_minimum_size = Vector2(38, 38)
		icon.size_flags_horizontal = SIZE_SHRINK_BEGIN
		entry.add_child(icon)
		entry.add_child(_label("EARNED" if milestone.earned else "IN PROGRESS", UI.TEAL if milestone.earned else UI.MUTED, -2))
		entry.add_child(_label(milestone.title))
		entry.add_child(_label(milestone.description, UI.MUTED, -2))
	panel.add_child(_label("Milestones celebrate recorded progress; they do not award extra credits.", UI.MUTED, -2))

func _navigate(route: StringName) -> void:
	Router.push(route)
