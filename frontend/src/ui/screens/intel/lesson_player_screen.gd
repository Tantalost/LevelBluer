class_name LessonPlayerScreen
extends BaseScreen
## One activity per lesson. Same two-pane intel window.

const FONT_PATH := "res://assets/fonts/PressStart2P-Regular.ttf"

@onready var _file_pane: PanelContainer = %FilePane
@onready var _report_pane: PanelContainer = %ReportPane
@onready var _topic_toggle: Button = %TopicToggle
@onready var _case_toggle: Button = %CaseToggle
@onready var _case_label: Label = %CaseLabel
@onready var _date_label: Label = %DateLabel
@onready var _time_label: Label = %TimeLabel
@onready var _photo_well: PanelContainer = %PhotoWell
@onready var _evidence_glyph: IntelPixelIcon = %EvidenceGlyph
@onready var _body_label: Label = %BodyLabel
@onready var _footer_label: Label = %FooterLabel
@onready var _report_title: Label = %ReportTitle
@onready var _close_button: Button = %CloseButton
@onready var _choice_list: VBoxContainer = %ChoiceList
@onready var _flag_a: Button = %FlagA
@onready var _flag_b: Button = %FlagB
@onready var _status_label: Label = %StatusLabel
@onready var _submit_button: Button = %SubmitButton
@onready var _progress_label: Label = %ProgressLabel
@onready var _prev_file: Button = %PrevFile
@onready var _next_file: Button = %NextFile

var _pixel_font: Font
var _module_id: String = ""
var _lesson_index: int = 0
var _lessons: Array[Dictionary] = []
var _activity: String = "guided"
var _step: int = 0
var _busy: bool = false
var _review_mode: bool = false
var _resolved: bool = false
var _briefed: bool = false
var _hint_open: bool = false
var _marks: Dictionary = {}
var _picks: Dictionary = {}
var _order: Array[int] = []
var _shuffle: Array[int] = []
var _branch_id: String = "start"
var _log: PackedStringArray = []
var _time_left: float = 0.0
var _timer_on: bool = false


func _ready() -> void:
	_load_font()
	set_process(false)
	_style_file_pane()
	_style_report_pane()
	_style_photo_well()
	_style_close_button()
	_style_submit()
	_apply_label(_case_label, Palette.FIELD_TEXT, 11)
	_apply_label(_date_label, Palette.FIELD_TEXT, 10)
	_apply_label(_time_label, Palette.FIELD_TEXT, 10)
	_apply_label(_body_label, Palette.FIELD_TEXT, 11)
	_apply_label(_footer_label, Palette.TEXT_MUTED, 10)
	_apply_label(_report_title, Palette.TEXT_PRIMARY, 13)
	_apply_label(_progress_label, Palette.TEXT_PRIMARY, 11)
	_apply_label(_status_label, Palette.TEXT_PRIMARY, 11)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_close_button.pressed.connect(func() -> void: Router.request_back())
	_submit_button.pressed.connect(_on_continue)
	_prev_file.pressed.connect(func() -> void: _browse_lesson(-1))
	_next_file.pressed.connect(func() -> void: _browse_lesson(1))
	_style_nav_file(_prev_file)
	_style_nav_file(_next_file)
	_topic_toggle.visible = false
	_case_toggle.visible = false
	_flag_a.visible = false
	_flag_b.visible = false
	_date_label.visible = false
	_time_label.visible = false


func _exit_tree() -> void:
	_timer_on = false
	set_process(false)


func _process(delta: float) -> void:
	if not _timer_on or _resolved:
		return
	_time_left -= delta
	if _time_left <= 0.0:
		_time_left = 0.0
		_timer_on = false
		set_process(false)
		_finish_triage()
		return
	_progress_label.text = "L%02d/%02d  %ds" % [_lesson_index + 1, _lessons.size(), int(ceil(_time_left))]


func on_enter(args: Dictionary) -> void:
	_module_id = str(args.get("module_id", ""))
	_review_mode = bool(args.get("review", false))
	_lessons = LessonCatalog.lessons_for(_module_id)
	if _lessons.is_empty():
		Router.request_back()
		return
	if _review_mode:
		_lesson_index = 0
	else:
		_lesson_index = clampi(PlayerManager.get_lesson_progress(_module_id), 0, _lessons.size() - 1)
	_start_lesson()


func _start_lesson() -> void:
	_busy = false
	_step = 0
	_resolved = false
	_briefed = false
	_hint_open = false
	_marks.clear()
	_picks.clear()
	_order.clear()
	_shuffle.clear()
	_branch_id = "start"
	_log.clear()
	_timer_on = false
	set_process(false)
	var lesson := _current_lesson()
	_activity = str(lesson.get("activity", "guided"))
	_show_activity()


func _current_lesson() -> Dictionary:
	if _lesson_index < 0 or _lesson_index >= _lessons.size():
		return {}
	return _lessons[_lesson_index]


func _show_activity() -> void:
	_clear_choices()
	_status_label.text = ""
	_footer_label.text = "LEVEL BLUE  //  INTEL"
	_progress_label.text = "L%02d/%02d  %s" % [_lesson_index + 1, _lessons.size(), _activity_tag()]
	_prev_file.visible = _review_mode
	_next_file.visible = _review_mode
	_prev_file.disabled = _lesson_index <= 0
	_next_file.disabled = _lesson_index >= _lessons.size() - 1
	_submit_button.disabled = true
	_submit_button.text = "CONTINUE  >"
	if _activity != "guided" and not _briefed and not _resolved:
		_show_brief()
		_style_submit()
		return
	match _activity:
		"guided":
			_show_guided()
		"trust":
			_show_trust()
		"spot":
			_show_spot()
		"tap":
			_show_tap()
		"branch":
			_show_branch()
		"triage":
			_show_triage()
		"consequence":
			_show_consequence()
		"reverse":
			_show_reverse()
		"timeline":
			_show_timeline()
		_:
			_show_guided()
	_style_submit()


func _activity_tag() -> String:
	match _activity:
		"guided":
			return "WALK"
		"trust":
			return "TRUST"
		"spot":
			return "SPOT"
		"tap":
			return "TAP"
		"branch":
			return "CALL"
		"triage":
			return "INBOX"
		"consequence":
			return "STAKES"
		"reverse":
			return "FORGE"
		"timeline":
			return "ORDER"
		_:
			return _activity.to_upper()


func _show_brief() -> void:
	var lesson := _current_lesson()
	_photo_well.visible = true
	_evidence_glyph.kind = IntelPixelIcon.Kind.BOOKS
	_case_label.text = str(lesson.get("title", "LESSON")).to_upper()
	_body_label.text = _brief_text()
	_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_report_title.text = "BEFORE YOU START"
	_add_plain_label(_how_text())
	_add_plain_label("QUESTION\n%s" % _question_text())
	_status_label.text = "No score yet. Read this, then start."
	_status_label.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
	_submit_button.text = "START  >"
	_submit_button.disabled = false


func _brief_text() -> String:
	var custom := str(_current_lesson().get("brief", "")).strip_edges()
	if not custom.is_empty():
		return custom
	match _activity:
		"trust":
			return "You will read one full message. Decide if it is safe to trust, or if it is a trick. A wrong guess is still a lesson — you will get a safety-net note either way."
		"spot":
			return "You will see a real message on the left and a fake one on the right. They look close on purpose. Your job is to tap the one detail that proves the right side is fake."
		"tap":
			return "You will see one message split into lines. Some lines are the trick. One line looks sharp but is ordinary — that is a decoy. Tap only the lines that are actually dangerous, then submit."
		"branch":
			return "This is a back-and-forth. Each reply you pick changes what they say next. You can shut them down, or you can hand them what they want. It is a drill."
		"triage":
			return "You will get a mixed inbox and a clock. Sort each item: SAFE (keep), REPORT (flag as a trick), or IGNORE (junk, not urgent)."
		"consequence":
			return "You will see one lure. If you open it, you will see a fake aftermath screen — what would have happened. Nothing is really sent. Then we debrief."
		"reverse":
			return "You will build a fake message from ready-made tactics. Pick the lines that would actually hit the attacker's goal. Leave the honest lines out."
		"timeline":
			return "A trick often happens in steps. You will put those steps in order, then mark the step where you should have stopped."
		_:
			return "Read the case, then do the drill on the right."


func _how_text() -> String:
	match _activity:
		"trust":
			return "HOW\nRead the message on the left. On the right, pick TRUST IT or DON'T TRUST. HINT is optional."
		"spot":
			return "HOW\nLeft is real. Right is fake. Tap the one difference that gives the fake away."
		"tap":
			return "HOW\nTap every suspicious line on the right so it stays highlighted. Leave the ordinary line alone. Press SUBMIT when you are done."
		"branch":
			return "HOW\nRead their line, then pick your reply. The next line depends on that pick."
		"triage":
			return "HOW\nTag each item SAFE, REPORT, or IGNORE before the clock runs out, then submit."
		"consequence":
			return "HOW\nChoose OPEN IT or LEAVE IT. Opening shows a fake compromised screen, then the debrief."
		"reverse":
			return "HOW\nTap tactics to add them to your draft. Submit when the draft would actually trick someone."
		"timeline":
			return "HOW\nTap events in the order they happen, then choose the step where suspicion should have kicked in."
		_:
			return "HOW\nFollow the question on the right."


func _question_text() -> String:
	var custom := str(_current_lesson().get("question", "")).strip_edges()
	if not custom.is_empty():
		return custom
	match _activity:
		"trust":
			return "Is this message safe to trust, or is it a trick?"
		"spot":
			return "What one detail proves the right side is fake?"
		"tap":
			return "Which lines are trying to trick you? Which line is ordinary?"
		"branch":
			return "What can you say that shuts this down instead of helping them?"
		"triage":
			return "For each item: keep it, report it, or ignore it?"
		"consequence":
			return "Do you open this, or leave it?"
		"reverse":
			return "Which tactics would actually hit the goal on the left?"
		"timeline":
			return "In what order did this happen, and where should you have stopped?"
		_:
			return "What is the trick here?"


func _show_guided() -> void:
	var lesson := _current_lesson()
	if _step == 0:
		var beat1: Dictionary = lesson.get("beat1_guided_example", {})
		_set_scenario(beat1.get("scenario", {}))
		_report_title.text = "LOOK CLOSELY"
		_submit_button.text = "CONTINUE  >"
		_submit_button.disabled = false
		_add_plain_label("Nobody can get this wrong. Just notice three things:")
		var notes: Array = beat1.get("observations", [])
		for i in notes.size():
			var note: Dictionary = notes[i]
			var item := int(note.get("checklist_item", i + 1))
			var text := "%d. %s\n%s" % [item, LessonCatalog.checklist_label(item), str(note.get("plain_language_note", ""))]
			_add_plain_label(text)
		return
	var beat1b: Dictionary = lesson.get("beat1_guided_example", {})
	_set_scenario(beat1b.get("scenario", {}))
	var beat2: Dictionary = lesson.get("beat2_name_it", {})
	_report_title.text = "NAME IT"
	_submit_button.text = "DONE  >"
	_submit_button.disabled = false
	_add_plain_label(str(beat2.get("reveal", "")))
	_add_plain_label(str(beat2.get("definition", "")))
	_add_plain_label(str(beat2.get("callback_line", "")))


func _show_trust() -> void:
	_clear_choices()
	var lesson := _current_lesson()
	_set_scenario(lesson.get("scenario", {}))
	_report_title.text = "TRUST IT OR NOT"
	if _resolved:
		_submit_button.disabled = false
		_submit_button.text = "DONE  >"
		return
	_status_label.text = "Guesses here do not count against you."
	_add_plain_label(_question_text())
	_add_btn("TRUST IT", func() -> void: _on_trust(false))
	_add_btn("DON'T TRUST", func() -> void: _on_trust(true))
	_add_btn("HINT", func() -> void: _on_hint())


func _on_hint() -> void:
	if _resolved:
		return
	_hint_open = true
	_status_label.text = str(_current_lesson().get("hint", "Look at who, what, and how fast."))
	_status_label.add_theme_color_override("font_color", Palette.GOLD)


func _on_trust(guessed_attack: bool) -> void:
	if _resolved or _busy:
		return
	var lesson := _current_lesson()
	var is_attack := bool(lesson.get("is_attack", true))
	var correct := guessed_attack == is_attack
	_resolved = true
	_clear_choices()
	if correct:
		_status_label.text = str(lesson.get("correct_feedback", "That's right."))
		_status_label.add_theme_color_override("font_color", Palette.GREEN)
	else:
		_status_label.text = str(lesson.get("incorrect_feedback", "Close. Look again."))
		_status_label.add_theme_color_override("font_color", Palette.GOLD)
	_add_plain_label(str(lesson.get("explanation", "")))
	_submit_button.text = "DONE  >"
	_submit_button.disabled = false
	_style_submit()


func _show_spot() -> void:
	_clear_choices()
	var lesson := _current_lesson()
	var real_s: Dictionary = lesson.get("real", {})
	_set_scenario(real_s)
	_case_label.text = "REAL"
	_body_label.text = str(real_s.get("content", ""))
	_report_title.text = "TAP THE TELL"
	if _resolved:
		_submit_button.disabled = false
		_submit_button.text = "DONE  >"
		_add_plain_label(str(lesson.get("explanation", "")))
		return
	_status_label.text = "Right side is the spoof. Tap one answer."
	_add_plain_label(_question_text())
	var fake_s: Dictionary = lesson.get("fake", {})
	_add_plain_label(str(fake_s.get("content", "")))
	var options: Array = lesson.get("options", [])
	for i in options.size():
		_add_btn(str(options[i]), _on_spot.bind(i))


func _on_spot(index: int) -> void:
	if _resolved:
		return
	var lesson := _current_lesson()
	var tell := int(lesson.get("tell_index", 0))
	_resolved = true
	_clear_choices()
	if index == tell:
		_status_label.text = "That's the giveaway."
		_status_label.add_theme_color_override("font_color", Palette.GREEN)
	else:
		_status_label.text = "Not the tell. Here's the one that matters."
		_status_label.add_theme_color_override("font_color", Palette.GOLD)
	_add_plain_label(str(lesson.get("explanation", "")))
	_submit_button.text = "DONE  >"
	_submit_button.disabled = false
	_style_submit()


func _show_tap() -> void:
	_clear_choices()
	var lesson := _current_lesson()
	var segs: Array = lesson.get("segments", [])
	var joined := ""
	for i in segs.size():
		var seg: Dictionary = segs[i]
		if i > 0:
			joined += "\n"
		joined += str(seg.get("text", ""))
	_set_scenario(lesson.get("scenario", {"channel": "email", "content": joined}))
	_body_label.text = joined
	_report_title.text = "YOUR JOB"
	if _resolved:
		_submit_button.disabled = false
		_submit_button.text = "DONE  >"
		return
	_add_plain_label(_question_text())
	_add_plain_label("Tap the dangerous lines. Leave the ordinary one unselected.")
	_status_label.text = "Highlighted lines stay marked. Press SUBMIT when ready."
	_status_label.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
	for i in segs.size():
		var on := bool(_marks.get(i, false))
		_add_btn(str(segs[i].get("text", "")), _toggle_mark.bind(i), on)
	_submit_button.text = "SUBMIT"
	_submit_button.disabled = false


func _toggle_mark(index: int) -> void:
	if _resolved:
		return
	_marks[index] = not bool(_marks.get(index, false))
	if _activity == "reverse":
		_show_reverse()
	else:
		_show_tap()


func _finish_tap() -> void:
	var lesson := _current_lesson()
	var segs: Array = lesson.get("segments", [])
	var hits := 0
	var tells := 0
	var traps := 0
	_clear_choices()
	for i in segs.size():
		var seg: Dictionary = segs[i]
		var on := bool(_marks.get(i, false))
		var is_tell := bool(seg.get("is_tell", false))
		var trap := bool(seg.get("trap", false))
		if is_tell:
			tells += 1
			if on:
				hits += 1
		if trap and on:
			traps += 1
		if on or is_tell:
			_add_plain_label("%s\n%s" % [str(seg.get("text", "")), str(seg.get("why", ""))])
	_resolved = true
	if traps > 0:
		_status_label.text = "Partial credit: %d/%d tells. You also marked a decoy that looked off but wasn't." % [hits, tells]
		_status_label.add_theme_color_override("font_color", Palette.GOLD)
	elif hits == tells and tells > 0:
		_status_label.text = "Clean catch. Every tell, no decoy."
		_status_label.add_theme_color_override("font_color", Palette.GREEN)
	else:
		_status_label.text = "Partial credit: %d/%d tells." % [hits, tells]
		_status_label.add_theme_color_override("font_color", Palette.GOLD)
	_submit_button.text = "DONE  >"
	_submit_button.disabled = false
	_style_submit()


func _show_branch() -> void:
	_clear_choices()
	var lesson := _current_lesson()
	var nodes: Dictionary = lesson.get("nodes", {})
	var node: Dictionary = nodes.get(_branch_id, {})
	var scene: Dictionary = lesson.get("scenario", {})
	var channel := str(scene.get("channel", "call"))
	_photo_well.visible = true
	_evidence_glyph.kind = _channel_kind(channel)
	_case_label.text = "CHANNEL: %s" % channel.to_upper()
	if _log.is_empty() and not str(node.get("line", "")).is_empty():
		_log.append(str(node.get("line", "")))
	_body_label.text = "\n\n".join(_log)
	_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_report_title.text = "YOUR MOVE"
	if bool(node.get("end", false)):
		_resolved = true
		var won := bool(node.get("won", false))
		_status_label.text = "They back off." if won else "They got what they came for. Drill only."
		_status_label.add_theme_color_override("font_color", Palette.GREEN if won else Palette.GOLD)
		_add_plain_label(str(node.get("debrief", "")))
		_submit_button.text = "DONE  >"
		_submit_button.disabled = false
		return
	_status_label.text = "Pick a reply. The next line depends on you."
	var choices: Array = node.get("choices", [])
	for i in choices.size():
		var choice: Dictionary = choices[i]
		_add_btn(str(choice.get("text", "")), _on_branch.bind(str(choice.get("next", ""))))


func _on_branch(next_id: String) -> void:
	if _resolved:
		return
	_branch_id = next_id
	var nodes: Dictionary = _current_lesson().get("nodes", {})
	var node: Dictionary = nodes.get(_branch_id, {})
	var line := str(node.get("line", ""))
	if not line.is_empty():
		_log.append(line)
	_show_branch()


func _show_triage() -> void:
	_clear_choices()
	var lesson := _current_lesson()
	if not _timer_on and not _resolved:
		_time_left = float(int(lesson.get("seconds", 40)))
		_timer_on = true
		set_process(true)
	_photo_well.visible = false
	_case_label.text = "INBOX"
	_body_label.text = "Sort each item: SAFE, REPORT, or IGNORE.\nClock is running."
	_report_title.text = "TRIAGE"
	if _resolved:
		_submit_button.disabled = false
		_submit_button.text = "DONE  >"
		return
	var items: Array = lesson.get("items", [])
	for i in items.size():
		var item: Dictionary = items[i]
		var pick := str(_picks.get(i, ""))
		var tag := pick.to_upper() if not pick.is_empty() else "—"
		_add_plain_label("%d. [%s] %s" % [i + 1, tag, str(item.get("preview", ""))])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		for action in ["safe", "report", "ignore"]:
			var b := Button.new()
			b.focus_mode = Control.FOCUS_NONE
			b.text = action.to_upper()
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.custom_minimum_size = Vector2(0, 36)
			if _pixel_font != null:
				b.add_theme_font_override("font", _pixel_font)
			b.add_theme_font_size_override("font_size", 8)
			_style_choice(b, pick == action)
			b.pressed.connect(_on_triage_pick.bind(i, action))
			row.add_child(b)
		_choice_list.add_child(row)
	_submit_button.text = "SUBMIT"
	_submit_button.disabled = false


func _on_triage_pick(index: int, action: String) -> void:
	if _resolved:
		return
	_picks[index] = action
	_show_triage()


func _finish_triage() -> void:
	_timer_on = false
	set_process(false)
	var lesson := _current_lesson()
	var items: Array = lesson.get("items", [])
	var right := 0
	_clear_choices()
	for i in items.size():
		var item: Dictionary = items[i]
		var correct := str(item.get("correct", ""))
		var pick := str(_picks.get(i, ""))
		if pick == correct:
			right += 1
		var mark := "OK" if pick == correct else "MISS"
		_add_plain_label("%s  you:%s  need:%s\n%s" % [mark, pick.to_upper() if pick else "—", correct.to_upper(), str(item.get("why", ""))])
	_resolved = true
	_status_label.text = "%d/%d sorted." % [right, items.size()]
	_status_label.add_theme_color_override("font_color", Palette.GREEN if right == items.size() else Palette.GOLD)
	_submit_button.text = "DONE  >"
	_submit_button.disabled = false
	_style_submit()


func _show_consequence() -> void:
	var lesson := _current_lesson()
	if _step == 0:
		_set_scenario(lesson.get("scenario", {}))
		_report_title.text = "YOUR CALL"
		_status_label.text = "Open it, or leave it. You will see what would follow."
		_add_btn("OPEN IT", func() -> void: _on_consequence(true))
		_add_btn("LEAVE IT", func() -> void: _on_consequence(false))
		return
	_photo_well.visible = true
	_evidence_glyph.kind = IntelPixelIcon.Kind.TERMINAL
	_case_label.text = "AFTER"
	var scene: Dictionary = lesson.get("scenario", {})
	_body_label.text = str(lesson.get("aftermath", "")) if bool(_marks.get("clicked", false)) else str(scene.get("content", ""))
	_report_title.text = "DEBRIEF"
	_add_plain_label(str(lesson.get("click_debrief" if bool(_marks.get("clicked", false)) else "ignore_debrief", "")))
	_submit_button.text = "DONE  >"
	_submit_button.disabled = false


func _on_consequence(clicked: bool) -> void:
	if _resolved and _step > 0:
		return
	_marks["clicked"] = clicked
	_step = 1
	_resolved = true
	if clicked:
		_clear_choices()
		_case_label.text = "AFTER"
		_photo_well.visible = true
		_evidence_glyph.kind = IntelPixelIcon.Kind.TERMINAL
		_body_label.text = str(_current_lesson().get("aftermath", ""))
		_report_title.text = "DEBRIEF"
		_status_label.text = "Drill only. Nothing left the device."
		_status_label.add_theme_color_override("font_color", Palette.GOLD)
		_add_plain_label(str(_current_lesson().get("click_debrief", "")))
		_submit_button.text = "DONE  >"
		_submit_button.disabled = false
		_style_submit()
		return
	_show_consequence()


func _show_reverse() -> void:
	_clear_choices()
	var lesson := _current_lesson()
	_photo_well.visible = false
	_case_label.text = "GOAL"
	var phrases: Array = lesson.get("phrases", [])
	var built := ""
	for i in phrases.size():
		if bool(_marks.get(i, false)):
			if not built.is_empty():
				built += "\n• "
			else:
				built = "• "
			built += str(phrases[i].get("text", ""))
	_body_label.text = "%s\n\nYOUR DRAFT:\n%s" % [str(lesson.get("goal", "")), built if not built.is_empty() else "(pick phrases)"]
	_report_title.text = "BUILD THE TRICK"
	if _resolved:
		_submit_button.disabled = false
		_submit_button.text = "DONE  >"
		return
	_status_label.text = "Pick the tactics that hit the goal. Skip the honest ones."
	for i in phrases.size():
		_add_btn(str(phrases[i].get("text", "")), _toggle_mark.bind(i), bool(_marks.get(i, false)))
	_submit_button.text = "SUBMIT"
	_submit_button.disabled = false


func _finish_reverse() -> void:
	var phrases: Array = _current_lesson().get("phrases", [])
	var good_hit := 0
	var good_total := 0
	var bad_hit := 0
	_clear_choices()
	for i in phrases.size():
		var row: Dictionary = phrases[i]
		var good := bool(row.get("good", false))
		var on := bool(_marks.get(i, false))
		if good:
			good_total += 1
			if on:
				good_hit += 1
		elif on:
			bad_hit += 1
	_resolved = true
	if good_hit >= 3 and bad_hit == 0:
		_status_label.text = "You built the playbook. That's how the other side thinks."
		_status_label.add_theme_color_override("font_color", Palette.GREEN)
	else:
		_status_label.text = "Tactics in: %d/%d. Honest lines you should have left out: %d." % [good_hit, good_total, bad_hit]
		_status_label.add_theme_color_override("font_color", Palette.GOLD)
	_add_plain_label(str(_current_lesson().get("beat4_summary", "")))
	_submit_button.text = "DONE  >"
	_submit_button.disabled = false
	_style_submit()


func _show_timeline() -> void:
	_clear_choices()
	var lesson := _current_lesson()
	var events: Array = lesson.get("events", [])
	if _shuffle.is_empty():
		_shuffle = _shuffled_indices(events.size(), str(lesson.get("title", "t")))
	_photo_well.visible = false
	_case_label.text = "TIMELINE"
	if _step == 0:
		var lined := ""
		for i in _order.size():
			lined += "%d. %s\n" % [i + 1, str(events[_order[i]])]
		_body_label.text = lined if not lined.is_empty() else "Tap events in the order they happen."
		_report_title.text = "REORDER"
		if _order.size() >= events.size():
			_status_label.text = "That's your order. Continue to mark where suspicion should kick in."
			_submit_button.text = "CONTINUE  >"
			_submit_button.disabled = false
			return
		_status_label.text = "Tap next."
		for i in _shuffle.size():
			var idx: int = _shuffle[i]
			if _order.has(idx):
				continue
			_add_btn(str(events[idx]), _on_timeline_pick.bind(idx))
		_add_btn("RESET ORDER", func() -> void: _order.clear(); _show_timeline())
		return
	_body_label.text = _joined_order(events)
	_report_title.text = "WHERE TO STOP"
	if _resolved:
		_submit_button.disabled = false
		_submit_button.text = "DONE  >"
		return
	_status_label.text = "Which step should have made you stop?"
	for i in events.size():
		_add_btn("%d. %s" % [i + 1, str(events[i])], _on_suspicion.bind(i))


func _joined_order(events: Array) -> String:
	var lined := ""
	var src: Array[int] = _order if _order.size() == events.size() else _range(events.size())
	for i in src.size():
		lined += "%d. %s\n" % [i + 1, str(events[src[i]])]
	return lined


func _range(n: int) -> Array[int]:
	var arr: Array[int] = []
	for i in n:
		arr.append(i)
	return arr


func _on_timeline_pick(index: int) -> void:
	if _resolved or _step != 0:
		return
	_order.append(index)
	_show_timeline()


func _on_suspicion(index: int) -> void:
	if _resolved:
		return
	var lesson := _current_lesson()
	var need := int(lesson.get("suspicion_index", 0))
	_resolved = true
	_clear_choices()
	if index == need:
		_status_label.text = "Yes. That's the kick-in."
		_status_label.add_theme_color_override("font_color", Palette.GREEN)
	else:
		_status_label.text = "Close. The stop line is earlier than that."
		_status_label.add_theme_color_override("font_color", Palette.GOLD)
	_add_plain_label(str(lesson.get("explanation", "")))
	_submit_button.text = "DONE  >"
	_submit_button.disabled = false
	_style_submit()


func _shuffled_indices(n: int, seed_s: String) -> Array[int]:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_s)
	var arr: Array[int] = []
	for i in n:
		arr.append(i)
	for i in range(n - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: int = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
	return arr


func _on_continue() -> void:
	if _busy or _submit_button.disabled:
		return
	if _activity != "guided" and not _briefed and not _resolved:
		_briefed = true
		_show_activity()
		return
	match _activity:
		"guided":
			if _step == 0:
				_step = 1
				_show_activity()
			else:
				_finish_lesson()
		"tap":
			if not _resolved:
				_finish_tap()
			else:
				_finish_lesson()
		"triage":
			if not _resolved:
				_finish_triage()
			else:
				_finish_lesson()
		"reverse":
			if not _resolved:
				_finish_reverse()
			else:
				_finish_lesson()
		"timeline":
			if _step == 0 and not _resolved:
				_step = 1
				_show_timeline()
			else:
				_finish_lesson()
		_:
			if _resolved or _activity == "guided":
				_finish_lesson()


func _finish_lesson() -> void:
	_timer_on = false
	set_process(false)
	if _review_mode:
		Router.request_back()
		return
	if _busy:
		return
	_busy = true
	PlayerManager.complete_lesson_unit(_module_id, _lessons.size(), LessonCatalog.module_ids())
	await get_tree().create_timer(0.35).timeout
	if not is_inside_tree():
		return
	var next: int = PlayerManager.get_lesson_progress(_module_id)
	if next >= _lessons.size():
		Router.request_back()
		return
	_lesson_index = next
	_start_lesson()


func _browse_lesson(delta: int) -> void:
	if not _review_mode or _lessons.is_empty():
		return
	_lesson_index = clampi(_lesson_index + delta, 0, _lessons.size() - 1)
	_start_lesson()


func _set_scenario(scene: Dictionary) -> void:
	var channel := str(scene.get("channel", "email"))
	_case_label.text = "CHANNEL: %s" % channel.to_upper()
	_body_label.text = str(scene.get("content", ""))
	_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_photo_well.visible = true
	_evidence_glyph.kind = _channel_kind(channel)


func _add_plain_label(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_label(label, Palette.TEXT_PRIMARY, 10)
	_choice_list.add_child(label)


func _add_btn(text: String, cb: Callable, selected: bool = false) -> void:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0, 48)
	button.text = text
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.pressed.connect(cb)
	if _pixel_font != null:
		button.add_theme_font_override("font", _pixel_font)
	button.add_theme_font_size_override("font_size", 11)
	_choice_list.add_child(button)
	_style_choice(button, selected)


func _clear_choices() -> void:
	var existing: Array = _choice_list.get_children()
	for i in existing.size():
		var child: Node = existing[i] as Node
		if child != null:
			_choice_list.remove_child(child)
			child.queue_free()


func _channel_kind(channel: String) -> IntelPixelIcon.Kind:
	match channel:
		"sms", "call":
			return IntelPixelIcon.Kind.PHONE
		"in-person":
			return IntelPixelIcon.Kind.BADGE
		"usb-drive":
			return IntelPixelIcon.Kind.TERMINAL
		_:
			return IntelPixelIcon.Kind.ENVELOPE


func _pixel_box(bg: Color, border: Color, radius: int, border_w: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(border_w)
	box.set_corner_radius_all(radius)
	return box


func _style_file_pane() -> void:
	var box := _pixel_box(Palette.FIELD_BG, Palette.CASTLE_STONE, 0, 3)
	box.content_margin_left = 18.0
	box.content_margin_right = 18.0
	box.content_margin_top = 14.0
	box.content_margin_bottom = 12.0
	box.shadow_color = Color(Palette.BG_DEEP, 0.7)
	box.shadow_size = 1
	box.shadow_offset = Vector2(5, 5)
	_file_pane.add_theme_stylebox_override("panel", box)


func _style_report_pane() -> void:
	var box := _pixel_box(Palette.CYAN_DIM, Palette.CYAN, 0, 3)
	box.content_margin_left = 16.0
	box.content_margin_right = 16.0
	box.content_margin_top = 12.0
	box.content_margin_bottom = 12.0
	box.shadow_color = Color(Palette.BG_DEEP, 0.7)
	box.shadow_size = 1
	box.shadow_offset = Vector2(5, 5)
	_report_pane.add_theme_stylebox_override("panel", box)


func _style_photo_well() -> void:
	var box := _pixel_box(Palette.FOREST_NIGHT, Palette.CASTLE_SHADOW, 0, 2)
	box.content_margin_left = 8.0
	box.content_margin_right = 8.0
	box.content_margin_top = 8.0
	box.content_margin_bottom = 8.0
	_photo_well.add_theme_stylebox_override("panel", box)


func _style_close_button() -> void:
	_close_button.custom_minimum_size = Vector2(44, 32)
	var normal := _pixel_box(Palette.RED, Palette.RED_DEEP, 0, 2)
	var hover := _pixel_box(Palette.RED, Palette.TEXT_PRIMARY, 0, 2)
	_close_button.add_theme_stylebox_override("normal", normal)
	_close_button.add_theme_stylebox_override("hover", hover)
	_close_button.add_theme_stylebox_override("pressed", hover)
	_close_button.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
	if _pixel_font != null:
		_close_button.add_theme_font_override("font", _pixel_font)
	_close_button.add_theme_font_size_override("font_size", 12)


func _style_nav_file(button: Button) -> void:
	button.custom_minimum_size = Vector2(120, 44)
	var box := _pixel_box(Color(Palette.BG_DEEP, 0.4), Palette.CYAN, 0, 2)
	box.content_margin_left = 10.0
	box.content_margin_right = 10.0
	box.content_margin_top = 10.0
	box.content_margin_bottom = 10.0
	button.add_theme_stylebox_override("normal", box)
	button.add_theme_stylebox_override("hover", box)
	button.add_theme_stylebox_override("pressed", box)
	button.add_theme_stylebox_override("disabled", _pixel_box(Color(Palette.BG_DEEP, 0.25), Palette.TEXT_MUTED, 0, 2))
	button.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
	button.add_theme_color_override("font_disabled_color", Palette.TEXT_MUTED)
	if _pixel_font != null:
		button.add_theme_font_override("font", _pixel_font)
	button.add_theme_font_size_override("font_size", 11)


func _style_submit() -> void:
	var box := _pixel_box(Palette.GREEN, Palette.BG_DEEP, 0, 2)
	box.content_margin_left = 16.0
	box.content_margin_right = 16.0
	box.content_margin_top = 16.0
	box.content_margin_bottom = 16.0
	_submit_button.add_theme_stylebox_override("normal", box)
	_submit_button.add_theme_stylebox_override("hover", box)
	_submit_button.add_theme_stylebox_override("pressed", box)
	_submit_button.add_theme_stylebox_override("disabled", _pixel_box(Palette.TEXT_MUTED, Palette.BG_DEEP, 0, 2))
	_submit_button.add_theme_color_override("font_color", Palette.BG_DEEP)
	_submit_button.add_theme_color_override("font_disabled_color", Palette.BG_DEEP)
	if _pixel_font != null:
		_submit_button.add_theme_font_override("font", _pixel_font)
	_submit_button.add_theme_font_size_override("font_size", 16)
	_submit_button.custom_minimum_size = Vector2(0, 56)


func _style_choice(button: Button, selected: bool) -> void:
	var fill := Palette.FIELD_BG if selected else Color(Palette.BG_DEEP, 0.35)
	var border := Palette.TEXT_PRIMARY if selected else Palette.CYAN
	var text := Palette.FIELD_TEXT if selected else Palette.TEXT_PRIMARY
	var box := _pixel_box(fill, border, 0, 2)
	box.content_margin_left = 12.0
	box.content_margin_right = 12.0
	box.content_margin_top = 10.0
	box.content_margin_bottom = 10.0
	button.add_theme_stylebox_override("normal", box)
	button.add_theme_stylebox_override("hover", box)
	button.add_theme_stylebox_override("pressed", box)
	button.add_theme_color_override("font_color", text)


func _apply_label(label: Control, color: Color, font_size: int) -> void:
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	if _pixel_font != null:
		label.add_theme_font_override("font", _pixel_font)


func _load_font() -> void:
	if not ResourceLoader.exists(FONT_PATH):
		return
	var file: FontFile = load(FONT_PATH) as FontFile
	if file != null:
		_pixel_font = file
