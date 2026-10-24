extends "res://src/gameplay/decision/survey_phone.gd"
## Only case-specific activities. Shell, chat clock, pause and styling are shared.
var _picked_header: String = ""
var _report_input: LineEdit
var _letter_feedback: Label
var _notice_text: String = ""
var _comparison_field: String = "domain"
var _lead_in: String = ""
var _lead_elapsed: float = 0.0
var _contact_button: Button
var _notification_card: PanelContainer

func _process(delta: float) -> void:
	super._process(delta)
	_tick_lead_in(delta)

func _tick_chat(delta: float) -> void:
	if not _lead_in.is_empty(): return
	super._tick_chat(delta)

func _tick_lead_in(delta: float) -> void:
	if _locked or not is_visible_in_tree() or _app != "mail" or _lead_in.is_empty(): return
	_lead_elapsed += delta
	if _lead_in == "notification" and is_instance_valid(_notification_card):
		_notification_card.modulate.a = 1.0 if _reduced_motion() else minf(1.0, _lead_elapsed / 0.3)
	elif _lead_in == "contacts" and is_instance_valid(_contact_button):
		var scroll: ScrollContainer = _content.get_parent() as ScrollContainer
		var target: float = _contact_button.position.y - 60.0
		var fraction: float = 1.0 if _reduced_motion() else smoothstep(0.0, 1.0, clampf((_lead_elapsed - 0.5) / 1.2, 0.0, 1.0))
		scroll.scroll_vertical = int(maxf(0.0, target) * fraction)
	elif _lead_in == "contact_tap" and _lead_elapsed >= 0.35:
		_lead_in = ""
		_begin_chat_turn()

func _open_notification() -> void:
	if _locked or _lead_in != "notification": return
	_lead_in = ""
	AudioManager.play_sfx("ui_click")
	_render()

func _select_jobert() -> void:
	if _locked or _lead_in != "contacts": return
	_lead_in = "contact_tap"
	_lead_elapsed = 0.0
	_contact_button.text = "✓ JOBERT / OPENING CHAT"
	_contact_button.add_theme_stylebox_override("normal", UI.box(Color("8FF0E6"), Color("4FE0D4"), 12))
	AudioManager.play_sfx("ui_click")
	_refresh()

func _build_chat() -> void:
	super._build_chat()
	if Chapter.STORY[int(state.beat)].get("chat_id", "") == "private" and _chat_stage == "done":
		_chat_status.text = "Private conversation · Jobert"

func _close_app() -> void:
	if not _lead_in.is_empty(): return
	super._close_app()

func configure_chapter(next_mode: String, snapshot: Dictionary) -> void:
	_notice_text = ""
	_picked_header = ""
	_lead_elapsed = 0.0
	_contact_button = null
	_notification_card = null
	var beat: Dictionary = Chapter.STORY[int(snapshot.beat)]
	_lead_in = "notification" if next_mode == "read" and beat.get("notification", false) and not snapshot.read.has("fake") else ""
	if next_mode == "chat" and beat.get("chat_id", "") == "private": _lead_in = "contacts"
	super.configure_chapter(next_mode, snapshot)
	if _lead_in == "notification": AudioManager.play_sfx("ui_notification")

class HeaderChip extends Button:
	var field: String = ""
	func _get_drag_data(_position: Vector2) -> Variant:
		if disabled: return null
		var preview: Label = Label.new()
		preview.text = field
		set_drag_preview(preview)
		return {"advisor_header":field}

class HeaderTarget extends Button:
	signal matched(field: String)
	func _can_drop_data(_position: Vector2, data: Variant) -> bool:
		return not disabled and data is Dictionary and data.get("advisor_header", "") in ["From","Reply-To","Subject"]
	func _drop_data(_position: Vector2, data: Variant) -> void:
		matched.emit(str(data.advisor_header))

func _init() -> void:
	Chapter = preload("res://src/gameplay/decision/advisor_chapter.gd")

func _render() -> void:
	if not is_instance_valid(_content): return
	if (mode == "chat" and _lead_in.is_empty()) or _app == "home":
		super._render()
		return
	UI.clear(_content)
	if is_instance_valid(_chat_footer):
		_chat_footer.get_parent().remove_child(_chat_footer)
		_chat_footer.queue_free()
	_chat_footer = null
	_chat_send = null
	_report_input = null
	_letter_feedback = null
	if _lead_in == "notification":
		_notification_card = UI.panel(_content, Color("e9efed"))
		var column: VBoxContainer = UI.column(_notification_card, 18)
		_ink("✉  MAIL · JUST NOW", column)
		_ink("You have an email", column)
		_ink("Sir Rham — Club Advisor", column)
		var open: Button = _action("TAP TO OPEN EMAIL", _open_notification)
		open.name = "OpenNotification"
		open.reparent(column)
		_notification_card.modulate.a = 1.0 if _reduced_motion() else 0.0
	elif _lead_in in ["contacts", "contact_tap"]:
		_ink("CONTACTS")
		_ink("Find Jobert and tap to message him.")
		for person: String in ["Dan", "Eric", "Jobert", "Sir Rham"]:
			if person == "Jobert":
				_contact_button = _action("J  /  JOBERT\nTap to message", _select_jobert)
				_contact_button.name = "ContactJobert"
				_contact_button.custom_minimum_size.y = 110
			else:
				var row: PanelContainer = UI.panel(_content, Color("e9efed"))
				row.custom_minimum_size.y = 110
				_ink(person.left(1) + "  /  " + person, row)
		var space: Control = Control.new()
		space.custom_minimum_size.y = 180
		_content.add_child(space)
	else:
		match mode:
			"read": _story_mail()
			"compare": _compare()
			"report": _report()
			"headers": _headers()
	if not _notice_text.is_empty() and mode != "report":
		var notice: Label = _ink(_notice_text)
		if mode == "compare": notice.add_theme_color_override("font_color", Color("365b63"))
		_content.move_child(notice, 0)
	_refresh()
	_metrics()
	(_content.get_parent() as ScrollContainer).set_deferred("scroll_vertical", 0)
	view_changed.emit()

func _ink(text: String, parent: Control = null) -> Label:
	var label: Label = UI.label(text, 26, INK)
	(parent if parent != null else _content).add_child(label)
	return label

func _story_mail() -> void:
	var beat: Dictionary = Chapter.STORY[int(state.beat)]
	var entry: Dictionary = Chapter.message(str(beat.get("email", "fake")))
	_ink(str(entry.subject))
	_action("FROM / " + str(entry.sender) + " · TAP TO INSPECT", func() -> void:
		if not _locked:
			selected = str(entry.id)
			_render())
	if selected == entry.id: _ink(str(entry.address))
	if beat.get("reply_preview", false): _ink("REPLY WOULD GO TO\n" + str(entry.reply))
	_ink(str(entry.body))
	_ink(str(entry.signature))
	if beat.get("draft", false):
		_ink("UNSENT DRAFT\nFull name: John…")
		_ink("No message has been sent.")
	_action("KEEP EMAIL / CONTINUE", func() -> void:
		if not _locked:
			_add("read", str(entry.id))
			phase_finished.emit())

func _compare() -> void:
	_content.size_flags_vertical = SIZE_FILL
	var instruction: Label = _ink("Compare each section. Mark a difference in the new email.")
	instruction.set_meta("compare_instruction", true)
	instruction.add_theme_color_override("font_color", INK)
	var rows: Array[Dictionary] = [
		{"id":"domain","name":"SENDER","real":Chapter.MESSAGES[0].address,"fake":Chapter.MESSAGES[1].address},
		{"id":"format","name":"SUBJECT FORMAT","real":"[CLUB UPDATE]","fake":"[CLUB UPDATE]"},
		{"id":"wording","name":"WORDING","real":Chapter.MESSAGES[0].body,"fake":Chapter.MESSAGES[1].body},
		{"id":"signature","name":"SIGNATURE","real":Chapter.MESSAGES[0].signature,"fake":Chapter.MESSAGES[1].signature}
	]
	var tabs: HBoxContainer = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	_content.add_child(tabs)
	for row: Dictionary in rows:
		var tab: Button = _action(("✓ " if state.flags.has(row.id) else "") + str(row.name), func() -> void:
			if not _locked:
				_comparison_field = str(row.id)
				_notice_text = ""
				_render())
		tab.name = "CompareTab_" + str(row.id)
		tab.set_meta("comparison_selected", row.id == _comparison_field)
		_comparison_button(tab, row.id == _comparison_field, state.flags.has(row.id))
		tab.accessibility_name = str(row.name) + (", selected" if row.id == _comparison_field else "") + (", collected" if state.flags.has(row.id) else "")
		tab.reparent(tabs)
		tab.size_flags_horizontal = SIZE_EXPAND_FILL
		tab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var chosen: Dictionary = rows[0]
	for row: Dictionary in rows:
		if row.id == _comparison_field: chosen = row
	var columns: HBoxContainer = HBoxContainer.new()
	columns.name = "ComparisonCards"
	columns.add_theme_constant_override("separation", 14)
	_content.add_child(columns)
	for side: String in ["real","fake"]:
		var panel: PanelContainer = UI.panel(columns, Color("e9efed") if side == "real" else Color("f4e8d7"))
		panel.name = "Comparison_" + side
		panel.add_theme_stylebox_override("panel", UI.box(Color("e9efed") if side == "real" else Color("f4e8d7"), Color("8aa9a3") if side == "real" else Color("b6a998"), 20))
		panel.size_flags_horizontal = SIZE_EXPAND_FILL
		var column: VBoxContainer = UI.column(panel, 12)
		var badge: Label = _ink("01 / CONFIRMED EMAIL" if side == "real" else "02 / NEW EMAIL", column)
		badge.add_theme_color_override("font_color", Color("153B37"))
		badge.set_meta("compare_pixels", 16)
		var section: Label = _ink(str(chosen.name), column)
		section.set_meta("compare_section", true)
		section.set_meta("compare_pixels", 14)
		section.add_theme_color_override("font_color", Color("365b63"))
		var value: Label = _ink(str(chosen[side]), column)
		value.name = "ComparisonValue"
		value.size_flags_vertical = SIZE_EXPAND_FILL
		value.set_meta("compare_pixels", 24 if chosen.id == "domain" else 20)
		value.set_meta("compare_value", true)
		value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		# Keep the two addresses equally readable; the clue must not depend on pixel-font glyphs.
		if chosen.id == "domain":
			value.add_theme_font_override("font", ThemeDB.fallback_font)
			value.texture_filter = TEXTURE_FILTER_LINEAR
		if side == "fake":
			var choice: Button = _action("✓ DIFFERENCE SAVED" if state.flags.has(chosen.id) else "MARK DIFFERENCE", _mark_difference.bind(str(chosen.id)))
			choice.name = "MarkDifference"
			choice.set_meta("compare_evidence", str(chosen.id))
			_comparison_button(choice, true, state.flags.has(chosen.id))
			choice.reparent(column)
			choice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			choice.disabled = state.flags.has(chosen.id) or _locked
		else:
			var note: Label = _ink("REFERENCE / Earlier message", column)
			note.set_meta("compare_pixels", 14)
			note.add_theme_color_override("font_color", Color("365b63"))
	if phase_ready():
		var next: Button = _action("SAVE COMPARISON / CONTINUE", _finish_phase)
		_comparison_button(next, true, false)

func _comparison_button(button: Button, active: bool, collected: bool) -> void:
	for style: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		var fill: Color = Color("dbe9e1") if collected else (PHONE_HEADER if active else Color("f0e5d6"))
		if style == "hover" or style == "pressed": fill = PHONE_HEADER
		var box: StyleBoxFlat = (button.get_theme_stylebox("normal").duplicate() as StyleBoxFlat)
		box.bg_color = fill
		box.border_color = Color("365b63") if style == "focus" else (PHONE_STATUS if active else Color("b6a998"))
		if style == "focus": box.set_border_width_all(2)
		button.add_theme_stylebox_override(style, box)
	for state_name: String in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color", "font_focus_color"]:
		button.add_theme_color_override(state_name, INK)

func _mark_difference(id: String) -> void:
	if _locked or mode != "compare" or state.flags.has(id): return
	if id not in ["domain","wording","signature"]:
		_miss("The subject format matches. Familiar formatting does not establish who sent it.")
		return
	_add("flags", id)
	if state.flags.size() == 3:
		_add("captures", "real")
		_add("captures", "fake")
	AudioManager.play_sfx("ui_confirm")
	_notice_text = "Evidence saved. Keep comparing the remaining sections."
	_render()

func _report() -> void:
	_content.size_flags_vertical = SIZE_FILL
	var heading: Label = _ink("Copy only the part after @. This report stays in the game.")
	heading.set_meta("report_pixels", 16)
	var columns: HBoxContainer = HBoxContainer.new()
	columns.name = "ReportColumns"
	columns.add_theme_constant_override("separation", 24)
	_content.add_child(columns)
	var reference: PanelContainer = UI.panel(columns, Color("e9efed"))
	reference.name = "ReportReference"
	reference.add_theme_stylebox_override("panel", UI.box(Color("e9efed"), Color("8aa9a3"), 20))
	reference.size_flags_horizontal = SIZE_EXPAND_FILL
	reference.size_flags_stretch_ratio = 0.9
	var details: VBoxContainer = UI.column(reference, 14)
	var sender_label: Label = _ink("EMAIL SENDER", details)
	sender_label.set_meta("report_pixels", 14)
	var sender: Label = _ink(str(Chapter.message("fake").address).replace("@", "\n@"), details)
	sender.set_meta("report_pixels", 21)
	sender.add_theme_font_override("font", ThemeDB.fallback_font)
	sender.texture_filter = TEXTURE_FILTER_LINEAR
	var known_label: Label = _ink("KNOWN SCHOOL DOMAIN", details)
	known_label.set_meta("report_pixels", 14)
	var known: Label = _ink("school.example", details)
	known.set_meta("report_pixels", 21)
	known.add_theme_font_override("font", ThemeDB.fallback_font)
	known.texture_filter = TEXTURE_FILTER_LINEAR
	var form: VBoxContainer = UI.column(columns, 14)
	form.name = "ReportForm"
	form.size_flags_horizontal = SIZE_EXPAND_FILL
	form.size_flags_stretch_ratio = 1.3
	var field_label: Label = _ink("SENDER DOMAIN", form)
	field_label.set_meta("report_pixels", 14)
	_report_input = LineEdit.new()
	_report_input.placeholder_text = "Type the domain after @"
	_report_input.accessibility_name = "Sender domain, only the part after the at sign"
	_report_input.text = str(state.report_draft)
	_report_input.max_length = 80
	_report_input.custom_minimum_size.y = 64
	_report_input.size_flags_horizontal = SIZE_EXPAND_FILL
	_report_input.expand_to_text_length = false
	_report_input.add_theme_font_size_override("font_size", 28)
	_report_input.add_theme_color_override("font_color", INK)
	_report_input.add_theme_color_override("font_placeholder_color", Color("607477"))
	_report_input.add_theme_stylebox_override("normal", UI.box(Color.WHITE, Color("8aa9a3"), 12))
	form.add_child(_report_input)
	_letter_feedback = _ink("", form)
	_letter_feedback.set_meta("report_pixels", 16)
	_letter_feedback.add_theme_font_override("font", ThemeDB.fallback_font)
	_letter_feedback.texture_filter = TEXTURE_FILTER_LINEAR
	_report_input.text_changed.connect(_draft_changed)
	_report_input.text_submitted.connect(func(_value: String) -> void: _submit_report())
	_draft_feedback()
	if not _notice_text.is_empty():
		var feedback: PanelContainer = UI.panel(form, Color("f0e5d6"))
		feedback.name = "ReportFeedback"
		var message: Label = _ink(_notice_text, feedback)
		message.set_meta("report_pixels", 16)
	var check_button: Button = _action("CHECK REPORT", _submit_report)
	check_button.name = "CheckReport"
	check_button.reparent(form)
	if phase_ready():
		check_button.hide()
		_letter_feedback.hide()
		var success_color: Color = Color("33D17A")
		var success_fill: Color = PHONE_PAPER.lerp(success_color, 0.16)
		var success_style: StyleBoxFlat = UI.box(success_fill, success_color, 12)
		_report_input.editable = false
		_report_input.add_theme_color_override("font_uneditable_color", INK)
		_report_input.add_theme_stylebox_override("normal", success_style)
		_report_input.add_theme_stylebox_override("read_only", success_style)
		var success_panel: PanelContainer = UI.panel(form, success_fill)
		success_panel.name = "ReportSuccess"
		success_panel.add_theme_stylebox_override("panel", UI.box(success_fill, success_color, 16))
		var success_details: VBoxContainer = UI.column(success_panel, 10)
		var success: Label = _ink("✓ CORRECT / DOMAIN SAVED", success_details)
		success.set_meta("report_pixels", 16)
		var difference: RichTextLabel = RichTextLabel.new()
		difference.name = "DomainDifference"
		difference.bbcode_enabled = true
		difference.fit_content = true
		difference.scroll_active = false
		difference.mouse_filter = Control.MOUSE_FILTER_IGNORE
		difference.add_theme_font_override("normal_font", ThemeDB.fallback_font)
		difference.add_theme_color_override("default_color", INK)
		difference.texture_filter = TEXTURE_FILTER_LINEAR
		difference.text = "Known: schoo[bgcolor=#33D17A][b]l[/b][/bgcolor].example\nCopied: schoo[bgcolor=#33D17A][b]1[/b][/bgcolor].example"
		success_details.add_child(difference)
		var explanation: Label = _ink("You spotted digit 1 replacing lowercase L at position 6. The copied address is still suspicious.", success_details)
		explanation.set_meta("report_pixels", 16)
		var next: Button = _action("CONTINUE TO HEADER", _finish_phase)
		next.reparent(form)

func _draft_changed(value: String) -> void:
	if _locked: return
	state.report_draft = value
	evidence_changed.emit(state.duplicate(true))
	_draft_feedback()

func _draft_feedback() -> void:
	if not is_instance_valid(_letter_feedback): return
	_letter_feedback.text = "Your transcription\n" + (" · ".join(str(state.report_draft).split("")) if not str(state.report_draft).is_empty() else "Characters appear here as you type.")

func _submit_report() -> void:
	if _locked or mode != "report" or phase_ready() or not is_instance_valid(_report_input): return
	if not Chapter.domain_matches(_report_input.text):
		_miss("Enter only the domain after @, not the full email address." if _report_input.text.contains("@") else "Copy the domain exactly, including the lookalike character.")
		return
	_add("domains", "fake")
	_notice_text = ""
	_render()

func _headers() -> void:
	_ink("RAW HEADER / MATCH THE FIELD NAMES")
	_ink("Drag a label onto a value, or tap a label then its matching value.")
	var chips: HBoxContainer = HBoxContainer.new()
	_content.add_child(chips)
	for field: String in ["Subject","Reply-To","From"]:
		var chip: HeaderChip = HeaderChip.new()
		chip.field = field
		chip.text = ("SELECTED / " if _picked_header == field else "") + field
		chip.custom_minimum_size.y = 64
		chip.size_flags_horizontal = SIZE_EXPAND_FILL
		chip.disabled = _locked or state.headers.has(field)
		_style_header_button(chip)
		chip.pressed.connect(func() -> void:
			if not _locked:
				_picked_header = field
				_render())
		chips.add_child(chip)
	var entry: Dictionary = Chapter.message("fake")
	for field: String in ["From","Reply-To","Subject"]:
		var target: HeaderTarget = HeaderTarget.new()
		target.name = "Header_" + field.replace("-", "_")
		var value: String = str(entry[{"From":"address","Reply-To":"reply","Subject":"subject"}[field]])
		target.text = (field if state.headers.has(field) else "[ DROP LABEL ]") + ":\n" + value
		target.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		target.custom_minimum_size.y = 80
		target.disabled = _locked or state.headers.has(field)
		_style_header_button(target)
		target.matched.connect(func(label: String) -> void: _match_header(label, field))
		target.pressed.connect(func() -> void: _match_header(_picked_header, field))
		_content.add_child(target)
	if phase_ready():
		_ink("The reply destination is different. Keep that mismatch with the original message; it is not a verdict about Dan.")
		_action("SAVE HEADER / CONTINUE", _finish_phase)

func _match_header(label: String, target: String) -> void:
	if _locked or mode != "headers" or state.headers.has(target): return
	if label.is_empty():
		thought_requested.emit("Pick a field label first, then tap its value.")
		return
	if label != target:
		_miss("From identifies the displayed sender address. Reply-To sets the reply destination. Subject is the message title.")
		return
	_add("headers", target)
	_picked_header = ""
	AudioManager.play_sfx("ui_confirm")
	_render()

func _miss(text: String) -> void:
	state.mistakes = int(state.mistakes) + 1
	evidence_changed.emit(state.duplicate(true))
	thought_requested.emit(text)
	AudioManager.play_sfx("ui_error")

func show_feedback(text: String) -> void:
	_notice_text = text
	_render()

func _refresh() -> void:
	super._refresh()
	if mode == "chat" and Chapter.STORY[int(state.get("beat", 0))].get("chat_id", "") == "private": _title.text = "Jobert / Private chat"
	if not _lead_in.is_empty():
		_title.text = "Contacts" if _lead_in in ["contacts", "contact_tap"] else "Notifications"
		_nav.hide()
		if is_instance_valid(_contact_button): _contact_button.disabled = _locked or _lead_in == "contact_tap"
	_status.visible = mode not in ["compare","report","headers"]
	if Chapter.STORY[int(state.get("beat", 0))].get("time", "") == "night": _status.text = "21:14  •  LTE  ▰"
	if mode in ["compare","report","headers"]: _nav.hide()
	if mode == "report":
		_title.text = "✉ Mail / Report to IT"
		_title.add_theme_color_override("font_color", INK)
	if mode == "compare":
		_title.text = "EMAIL COMPARISON"
		_title.add_theme_color_override("font_color", INK)
		_title.visible = get_viewport_rect().size.y * get_viewport().get_final_transform().get_scale().y >= 500
	for node: Node in _content.find_children("*", "Button", true, false):
		if node is HeaderChip: (node as Button).disabled = _locked or state.headers.has(node.field)
		if node.has_meta("compare_evidence"): (node as Button).disabled = _locked or state.flags.has(str(node.get_meta("compare_evidence")))

func _style_header_button(button: Button) -> void:
	button.add_theme_font_override("font", UI.FONT)
	for style: String in ["normal","hover","pressed","disabled"]:
		button.add_theme_stylebox_override(style, UI.box(Color("dbe9e1") if style == "disabled" else Color("f0e5d6"), Color("8aa9a3"), 12))
	for state_name: String in ["font_color","font_disabled_color","font_hover_color","font_pressed_color"]:
		button.add_theme_color_override(state_name, INK)

func _fit_shell() -> void:
	super._fit_shell()
	if not is_instance_valid(_shell): return
	if mode in ["compare","report","headers"] and _app == "mail":
		_shell.position = Vector2(8, 0)
		_shell.size = Vector2(maxf(100, size.x - 16), maxf(100, size.y - 8))
		_shell.queue_redraw()
	var frame: StyleBoxEmpty = _shell.get_theme_stylebox("panel") as StyleBoxEmpty
	frame.content_margin_top = 38
	frame.content_margin_bottom = 30
	(_title.get_parent() as VBoxContainer).add_theme_constant_override("separation", 8)
	if mode == "report" and _app == "mail":
		var physical: float = maxf(0.25, get_viewport().get_final_transform().get_scale().y)
		var padding: float = (44.0 if get_viewport_rect().size.y * physical >= 500 else 28.0) / physical
		for edge: String in ["left", "right", "top", "bottom"]: frame.set("content_margin_" + edge, padding)
		(_title.get_parent() as VBoxContainer).add_theme_constant_override("separation", ceili(20 / physical))
		var width: float = minf(size.x - 16, 1040 / physical)
		_shell.position.x = (size.x - width) * 0.5
		_shell.size = Vector2(width, minf(size.y - 8, _content.get_combined_minimum_size().y + _title.get_combined_minimum_size().y + 20 / physical + padding * 2))
		(_content.get_parent() as ScrollContainer).vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	if mode == "compare" and _app == "mail":
		var physical: float = maxf(0.25, get_viewport().get_final_transform().get_scale().y)
		var padding: float = 44.0 if _title.visible else 24.0
		for edge: String in ["left", "right", "top", "bottom"]: frame.set("content_margin_" + edge, padding / physical)
		var heading_height: float = _title.get_combined_minimum_size().y + 8 if _title.visible else 0.0
		_shell.size.y = minf(size.y - 8, _content.get_combined_minimum_size().y + heading_height + padding * 2 / physical)
		(_content.get_parent() as ScrollContainer).vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO

func _draw_frame() -> void:
	if mode not in ["compare", "report", "reveal", "expand", "flaws", "timeline", "board", "case_note"] or _app != "mail":
		super._draw_frame()
		return
	var rect: Rect2 = Rect2(Vector2.ZERO, _shell.size)
	for layer: int in 6:
		_shell.draw_colored_polygon(_bezel(rect.grow(-layer * 4), 32 - layer * 3), PHONE_FRAME_COLORS[layer])
	var paper: Rect2 = rect.grow(-24)
	_wallpaper_clip = _bezel(paper, 14)
	_wallpaper_rect(paper, PHONE_PAPER)
	if _title.visible:
		var header_end: float = _title.global_position.y - _shell.global_position.y + _title.size.y + 4
		_wallpaper_rect(Rect2(paper.position, Vector2(paper.size.x, maxf(0, header_end - paper.position.y))), PHONE_HEADER)

func _metrics() -> void:
	super._metrics()
	var physical: float = maxf(0.25, get_viewport().get_final_transform().get_scale().y)
	if mode == "compare":
		_title.visible = get_viewport_rect().size.y * physical >= 500
		for node: Node in _content.find_children("*", "Button", true, false):
			(node as Button).custom_minimum_size.y = 48 / physical
	if mode in ["compare","report","headers"]:
		for node: Node in _content.find_children("*", "Label", true, false):
			(node as Label).add_theme_font_size_override("font_size", ceili(float(node.get_meta("report_pixels", node.get_meta("compare_pixels", 18))) / physical))
			var compact: bool = get_viewport_rect().size.y * physical < 500
			if node.has_meta("compare_value"): (node as Label).custom_minimum_size.y = (32.0 if compact else 90.0) / physical
			if node.has_meta("compare_section") or node.has_meta("compare_instruction"): (node as Label).visible = not compact
	if is_instance_valid(_report_input): _report_input.add_theme_font_size_override("font_size", ceili(20 / physical))
	if mode == "report":
		if is_instance_valid(_report_input): _report_input.custom_minimum_size.y = 52 / physical
		for node: Node in _content.find_children("*", "RichTextLabel", true, false):
			(node as RichTextLabel).add_theme_font_size_override("normal_font_size", ceili(20 / physical))
			(node as RichTextLabel).add_theme_font_size_override("bold_font_size", ceili(20 / physical))
		for node: Node in _content.find_children("*", "Button", true, false):
			(node as Button).custom_minimum_size.y = 48 / physical
		for node: Node in _content.find_children("*", "BoxContainer", true, false):
			(node as BoxContainer).add_theme_constant_override("separation", ceili((24.0 if node.name == "ReportColumns" else 14.0) / physical))

func phase_ready() -> bool:
	if not _lead_in.is_empty(): return false
	match mode:
		"chat": return super.phase_ready()
		"read": return state.read.has(str(Chapter.STORY[int(state.beat)].get("email", "fake")))
		"compare": return state.flags.size() == 3
		"report": return state.domains.has("fake")
		"headers": return state.headers.size() == 3
	return false

func set_locked(value: bool) -> void:
	super.set_locked(value)
	if is_instance_valid(_report_input): _report_input.editable = not value and not phase_ready()
