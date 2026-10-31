extends "res://src/gameplay/decision/survey_phone.gd"
## All conversations are local story simulations.
var _notice: bool = false
var _trusted_open: bool = false
var _feedback_text: String = ""

func _init() -> void:
	Chapter = preload("res://src/gameplay/decision/familiar_name_chapter.gd")

func configure_chapter(next_mode: String, snapshot: Dictionary) -> void:
	_notice = next_mode == "read" and snapshot.read.is_empty()
	_trusted_open = false
	_feedback_text = ""
	super.configure_chapter(next_mode, snapshot)
	if _notice: AudioManager.play_sfx("ui_notification")

func _profile(label_text: String) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	_content.add_child(row)
	var portrait: TextureRect = TextureRect.new()
	var sheet: Texture2D = AssetManager.get_texture("story_amani_poses")
	if sheet != null:
		var crop: AtlasTexture = AtlasTexture.new()
		crop.atlas = sheet
		crop.region = Rect2(Vector2.ZERO, sheet.get_size() / Vector2(3,2))
		portrait.texture = crop
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.custom_minimum_size = Vector2(64,64) / maxf(0.25,get_viewport().get_final_transform().get_scale().y)
	row.add_child(portrait)
	var copy: Label = UI.label(label_text,24,INK)
	copy.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(copy)

func _render() -> void:
	if not is_instance_valid(_content): return
	UI.clear(_content)
	if _notice:
		_activity_text("JOHN / FORWARDED MESSAGE\nDan received a payment request using Amani's name.")
		_action("VIEW FORWARDED MESSAGE", _open_notice)
	elif mode == "read":
		_profile("Amani · New number\nUnfamiliar contact / Same profile photo")
		_activity_text(Chapter.REQUEST)
		_action("KEEP MESSAGE / CONTINUE", _read_message)
	elif mode == "sources":
		if phase_ready():
			_activity_success("BOTH DETAILS WERE PUBLIC\nThe photo and delivery day could be copied. Knowing them does not authenticate this sender or implicate Dan.")
		else:
			_profile("PUBLIC CLUB POST / Posted by Dan\nAmani is organizing today's event. Materials arrive today.")
			_activity_text("NEW CONTACT: Same photo · Club parcel is stuck\nMatch each copied detail to this public post.")
			_choices(("✓ " if state.sorted.has("photo") else "") + "SAME PROFILE PHOTO", _match_detail.bind("photo"), ("✓ " if state.sorted.has("schedule") else "") + "DELIVERY TODAY", _match_detail.bind("schedule"))
	elif mode == "contact":
		if phase_ready():
			_activity_success("DIFFERENT CONTACT\nThe payment request is outside the established conversation. A matching name or photo cannot verify the new contact.")
		elif _trusted_open:
			_activity_text("ESTABLISHED CHAT / AMANI\nEarlier: Please bring tape to the clubroom.\nAvailable over school Wi-Fi. No payment request here.\n\nNEW CONTACT: Pay the parcel fee. New number for today.")
			_choices("TRUST THE MATCHING PHOTO", _wrong.bind("A photo can be copied from the public post. Compare the conversation and verify through a channel you already know."), "RECORD THE DIFFERENT CONTACT", _record_contact)
		else:
			_activity_text("NEW CONTACT / Amani · New number\nCompare with a conversation established before this request.")
			_choices("OPEN ESTABLISHED AMANI CHAT", _open_trusted, "ASK THE NEW CONTACT TO CONFIRM", _wrong.bind("The unfamiliar sender would be confirming their own story. Open the established conversation independently."))
	elif mode == "verify":
		if phase_ready():
			_activity_success("WARNING SENT / ESTABLISHED CLUB CHAT\n“" + Chapter.WARNING + "”\n\nNo payment sent. The cause of the signal loss and the sender's identity remain unknown.")
		elif not state.sorted.has("facts"):
			_activity_text("OBSERVED: No cellular signal. A different contact copied Amani's details. Her usual chat works over Wi-Fi.\nWhat conclusion does the evidence support?")
			_choices("SIGNAL LOSS PROVES A SIM SWAP", _wrong.bind("Signal loss has several possible causes. It does not prove a SIM swap or device compromise. Dan's public reminder also does not establish authorship."), "IMPERSONATION / CAUSE OF SIGNAL LOSS UNKNOWN", _confirm_facts)
		elif _trusted_open:
			_activity_text("ESTABLISHED CLUB CHAT / SCHOOL WI-FI\nAmani · Draft\n“" + Chapter.WARNING + "”")
			_action("SEND WARNING TO CLUB", _send_warning)
		else:
			_activity_text("Warn classmates through the club conversation you already use.")
			_choices("OPEN ESTABLISHED CLUB CHAT", _open_trusted, "ACCUSE DAN / HE KNEW THE DATE", _wrong.bind("The delivery date was public. Knowing it does not identify the sender. Warn the group about the request without making an unsupported accusation."))
	if not _feedback_text.is_empty(): _activity_text(_feedback_text)
	_refresh()
	_metrics()

func _refresh() -> void:
	super._refresh()
	_title.text = "Messages / Identity check"
	_status.text = "15:42  •  No signal  /  Wi-Fi" if mode != "read" else "15:42  •  Forwarded to John"
	_status.visible = mode == "read"
	_nav.visible = phase_ready()
	_close.text = "CONTINUE →"
	_close.accessibility_name = "Continue to the next story or investigation step"
	_close.disabled = _locked or not phase_ready()

func _open_notice() -> void:
	if _locked: return
	_notice = false
	_render()

func _read_message() -> void:
	if _locked or mode != "read" or _notice: return
	_add("read","identity")
	_refresh()
	_finish_phase()

func _match_detail(id: String) -> void:
	if _locked or mode != "sources" or id not in ["photo","schedule"] or phase_ready(): return
	_add("sorted",id)
	if state.sorted.has("photo") and state.sorted.has("schedule"): _add("flags","identity")
	_render()

func _open_trusted() -> void:
	if _locked or mode not in ["contact","verify"] or phase_ready(): return
	_trusted_open = true
	_feedback_text = ""
	_render()

func _record_contact() -> void:
	if _locked or mode != "contact" or not _trusted_open or phase_ready(): return
	_add("domains","identity")
	_feedback_text = ""
	_render()

func _confirm_facts() -> void:
	if _locked or mode != "verify" or phase_ready(): return
	_add("sorted","facts")
	_feedback_text = ""
	_render()

func _send_warning() -> void:
	if _locked or mode != "verify" or not _trusted_open or not state.sorted.has("facts") or phase_ready(): return
	_add("captures","identity")
	AudioManager.play_sfx("ui_confirm")
	_render()

func _wrong(explanation: String) -> void:
	if _locked or phase_ready() or not Chapter.TASKS.has(mode): return
	state.mistakes = int(state.mistakes) + 1
	evidence_changed.emit(state.duplicate(true))
	show_feedback(explanation)

func show_feedback(text: String) -> void:
	_feedback_text = text
	_render()
	var feedback: Control = _content.get_child(_content.get_child_count() - 1) as Control
	var scroll: ScrollContainer = _content.get_parent() as ScrollContainer
	(func() -> void:
		if is_instance_valid(feedback) and is_instance_valid(scroll) and scroll.is_ancestor_of(feedback):
			scroll.ensure_control_visible(feedback)
	).call_deferred()

func phase_ready() -> bool:
	var field: String = {"read":"read","sources":"flags","contact":"domains","verify":"captures"}.get(mode, "")
	return not field.is_empty() and (state.get(field, []) as Array).has("identity")

func _close_app() -> void:
	_finish_phase()
