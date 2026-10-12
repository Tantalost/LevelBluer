extends CanvasLayer
## One presentation/request owner shared by Settings and both result presentations.
## Drafts are account-scoped, memory-only, and never auto-submitted.
signal submitted
signal closed
const UI: GDScript = preload("res://src/ui/screens/intel/study_ui.gd")
const QUESTIONS: PackedStringArray = [
	"The game was easy to navigate.", "I understood why my answers were wrong.",
	"The difficulty felt right for me.", "I would recommend this to a classmate.",
	"The quizzes felt relevant to real scams."]
const MODULES: Dictionary = {"mod_01": "Phishing", "mod_02": "Smishing", "mod_03": "Vishing", "mod_04": "Pretexting", "mod_05": "Baiting"}
static var _drafts: Dictionary = {}
var context: Dictionary = {}
var _identity: String = ""
var _draft_key: String = ""
var _scores: Array[int] = [0, 0, 0, 0, 0]
var _comment: String = ""
var _kind: int = 0
var _step: int = 0
var _busy: bool = false
var _sent: bool = false
var _token: String = ""
var _panel: PanelContainer
var _body: VBoxContainer
var _scroll: ScrollContainer
var _status: Label
var _heading: Label
var _next: Button
var _back: Button
var _close: Button
var _http: HTTPRequest
var _message: TextEdit
var _type: OptionButton
var _font_size: int = 24
var _touch: float = 48.0
var _keyboard_height: int = 0

static func open(parent: Node, details: Dictionary = {}) -> CanvasLayer:
	var existing: Node = parent.get_node_or_null("StudentFeedback")
	if existing != null:
		return existing as CanvasLayer
	var form: CanvasLayer = load("res://src/ui/screens/settings/student_feedback.gd").new()
	form.name = "StudentFeedback"
	form.set("context", details.duplicate(true))
	parent.add_child(form)
	return form

func _ready() -> void:
	add_to_group("student_feedback_modal")
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_identity = AuthService.participant_code()
	_draft_key = _identity + ":" + str(context.get("module_id", "")) + ":" + str(context.get("stage", 0)) + ":" + str(context.get("won", false))
	var draft: Dictionary = _drafts.get(_draft_key, {})
	if not draft.is_empty():
		_scores.assign(draft.scores)
		_comment = str(draft.comment)
		_kind = int(draft.kind)
	var shade: ColorRect = ColorRect.new()
	shade.color = Color("050b18ed")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UI.box(Color("0a1730"), Color("4fe0d4"), 16))
	add_child(_panel)
	var column: VBoxContainer = UI.column(_panel, 10)
	var header: HBoxContainer = HBoxContainer.new()
	column.add_child(header)
	_heading = UI.label("", 24, Color("8ff0e6"))
	_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_heading)
	_close = UI.button("Close", _dismiss)
	header.add_child(_close)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_scroll)
	_body = UI.column(_scroll, 12)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status = UI.label("", 24, Color("ffb648"))
	column.add_child(_status)
	var footer: HBoxContainer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	column.add_child(footer)
	_back = UI.button("Back", _previous)
	footer.add_child(_back)
	_next = UI.button("Next", _advance, true)
	_next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_next)
	_http = HTTPRequest.new()
	_http.timeout = 25.0
	_http.max_redirects = 0 # Never forward the student's bearer token to a redirect.
	_http.body_size_limit = 65536
	add_child(_http)
	_http.request_completed.connect(_completed)
	AuthService.session_changed.connect(_session_changed)
	get_viewport().size_changed.connect(_layout)
	_panel.minimum_size_changed.connect(_layout.call_deferred)
	_layout()
	_render()
	_close.grab_focus()

func _layout() -> void:
	var area: Vector2 = get_viewport().get_visible_rect().size
	var scale_y: float = maxf(0.1, get_viewport().get_final_transform().get_scale().y)
	_font_size = maxi(24, ceili(16.0 / scale_y))
	_touch = maxf(48.0, ceilf(48.0 / scale_y))
	_scale_controls(_panel)
	_panel.position = Vector2(24, 16)
	_panel.size = area - Vector2(48, 32 + float(_keyboard_height) / scale_y)

func _scale_controls(node: Node) -> void:
	if node is Control:
		(node as Control).add_theme_font_size_override("font_size", _font_size)
		(node as Control).add_theme_font_override("font", UI.FONT)
	if node is BaseButton:
		(node as Control).custom_minimum_size.y = _touch
	for child: Node in node.get_children():
		_scale_controls(child)

func _render() -> void:
	for child: Node in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	_heading.text = "STUDENT FEEDBACK / %d OF 2" % (_step + 1)
	_back.visible = _step == 1 and not _sent
	_next.text = "Send feedback" if _step == 1 else "Next"
	_status.text = ""
	if not AuthService.is_signed_in():
		_status.text = "Sign in with your student account to send feedback."
	_next.disabled = not AuthService.is_signed_in()
	if _step == 0:
		_body.add_child(UI.label("Your experience matters. Choose your own ratings — feedback does not affect your grades or rewards.", _font_size))
		_body.add_child(UI.label("1 Strongly disagree  /  2 Disagree  /  3 Neutral  /  4 Agree  /  5 Strongly agree", _font_size, Color("8ff0e6")))
		for index: int in QUESTIONS.size():
			var row: HBoxContainer = HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			_body.add_child(row)
			var label: Label = UI.label("%d. %s" % [index + 1, QUESTIONS[index]], _font_size)
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(label)
			var group: ButtonGroup = ButtonGroup.new()
			for score: int in range(1, 6):
				var button: Button = UI.button(str(score), _rate.bind(index, score))
				button.custom_minimum_size.x = _touch
				button.toggle_mode = true
				button.button_group = group
				button.set_pressed_no_signal(_scores[index] == score)
				button.tooltip_text = "%s: %d out of 5" % [QUESTIONS[index], score]
				row.add_child(button)
	else:
		_body.add_child(UI.label("Sending as %s. Teachers and school heads can read your response; it is not anonymous." % AuthService.full_name(), _font_size))
		_body.add_child(UI.label("Context: " + _context_text(), _font_size, Color("8ff0e6")))
		_body.add_child(UI.label("Feedback type", _font_size))
		_type = OptionButton.new()
		_type.add_item("Comment / suggestion")
		_type.add_item("Bug report")
		_type.select(_kind)
		_type.item_selected.connect(func(index: int) -> void: _kind = index; _save_draft())
		_body.add_child(_type)
		_body.add_child(UI.label("What happened, or what could we improve? Please don't include passwords or private information.", _font_size))
		_message = TextEdit.new()
		_message.custom_minimum_size.y = _touch * 2.5
		_message.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
		_message.placeholder_text = "Optional for comments; required for bug reports. Up to 4,500 characters."
		_message.text = _comment
		_message.add_theme_font_override("font", UI.FONT)
		_message.text_changed.connect(func() -> void: _comment = _message.text; _save_draft())
		_body.add_child(_message)
		_body.add_child(UI.label("Ratings: %s. Module and stage context above is included with your comments." % str(_scores), _font_size, Color("8ff0e6")))
	_scroll.scroll_vertical = 0
	_scale_controls(_panel)
	_layout.call_deferred()

func _context_text() -> String:
	var module: String = str(MODULES.get(str(context.get("module_id", "")), ""))
	if module.is_empty():
		return "General app experience"
	var stage: int = int(context.get("stage", 0))
	return "%s / Stage %d / %s" % [module, stage, "Cleared" if bool(context.get("won", false)) else "Not cleared"] if stage > 0 else module

func _rate(index: int, score: int) -> void:
	_scores[index] = score
	_save_draft()

func _save_draft() -> void:
	if not _sent and not _identity.is_empty():
		_drafts[_draft_key] = {"scores": _scores.duplicate(), "comment": _comment, "kind": _kind}

func _previous() -> void:
	if not _busy:
		_step = 0
		_render()

func _advance() -> void:
	if _busy or _sent:
		return
	if _scores.has(0):
		_status.text = "Choose a rating for all five statements first."
		return
	if _step == 0:
		_step = 1
		_render()
		return
	if _comment.length() > 4500 or (_kind == 1 and _comment.strip_edges().is_empty()):
		_status.text = "Describe the bug before sending." if _comment.strip_edges().is_empty() else "Please shorten your message to 4,500 characters."
		return
	if not AuthService.is_signed_in() or _identity.is_empty() or AuthService.auth_token().is_empty() or AuthService.participant_code() != _identity:
		_status.text = "Your session changed. Close this form and sign in again."
		return
	var base: String = str(ProjectSettings.get_setting("levelblue/feedback_api_base_url", "")).strip_edges().trim_suffix("/")
	if not _safe_endpoint(base):
		_status.text = "Feedback server is not configured. Your draft is kept for this session."
		return
	_token = AuthService.auth_token()
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		DisplayServer.virtual_keyboard_hide()
	_set_busy(true)
	_status.text = "Sending… Please wait."
	var error: Error = _http.request(base + "/api/usability-feedback", PackedStringArray(["Content-Type: application/json", "Accept: application/json", "Authorization: Bearer " + _token]), HTTPClient.METHOD_POST, JSON.stringify(_payload()))
	if error != OK:
		_set_busy(false)
		_status.text = "Could not connect. Your draft is kept; you can try again."

static func _safe_endpoint(base: String) -> bool:
	var pattern: RegEx = RegEx.new()
	pattern.compile("^https://[A-Za-z0-9.-]+(:[0-9]+)?(/[A-Za-z0-9_/-]+)?$|^http://(127\\.0\\.0\\.1|localhost):[0-9]+$")
	return pattern.search(base) != null

func _payload() -> Dictionary:
	var payload: Dictionary = {"feedbackType": "bug" if _kind == 1 else "comment", "comments": "[Mobile / %s]\n%s" % [_context_text(), _comment.strip_edges()]}
	for index: int in 5:
		payload["q%d" % (index + 1)] = _scores[index]
	var module: String = str(MODULES.get(str(context.get("module_id", "")), ""))
	if not module.is_empty():
		payload["module"] = module
	return payload

func _set_busy(value: bool) -> void:
	_busy = value
	_next.disabled = value or _sent
	_back.disabled = value
	_close.disabled = value
	if is_instance_valid(_message):
		_message.editable = not value
	if is_instance_valid(_type):
		_type.disabled = value

func _completed(result: int, code: int, _headers: PackedStringArray, _body_bytes: PackedByteArray) -> void:
	if not _busy:
		return
	if AuthService.auth_token() != _token or AuthService.participant_code() != _identity:
		_dismiss_session()
		return
	_set_busy(false)
	var response: Variant = JSON.parse_string(_body_bytes.get_string_from_utf8()) if not _body_bytes.is_empty() else null
	if result == HTTPRequest.RESULT_SUCCESS and code == 201 and response is Dictionary and not str((response as Dictionary).get("_id", "")).is_empty():
		_sent = true
		_drafts.erase(_draft_key)
		_heading.text = "FEEDBACK SENT"
		for child: Node in _body.get_children():
			_body.remove_child(child)
			child.queue_free()
		_body.add_child(UI.label("Thanks for helping improve LEVELBLUE! Your response was received.", _font_size, Color("33d17a")))
		_status.text = "You can close this window and continue playing."
		_next.hide()
		_back.hide()
		submitted.emit()
		return
	match code:
		401, 403: _status.text = "Please sign in again with a current student account. Your draft is kept."
		400: _status.text = "The server rejected this response. Check the ratings and message; your draft is kept."
		429: _status.text = "Too many requests. Wait a moment before trying again. Your draft is kept."
		503: _status.text = "Feedback is temporarily unavailable. Your draft is kept; try again later."
		_: _status.text = "Delivery could not be confirmed. Your draft is kept. Retrying may send a duplicate if the server already received it."

func _session_changed(_signed_in: bool) -> void:
	if not AuthService.is_signed_in() or AuthService.participant_code() != _identity:
		_dismiss_session()

func _dismiss_session() -> void:
	_http.cancel_request()
	_busy = false
	_drafts.clear()
	closed.emit()
	queue_free()

func _dismiss() -> void:
	if _busy:
		return
	_save_draft()
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		DisplayServer.virtual_keyboard_hide()
	closed.emit()
	queue_free()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_dismiss()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_focus_next") or event.is_action_pressed("ui_focus_prev"):
		var controls: Array[Control] = []
		_focus_controls(_panel, controls)
		if not controls.is_empty():
			var current: int = controls.find(get_viewport().gui_get_focus_owner())
			var direction: int = -1 if event.is_action_pressed("ui_focus_prev") else 1
			controls[posmod(current + direction, controls.size())].grab_focus()
		get_viewport().set_input_as_handled()

func _focus_controls(node: Node, controls: Array[Control]) -> void:
	if node is Control:
		var control: Control = node as Control
		if control.is_visible_in_tree() and control.focus_mode == Control.FOCUS_ALL and not (control is BaseButton and (control as BaseButton).disabled):
			controls.append(control)
	for child: Node in node.get_children():
		_focus_controls(child, controls)

func _exit_tree() -> void:
	_http.cancel_request()
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		DisplayServer.virtual_keyboard_hide()

func _process(_delta: float) -> void:
	if not DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		return
	var height: int = DisplayServer.virtual_keyboard_get_height()
	if height != _keyboard_height:
		_keyboard_height = height
		_layout()
		if height > 0 and is_instance_valid(_message):
			_scroll.ensure_control_visible.call_deferred(_message)
