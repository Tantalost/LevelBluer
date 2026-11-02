extends "res://src/gameplay/decision/survey_phone.gd"
## Tap-to-match comparison inside the existing phone shell; no precision drag.
var _notice: bool = false
var _selected_detail: String = ""
var _feedback_text: String = ""

func _init() -> void:
	Chapter = preload("res://src/gameplay/decision/known_details_chapter.gd")

func configure_chapter(next_mode: String, snapshot: Dictionary) -> void:
	_notice = next_mode == "read" and snapshot.read.is_empty()
	_selected_detail = ""
	_feedback_text = ""
	super.configure_chapter(next_mode, snapshot)
	if _notice: AudioManager.play_sfx("ui_notification")

func _render() -> void:
	if not is_instance_valid(_content): return
	UI.clear(_content)
	if _notice:
		_activity_text("NEW VOICEMAIL\nAccount Security / Identity unverified\nReceived after the earlier call ended.")
		_action("READ VOICEMAIL TRANSCRIPT", _open_notice)
	elif mode == "read":
		_activity_text("NEW VOICEMAIL / TRANSCRIPT\n“"+Chapter.CALLER_EXCERPT+"”")
		_activity_text("These are newly received words, not a continuation of your earlier call notes.")
		if not phase_ready(): _action("KEEP VOICEMAIL", _read_message)
	elif mode == "sources":
		if phase_ready():
			_activity_success("ALL THREE DETAILS WERE PUBLIC\nKnowing the name, role and date does not verify the caller's identity.")
		else:
			_activity_text("Tap a caller detail, then its match in the public post.")
		var columns: HBoxContainer = HBoxContainer.new()
		columns.add_theme_constant_override("separation", 16)
		_content.add_child(columns)
		for side: String in ["caller","post"]:
			var column: VBoxContainer = UI.column(columns, 10)
			column.size_flags_horizontal = SIZE_EXPAND_FILL
			column.add_child(UI.label("CALLER SAID" if side == "caller" else "PUBLIC POST",24,INK))
			var order: PackedInt32Array = PackedInt32Array([0,1,2]) if side == "caller" else PackedInt32Array([2,0,1])
			for index: int in order:
				var detail: Dictionary = Chapter.DETAILS[index]
				var id: String = str(detail.id)
				var matched: bool = state.sorted.has(id)
				var chosen: bool = side == "caller" and _selected_detail == id
				var button: Button = _action(("✓ " if matched else "> " if chosen else "")+str(detail[side]), _select_detail.bind(id) if side == "caller" else _match_post.bind(id))
				button.reparent(column)
				button.set_meta("matched_detail",matched)
				if matched or chosen:
					button.add_theme_stylebox_override("normal",UI.box(Color("dcefe2") if matched else Color("c9eee9"),Color("33D17A") if matched else Color("4FE0D4"),12))
				if matched:
					button.add_theme_stylebox_override("disabled",UI.box(Color("dcefe2"),Color("33D17A"),12))
					button.add_theme_color_override("font_disabled_color",INK)
				button.accessibility_name = str(detail[side]) + (". Matched." if matched else ". Selected." if chosen else ". Tap to match.")
	elif mode == "permission":
		_activity_text("CALLER'S CLAIM\nYou're speaking with the right security team. Authorize us to access your wallet so we can protect the event funds.")
		if phase_ready():
			_activity_success("KNOWLEDGE IS NOT PERMISSION\nPublic details verify neither the caller's role nor their authority. Liza has not authorized account access.")
		else:
			_activity_text("What does the matching information establish?")
			_choices("THE CALLER IS AUTHORIZED",_wrong.bind("A public name, role and date can be read by many people. They do not verify a security role or authorize account access."),"THEY KNOW PUBLIC DETAILS",_confirm_permission)
	elif mode == "preserve":
		if phase_ready():
			_activity_success("COMPARISON SAVED\nThe details could be copied from a public source. The caller's identity and actual source remain unknown. No account permission was given.")
		elif state.sorted.has("limits"):
			_activity_success("SUPPORTED CONCLUSION\nThe post is a possible source. Its author is not identified as the caller.")
			_action("SAVE POST + VOICEMAIL",_save_comparison)
		else:
			_activity_text("Which conclusion belongs in Liza's evidence record?")
			_choices("THE POST'S AUTHOR MUST BE THE CALLER",_wrong.bind("A public source can be read by many people. This comparison does not identify who called or prove they copied this exact post."),"THE DETAILS COULD BE COPIED",_confirm_limits)
		_activity_text(Chapter.PUBLIC_POST)
		_activity_text("VOICEMAIL / Account Security (unverified)\n“"+Chapter.CALLER_EXCERPT+"”")
	if not _feedback_text.is_empty(): _activity_text(_feedback_text)
	_refresh()
	_metrics()

func _refresh() -> void:
	super._refresh()
	_title.text = "Phone / Public information"
	_status.text = "15:28  •  New voicemail"
	_status.visible = mode == "read"
	_nav.visible = phase_ready()
	_close.text = "CONTINUE →"
	_close.disabled = _locked or not phase_ready()
	for node: Node in _content.find_children("*","Button",true,false):
		if node.get_meta("matched_detail",false): (node as Button).disabled = true

func _open_notice() -> void:
	if _locked or mode != "read" or not _notice: return
	_notice = false
	_render()

func _read_message() -> void:
	if _locked or mode != "read" or _notice or phase_ready(): return
	_add("read","public")
	_render()

func _select_detail(id: String) -> void:
	if _locked or mode != "sources" or id not in ["name","role","date"] or state.sorted.has(id): return
	_selected_detail = id
	_feedback_text = ""
	_render()

func _match_post(id: String) -> void:
	if _locked or mode != "sources" or id not in ["name","role","date"] or state.sorted.has(id): return
	if _selected_detail.is_empty():
		show_feedback("Select a caller detail first, then its matching field. No mistake recorded.")
		return
	if id != _selected_detail:
		_wrong("Compare the selected detail with the post: a person's name, a role and an event date are different fields.")
		return
	_add("sorted",id)
	_selected_detail = ""
	_feedback_text = ""
	if state.sorted.has("name") and state.sorted.has("role") and state.sorted.has("date"): _add("flags","public")
	AudioManager.play_sfx("ui_confirm")
	_render()

func _confirm_permission() -> void:
	if _locked or mode != "permission" or phase_ready(): return
	_add("domains","public")
	_feedback_text = ""
	_render()

func _confirm_limits() -> void:
	if _locked or mode != "preserve" or phase_ready(): return
	_add("sorted","limits")
	_feedback_text = ""
	_render()

func _save_comparison() -> void:
	if _locked or mode != "preserve" or not state.sorted.has("limits") or phase_ready(): return
	_add("captures","public")
	AudioManager.play_sfx("ui_confirm")
	_render()

func _wrong(explanation: String) -> void:
	if _locked or phase_ready() or not Chapter.TASKS.has(mode): return
	state.mistakes = int(state.mistakes)+1
	evidence_changed.emit(state.duplicate(true))
	show_feedback(explanation)

func show_feedback(text: String) -> void:
	_feedback_text = text
	_render()
	var feedback: Control = _content.get_child(_content.get_child_count()-1) as Control
	var scroll: ScrollContainer = _content.get_parent() as ScrollContainer
	(func() -> void:
		if is_instance_valid(feedback) and is_instance_valid(scroll) and scroll.is_ancestor_of(feedback): scroll.ensure_control_visible(feedback)
	).call_deferred()

func phase_ready() -> bool:
	var field: String = {"read":"read","sources":"flags","permission":"domains","preserve":"captures"}.get(mode,"")
	return not field.is_empty() and (state.get(field,[]) as Array).has("public")

func _close_app() -> void:
	_finish_phase()
