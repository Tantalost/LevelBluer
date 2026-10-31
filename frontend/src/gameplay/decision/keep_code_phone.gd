extends "res://src/gameplay/decision/survey_phone.gd"
const Widgets: GDScript = preload("res://src/ui/screens/deploy/confrontation_widgets.gd")
var _picked: String = ""
var _feedback_text: String = ""

func _init() -> void:
	Chapter = preload("res://src/gameplay/decision/keep_code_chapter.gd")

func configure_chapter(next_mode: String, snapshot: Dictionary) -> void:
	_picked = ""
	_feedback_text = ""
	super.configure_chapter(next_mode,snapshot)

func _render() -> void:
	if not is_instance_valid(_content): return
	UI.clear(_content)
	if mode == "read":
		_activity_text("WALLET APP / EXISTING CASE LB-204\n" + str(Chapter.MESSAGES[0].body))
		_action("KEEP CASE RESPONSE / CONTINUE", _read_case)
	elif mode == "reconstruct":
		if phase_ready():
			_activity_success("SEQUENCE RECONSTRUCTED\nDelivery → Wallet code → Copied identity → Recovery pressure\nAmani verified independently and kept the code private.")
		else:
			_activity_text("Tap the requests from first to last. %d / 4 placed." % state.sorted.size())
			_choices(_event_label("identity"),_place_event.bind("identity"),_event_label("delivery"),_place_event.bind("delivery"))
			_choices(_event_label("recovery"),_place_event.bind("recovery"),_event_label("code"),_place_event.bind("code"))
	elif Chapter.CLAIMS.has(mode):
		_activity_text("CLAIM / “" + str(Chapter.CLAIMS[mode]) + "”")
		if phase_ready():
			_activity_success("CLAIM REFUTED\n" + str(Chapter.EXHIBITS[Chapter.CORRECT[mode]].detail))
		elif not _picked.is_empty():
			var exhibit: Dictionary = Chapter.EXHIBITS[_picked]
			_activity_text(str(exhibit.title).to_upper() + "\n" + str(exhibit.detail))
			_choices("USE THIS EVIDENCE",_rebut,"OTHER EVIDENCE",_back_to_evidence)
		else:
			_activity_text("CASE RECORD / Select evidence, read it, then challenge the claim.")
			for pair: Array in [["order","authorization"],["post","signal"]]:
				_choices(str(Chapter.EXHIBITS[pair[0]].title).to_upper(),_select_evidence.bind(str(pair[0])),str(Chapter.EXHIBITS[pair[1]].title).to_upper(),_select_evidence.bind(str(pair[1])))
	if not _feedback_text.is_empty(): _activity_text(_feedback_text)
	_refresh()
	_metrics()

func _refresh() -> void:
	super._refresh()
	_title.text = "Case record / Keep the Code"
	_status.text = "09:10  •  School Wi-Fi"
	_status.visible = mode == "read"
	_nav.visible = phase_ready()
	_close.text = "CONTINUE →"
	_close.accessibility_name = "Continue the evidence review"
	_close.disabled = _locked or not phase_ready()

func _read_case() -> void:
	if _locked or mode != "read": return
	_add("read","case")
	_refresh()
	_finish_phase()

func _select_evidence(id: String) -> void:
	if _locked or not Chapter.CLAIMS.has(mode) or phase_ready() or not Chapter.EXHIBITS.has(id): return
	_picked = id
	_feedback_text = ""
	_render()
	# Reuse the hearing's evidence artwork alongside Amani's own case text.
	var illustration: Control = Widgets.EvidenceIcon.new()
	illustration.kind = Chapter.EXHIBITS[id].kind
	illustration.custom_minimum_size.y = 40 / maxf(0.25,get_viewport().get_final_transform().get_scale().y)
	illustration.mouse_filter = MOUSE_FILTER_IGNORE
	_content.add_child(illustration)

func _back_to_evidence() -> void:
	if _locked: return
	_picked = ""
	_feedback_text = ""
	_render()

func _rebut() -> void:
	if _locked or not Chapter.CLAIMS.has(mode) or phase_ready() or _picked.is_empty(): return
	if _picked != Chapter.CORRECT[mode]:
		_wrong("That record does not contradict this claim. " + str(Chapter.TASKS[mode].tip))
		return
	_add(str(Chapter.TASKS[mode].field),"case")
	_feedback_text = ""
	AudioManager.play_sfx("ui_confirm")
	_render()

func _event_label(id: String) -> String:
	return ("✓ " if state.sorted.has(id) else "") + str(Chapter.EVENT_NAMES[id]).to_upper()

func _place_event(id: String) -> void:
	if _locked or mode != "reconstruct" or phase_ready() or state.sorted.has(id): return
	if id != Chapter.ORDER[state.sorted.size()]:
		_wrong(str(Chapter.TASKS.reconstruct.tip))
		return
	_add("sorted",id)
	_feedback_text = ""
	_render()

func _wrong(text: String) -> void:
	state.mistakes = int(state.mistakes) + 1
	evidence_changed.emit(state.duplicate(true))
	show_feedback(text)

func show_feedback(text: String) -> void:
	_feedback_text = text
	_render()

func phase_ready() -> bool:
	if mode == "reconstruct": return state.sorted == Chapter.ORDER
	var field: String = {"read":"read","fee":"flags","code":"domains","public":"captures"}.get(mode, "")
	return not field.is_empty() and (state.get(field, []) as Array).has("case")

func _close_app() -> void:
	_finish_phase()
