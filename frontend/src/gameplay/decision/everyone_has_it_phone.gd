extends "res://src/gameplay/decision/survey_phone.gd"
var _notice: bool = false
var _detail: String = ""
var _response: String = ""

func _init() -> void:
	Chapter = preload("res://src/gameplay/decision/everyone_has_it_chapter.gd")

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
			_activity_text("EVENT RECOVERY DESK / OFFER THREAD")
			if _notice: _action("Open new message",_open_message)
			else:
				_activity_text(Chapter.OFFER)
				_quote_card("SUPPLIED CROP",Chapter.QUOTE+"\n— Amani",false)
				if not phase_ready(): _action("Keep the supplied crop",_keep_message)
		"compare":
			if phase_ready():
				_activity_success("CONTEXT RESTORED\nThe crop omits Mika's banner photo and question. Both records are kept with their sources.")
			else:
				_choices(_label_for("crop","Sender's crop"),_inspect.bind("crop"),_label_for("original","Existing club chat"),_inspect.bind("original"))
				if _detail == "crop":
					_quote_card("EVENT RECOVERY DESK / CROP",Chapter.QUOTE+"\n— Amani",false)
					_activity_text("The sender presents this as a recommendation for its event pack.")
				elif _detail == "original":
					_banner_record()
				if _seen_records():
					_activity_text("What did the crop remove?")
					_action("The banner photo and Mika's question",_answer.bind("context"))
					_action("Amani's name",_answer.bind("name"))
		"meaning":
			if phase_ready():
				_activity_success("ENDORSEMENT CHECKED\nAmani tried following the banner's arrow. Her reply does not endorse the app package or implicate her in the offer.")
			else:
				_action(_label_for("clarification","Read Amani's club reply"),_inspect.bind("clarification"))
				if state.sorted.has("clarification"):
					_quote_card("AMANI / EXISTING CLUB CHAT",Chapter.REPLY+" I followed the arrow from the gate. I didn't try their download.",true)
					_activity_text("What does her praise refer to?")
					_choices("The app package",_answer.bind("package"),"Mika's banner",_answer.bind("banner"))
		"warn":
			if phase_ready():
				_activity_success("CLUB WARNING POSTED\n"+Chapter.WARNING)
			else:
				_activity_text("Choose a warning for the existing club chat.")
				_action("Name the offer and installation request. Point to the pinned folder. No package.",_answer.bind("safe"))
				_action("Forward the package so everyone can test it.",_answer.bind("forward"))
				_action("Tell the club Amani is behind the scam.",_answer.bind("accuse"))
	if not _response.is_empty(): _activity_text(_response)
	_refresh()
	_metrics()

func _quote_card(heading: String, text: String, confirmed: bool) -> void:
	var panel: PanelContainer = UI.panel(_content,Color("dcefe2") if confirmed else Color("e8efed"))
	panel.add_theme_stylebox_override("panel",UI.box(Color("dcefe2") if confirmed else Color("e8efed"),Color("33D17A") if confirmed else Color("87aaa6"),12))
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation",10)
	panel.add_child(column)
	column.add_child(UI.label(heading,20,INK))
	column.add_child(UI.label(text,24,INK))

func _banner_record() -> void:
	var panel: PanelContainer = UI.panel(_content,Color("e8efed"))
	panel.add_theme_stylebox_override("panel",UI.box(Color("e8efed"),Color("87aaa6"),12))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation",16)
	panel.add_child(row)
	var photo: VBoxContainer = VBoxContainer.new()
	row.add_child(photo)
	var image: TextureRect = TextureRect.new()
	# Crop the shelter's actual painted banner into the original chat's photo.
	var texture: Texture2D = AssetManager.get_texture(Chapter.BACKGROUND_ASSET)
	if texture != null:
		var crop: AtlasTexture = AtlasTexture.new()
		crop.atlas = texture
		crop.region = Rect2(texture.get_size()*Vector2(.65,.49),texture.get_size()*Vector2(.35,.39))
		image.texture = crop
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.custom_minimum_size = Vector2(250,156)
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	photo.add_child(image)
	photo.add_child(UI.label("PHOTO / BEFORE HANGING",18,INK))
	var messages: VBoxContainer = VBoxContainer.new()
	messages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	messages.add_theme_constant_override("separation",12)
	row.add_child(messages)
	messages.add_child(UI.label("ORIGINAL / EXISTING CLUB CHAT",20,INK))
	messages.add_child(UI.label(Chapter.ORIGINAL,24,INK))
	messages.add_child(UI.label("Amani replied: "+Chapter.QUOTE,24,INK))

func _label_for(id: String, label: String) -> String:
	return ("✓ " if state.sorted.has(id) else "")+label

func _seen_records() -> bool:
	return state.sorted.has("crop") and state.sorted.has("original")

func _open_message() -> void:
	if _locked or mode != "read" or not _notice: return
	_notice = false
	_render()

func _keep_message() -> void:
	if _locked or mode != "read" or _notice or phase_ready(): return
	_add("read","endorsement")
	_render()

func _inspect(id: String) -> void:
	if _locked or phase_ready(): return
	var record: bool = mode == "compare" and state.read.has("endorsement") and id in ["crop","original"]
	var reply: bool = mode == "meaning" and state.flags.has("endorsement") and id == "clarification"
	if not record and not reply: return
	_detail = id
	_response = ""
	_add("sorted",id)
	_render()
	(_content.get_parent() as ScrollContainer).scroll_vertical = 0

func _answer(choice: String) -> void:
	if _locked or phase_ready(): return
	var field: String
	var correct: bool
	var explanation: String
	match mode:
		"compare":
			if not state.read.has("endorsement") or not _seen_records(): return
			field = "flags"
			correct = choice == "context"
			explanation = "Amani's name is still on the crop. The missing photo and question explain what she tried."
		"meaning":
			if not state.flags.has("endorsement") or not state.sorted.has("clarification"): return
			field = "domains"
			correct = choice == "banner"
			explanation = "Amani followed the banner's arrow from the gate. Her words were taken from that conversation."
		"warn":
			if not state.domains.has("endorsement"): return
			field = "captures"
			correct = choice == "safe"
			explanation = "Amani's words were reused out of context. That does not show she sent the offer." if choice == "accuse" else "Explain the offer and point to the pinned folder. Forwarding the package could spread the risk."
		_: return
	if not correct:
		state.mistakes += 1
		evidence_changed.emit(state.duplicate(true))
		show_feedback(explanation)
		return
	_response = ""
	_add(field,"endorsement")
	AudioManager.play_sfx("ui_confirm")
	_render()
	(_content.get_parent() as ScrollContainer).scroll_vertical = 0

func show_feedback(text: String) -> void:
	_response = text
	_render()
	var last: Control = _content.get_child(-1) as Control
	var scroll: ScrollContainer = _content.get_parent() as ScrollContainer
	(func() -> void:
		if is_instance_valid(scroll) and is_instance_valid(last) and scroll.is_ancestor_of(last): scroll.ensure_control_visible(last)
	).call_deferred()

func _refresh() -> void:
	super._refresh()
	_title.text = "Phone / The missing context"
	_status.text = "Late morning"
	_status.visible = mode == "read"
	_nav.visible = phase_ready()
	_close.text = "CONTINUE →"
	_close.disabled = _locked or not phase_ready()

func phase_ready() -> bool:
	if mode == "read": return state.get("read",[]).has("endorsement")
	var task: Dictionary = Chapter.TASKS.get(mode,{})
	return not task.is_empty() and state.get(task.field,[]).has("endorsement")

func _close_app() -> void:
	_finish_phase()
