extends "res://src/gameplay/decision/survey_phone.gd"
var _notice: bool = false
var _detail: String = ""
var _response: String = ""

func _init() -> void:
	Chapter = preload("res://src/gameplay/decision/just_open_it_chapter.gd")

func configure_chapter(next_mode: String, snapshot: Dictionary) -> void:
	_notice = next_mode == "read" and snapshot.read.is_empty()
	_detail = ""
	_response = ""
	super.configure_chapter(next_mode,snapshot)
	if _notice: AudioManager.play_sfx("ui_notification")

func _render() -> void:
	if not is_instance_valid(_content): return
	UI.clear(_content)
	match mode:
		"read":
			_activity_text("CLUB CHAT / PINNED DESIGN DESK")
			if _notice:
				_action("Open reply to Mika",_open_reply)
			else:
				_activity_text(Chapter.REPLY)
				if not phase_ready(): _action("Keep desk reply",_keep_reply)
		"sources":
			if phase_ready(): _activity_success("SOURCES CHECKED\nThe pinned desk denies sending a helper. The installation request came from the separate offer.")
			else:
				_action(_label_for("desk_record","Pinned desk reply"),_inspect.bind("desk_record"))
				_action(_label_for("offer_record","Event Recovery Desk message"),_inspect.bind("offer_record"))
				if _detail == "desk_record": _activity_text("Student Design Desk / "+Chapter.REPLY)
				if _detail == "offer_record": _activity_text("Event Recovery Desk / "+Chapter.INSTRUCTION)
				if _seen_sources():
					_activity_text("Who asked Mika to install software?")
					_choices("Pinned design desk",_answer.bind(false),"Event Recovery Desk",_answer.bind(true))
		"inspect":
			if phase_ready(): _activity_success("ACTION IDENTIFIED\nThe poster thumbnail accompanies an app package. The sender asks for an installation setting.")
			else:
				_activity_text("ATTACHMENT DETAILS / Tap to inspect")
				_part_button("preview","Club event poster / Thumbnail")
				_part_button("type","EventPreview.apk / File details")
				_part_button("permission","Allow installation / Requested setting")
				if Chapter.PARTS.has(_detail): _activity_text(Chapter.PARTS[_detail])
				if _seen_parts():
					_activity_text("What does the helper ask Mika to do?")
					_choices("View a poster",_answer.bind(false),"Install an app",_answer.bind(true))
		"preserve":
			if phase_ready(): _activity_success("PACKAGE CLOSED\nMessage, file details and desk reply saved. Installation from this source stays off.")
			else:
				_activity_text("The pinned design desk has supplied a different route to the signs. What should Mika keep?")
				_action("Keep closed and preserve details",_answer.bind(true))
				_action("Install the helper to check the poster",_answer.bind(false))
	if not _response.is_empty(): _activity_text(_response)
	_refresh()
	_metrics()

func _label_for(id: String, label: String) -> String:
	return ("✓ " if state.sorted.has(id) else "")+label

func _part_button(id: String, label: String) -> void:
	var button: Button = _action(_label_for(id,label),_inspect.bind(id))
	if state.sorted.has(id):
		button.add_theme_stylebox_override("normal",UI.box(Color("dcefe2"),Color("33D17A"),12))
	if id == "preview":
		# The poster is a touchable thumbnail inside the record, with no external file.
		var poster: Polygon2D = Polygon2D.new()
		poster.polygon = PackedVector2Array([Vector2(12,7),Vector2(54,7),Vector2(54,56),Vector2(12,56)])
		poster.color = Color("153B37")
		button.add_child(poster)
		var arrow: Polygon2D = Polygon2D.new()
		arrow.polygon = PackedVector2Array([Vector2(16,28),Vector2(33,28),Vector2(33,18),Vector2(49,32),Vector2(33,47),Vector2(33,37),Vector2(16,37)])
		arrow.color = Color("8FF0E6")
		poster.add_child(arrow)

func _seen_sources() -> bool:
	return state.sorted.has("desk_record") and state.sorted.has("offer_record")

func _seen_parts() -> bool:
	for key: String in Chapter.PARTS:
		if not state.sorted.has(key): return false
	return true

func _open_reply() -> void:
	if _locked or mode != "read" or not _notice: return
	_notice = false
	_render()

func _keep_reply() -> void:
	if _locked or mode != "read" or _notice or phase_ready(): return
	_add("read","desk")
	_render()

func _inspect(id: String) -> void:
	if _locked or phase_ready(): return
	var source: bool = mode == "sources" and state.read.has("desk") and id in ["desk_record","offer_record"]
	var part: bool = mode == "inspect" and state.flags.has("helper") and Chapter.PARTS.has(id)
	if not source and not part: return
	_detail = id
	_response = ""
	_add("sorted",id)
	_render()
	_reveal_detail()

func _answer(correct: bool) -> void:
	if _locked or phase_ready(): return
	var field: String
	var explanation: String
	match mode:
		"sources":
			if not state.read.has("desk") or not _seen_sources(): return
			field = "flags"
			explanation = "The pinned desk says its signs are in the club folder. Read the instruction from the separate offer."
		"inspect":
			if not state.flags.has("helper") or not _seen_parts(): return
			field = "domains"
			explanation = "The preview shows an arrow. The file details say Android app package, and the sender asks for permission to install it."
		"preserve":
			if not state.domains.has("helper"): return
			field = "captures"
			explanation = "The message and file details are already visible. Keep the package closed and preserve those records."
		_: return
	if not correct:
		state.mistakes += 1
		evidence_changed.emit(state.duplicate(true))
		show_feedback(explanation)
		return
	_response = ""
	_add(field,"helper")
	AudioManager.play_sfx("ui_confirm")
	_render()
	(_content.get_parent() as ScrollContainer).scroll_vertical = 0

func show_feedback(text: String) -> void:
	_response = text
	_render()
	_reveal_detail()

func _reveal_detail() -> void:
	var last: Control = _content.get_child(-1) as Control
	var scroll: ScrollContainer = _content.get_parent() as ScrollContainer
	(func() -> void:
		if is_instance_valid(scroll) and is_instance_valid(last) and scroll.is_ancestor_of(last): scroll.ensure_control_visible(last)
	).call_deferred()

func _refresh() -> void:
	super._refresh()
	_title.text = "Phone / Preview helper"
	_status.text = "Morning"
	_status.visible = mode == "read"
	_nav.visible = phase_ready()
	_close.text = "CONTINUE →"
	_close.disabled = _locked or not phase_ready()

func phase_ready() -> bool:
	if mode == "read": return state.get("read",[]).has("desk")
	var task: Dictionary = Chapter.TASKS.get(mode,{})
	return not task.is_empty() and state.get(task.field,[]).has("helper")

func _close_app() -> void:
	_finish_phase()
