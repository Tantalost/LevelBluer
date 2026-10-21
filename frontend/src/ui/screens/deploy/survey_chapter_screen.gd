extends BaseScreen
## Chapter 1 presentation and transitions. Phone reports intents, never saves.
const UI: GDScript = preload("res://src/ui/screens/intel/study_ui.gd")
const Chapter: GDScript = preload("res://src/gameplay/decision/survey_chapter.gd")
const Phone: GDScript = preload("res://src/gameplay/decision/survey_phone.gd")
const Practice: GDScript = preload("res://src/gameplay/decision/tutorial_phone.gd")
var state: Dictionary = {}
var replay: bool = false
var _active: bool = false
var _paused: bool = false
var _backgrounded: bool = false
var _suspended: bool = false
var _sending: bool = false
var _testing: bool = false
var _owner: String = ""
var _signed_owner: bool = false
var _bg: TextureRect
var _portrait: TextureRect
var _area: Control
var _header: HBoxContainer
var _heading: Label
var _phone: Control
var _journal: PanelContainer
var _journal_body: VBoxContainer
var _dialogue: PanelContainer
var _speaker: Label
var _line: RichTextLabel
var _advance_button: Button
var _menu: PanelContainer
var _seal: Practice.SealArt
var _typing: Tween
var _motion: Tween
var _seq: int = 0

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var fallback: ColorRect = ColorRect.new()
	fallback.color = Color("173058")
	fallback.mouse_filter = MOUSE_FILTER_IGNORE
	fallback.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(fallback)
	_bg = TextureRect.new()
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg.mouse_filter = MOUSE_FILTER_IGNORE
	_bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(_bg)
	var safe: SafeAreaContainer = SafeAreaContainer.new()
	safe.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	safe.extra_margin = 14
	add_child(safe)
	_area = Control.new()
	safe.add_child(_area)
	_portrait = TextureRect.new()
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.mouse_filter = MOUSE_FILTER_IGNORE
	_area.add_child(_portrait)
	_phone = Phone.new()
	_area.add_child(_phone)
	_phone.evidence_changed.connect(_evidence_changed)
	_phone.thought_requested.connect(_thought)
	_phone.phase_finished.connect(_phase_finished)
	_journal = UI.panel(_area, Color("0A1730", 0.92))
	_journal_body = UI.scroll_column(_journal)
	_dialogue = UI.panel(_area, Color("050B18", 0.82))
	var box: StyleBoxFlat = UI.box(Color("050B18", 0.82), Color("4FE0D4", 0.5), 16)
	box.set_corner_radius_all(22)
	_dialogue.add_theme_stylebox_override("panel", box)
	var dialogue_body: VBoxContainer = UI.column(_dialogue, 10)
	_speaker = UI.label("John", 24, Color("4FE0D4"))
	_speaker.add_theme_color_override("font_color", Color("101623"))
	var speaker_style: StyleBoxFlat = UI.box(Color("4FE0D4"), Color("4FE0D4"), 8)
	speaker_style.set_corner_radius_all(10)
	_speaker.add_theme_stylebox_override("normal", speaker_style)
	dialogue_body.add_child(_speaker)
	var row: HBoxContainer = HBoxContainer.new()
	dialogue_body.add_child(row)
	row.size_flags_vertical = SIZE_EXPAND_FILL
	_line = RichTextLabel.new()
	_line.add_theme_font_override("normal_font", UI.FONT)
	_line.add_theme_color_override("default_color", Color("F3ECD6"))
	_line.size_flags_horizontal = SIZE_EXPAND_FILL
	_line.size_flags_vertical = SIZE_EXPAND_FILL
	row.add_child(_line)
	_advance_button = _button("›", _advance)
	_advance_button.size_flags_vertical = SIZE_SHRINK_END
	row.add_child(_advance_button)
	_header = HBoxContainer.new()
	_header.add_theme_constant_override("separation", 14)
	_area.add_child(_header)
	_header.add_child(_button("‹ BACK", _leave))
	_heading = UI.label("CHAPTER 1 / THE SURVEY", 22, Color("F3ECD6"))
	_heading.add_theme_color_override("font_outline_color", Color("050B18"))
	_heading.add_theme_constant_override("outline_size", 4)
	_heading.size_flags_horizontal = SIZE_EXPAND_FILL
	_heading.autowrap_mode = TextServer.AUTOWRAP_OFF
	_heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_header.add_child(_heading)
	_header.add_child(_button("MENU", _toggle_menu))
	_menu = UI.panel(_area, Color("0A1730"))
	var menu_body: VBoxContainer = UI.column(_menu)
	menu_body.add_child(UI.label("CHAPTER PAUSED", 26, Color("4FE0D4")))
	menu_body.add_child(_button("RESUME", _toggle_menu))
	menu_body.add_child(_button("SETTINGS", _settings))
	menu_body.add_child(_button("SAVE & RETURN TO MODULES", _leave))
	_menu.hide()
	_area.resized.connect(_layout)
	AssetManager.sync_finished.connect(_art_ready)
	SettingsService.settings_changed.connect(_settings_changed)
	AuthService.session_changed.connect(_session_changed)

func _button(caption: String, callback: Callable) -> Button:
	var button: Button = UI.button(caption, callback)
	var style: StyleBoxFlat = UI.box(Color("0A1730",0.95), Color("4FE0D4"), 12)
	style.set_corner_radius_all(22)
	button.add_theme_stylebox_override("normal", style)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return button

func on_enter(args: Dictionary) -> void:
	_testing = bool(args.get("test", false))
	_owner = AuthService.participant_code()
	_signed_owner = AuthService.is_signed_in()
	replay = bool(args.get("replay", false))
	state = Chapter.fresh() if replay else Chapter.clean(PlayerManager.chapter_progress.get(Chapter.ID, {}))
	_active = true
	_render()

func _render() -> void:
	_seq += 1
	_stop_tweens()
	UI.clear(_journal_body)
	_seal = null
	_phone.stop()
	_phone.hide()
	_journal.hide()
	_portrait.show()
	_dialogue.show()
	_sending = false
	_speaker.text = "John / Thinking"
	var phase: String = str(state["phase"])
	_heading.text = "CHAPTER 1 / " + ("DAY" if phase == "day" else "NIGHT") + (" / REPLAY" if replay else "")
	if phase == "day":
		var beat: Dictionary = Chapter.STORY[int(state["beat"])]
		_speaker.text = str(beat["who"])
		_set_line(str(beat["line"]))
		if bool(beat.get("chat", false)):
			_phone.configure_chapter("chat", state)
		elif bool(beat.get("mail", false)):
			_phone.configure_chapter("read", state)
	elif phase in ["sort", "highlight", "notes", "capture"]:
		_portrait.hide()
		_journal.show()
		var titles: Dictionary = {"sort":"01 / SORT THE INBOX", "highlight":"02 / READ BETWEEN THE LINES", "notes":"03 / TRACE THE SENDERS", "capture":"04 / KEEP THE CONTEXT"}
		_journal_body.add_child(UI.label(str(titles[phase]), 24, Color("4FE0D4")))
		var tips: Dictionary = {"sort":"Open each message. Drag it into a bin, or tap a bin. Looks Fine means no warning sign in this context—not guaranteed safe.", "highlight":"Inspect the three suspicious requests. Tap a passage to mark it; John's thoughts appear outside the phone.", "notes":"Check each sender in Mail. Open Notepad and record the domain. Return to Mail whenever you need to check.", "capture":"Frame each suspicious message with its sender, subject and request. Drag the frame or use the tap controls."}
		_journal_body.add_child(UI.label(str(tips[phase]), 22))
		_journal_body.add_child(UI.label(_evidence_summary(), 22, Color("F3ECD6")))
		_journal_body.get_child(_journal_body.get_child_count() - 1).name = "EvidenceSummary"
		_journal_body.add_child(_button("NEED A HINT?", _hint))
		_phone.configure_chapter(phase, state)
		_set_line({"sort":"Six messages. Which ones deserve another look?", "highlight":"Alright, what in these messages made me hesitate?", "notes":"Alright, what next could be the issue? Who actually sent these?", "capture":"If I need to explain this later, I need the full context—not just a suspicious sentence."}[phase])
	elif phase == "seal":
		_journal.show()
		_journal_body.add_child(UI.label("EXHIBIT 01 / THE SURVEY", 28, Color("4FE0D4")))
		_journal_body.add_child(UI.label("3 evidence bundles\n\n01 · Three message captures\n02 · Sender-domain notes\n03 · Payment, pressure and personal-data clues", 24))
		_journal_body.add_child(UI.label("A typo or free mailbox alone is not proof. Keep each clue connected to the request it came from.", 22))
		for id: String in Chapter.suspicious_ids():
			_journal_body.add_child(_button("REVIEW / " + str(Chapter.message(id)["subject"]), _review_capture.bind(id)))
		_seal = Practice.SealArt.new()
		_journal_body.add_child(_seal)
		_journal_body.add_child(_button("SEAL EXHIBIT", _seal_exhibit))
		_set_line("I still don't know who the client is. But now I have something more useful than a feeling.")
	elif phase == "sleep":
		_set_line("I put my phone down. Eric said he knew the client. Tomorrow, I'll ask him again.\n\nFor now, I need some sleep.")
	else:
		_show_results()
	_load_art()
	_layout()
	if not SettingsService.reduced_motion:
		_motion = create_tween().set_parallel(true)
		for control: Control in [_dialogue, _journal, _portrait, _phone]:
			control.modulate.a = 0.0
			_motion.tween_property(control, "modulate:a", 1.0, 0.22)
	else:
		for control: Control in [_dialogue, _journal, _portrait, _phone]: control.modulate.a = 1.0
	_apply_pause()

func _review_capture(id: String) -> void:
	if not _can_act() or _sending or not state["captures"].has(id): return
	var panel: PanelContainer = _journal_body.get_node_or_null("CaptureReview") as PanelContainer
	if panel != null:
		_journal_body.remove_child(panel)
		panel.queue_free()
	panel = UI.panel(_journal_body, Color("F3ECD6"))
	panel.name = "CaptureReview"
	var contents: VBoxContainer = UI.column(panel, 8)
	var entry: Dictionary = Chapter.message(id)
	contents.add_child(UI.label("SAVED CAPTURE / " + str(entry["address"]), 24, Color("101623")))
	var texture: Texture2D = _phone._previews.get(id)
	if texture != null:
		var photo: TextureRect = TextureRect.new()
		photo.texture = texture
		photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		photo.custom_minimum_size.y = 250
		contents.add_child(photo)
	else:
		contents.add_child(UI.label(str(entry["subject"]) + "\n\n" + str(entry["phrase"]), 24, Color("101623")))
	_layout()
	(_journal_body.get_parent() as ScrollContainer).ensure_control_visible.call_deferred(panel)

func _show_results() -> void:
	_journal.show()
	_portrait.hide()
	_dialogue.hide()
	_heading.text = "CHAPTER 1 / COMPLETE"
	_journal_body.add_child(UI.label("THE SURVEY\nEXHIBIT SEALED", 30, Color("4FE0D4"), true))
	_journal_body.add_child(UI.label("Three evidence bundles saved for the Chapter 5 meeting.", 25))
	var reward: int = int(state["reward"])
	_journal_body.add_child(UI.label("Replay · no additional rewards" if replay else "%d CREDITS EARNED\n%d completion + %d clean-work bonus\nReward recorded · collected once" % [reward, Chapter.BASE_REWARD, reward - Chapter.BASE_REWARD], 26, Color("FFB648")))
	_journal_body.add_child(UI.label("Chapter 2 access earned. Its story is coming in the next milestone.", 22))
	_journal_body.add_child(_button("RETURN TO MODULES", _leave))
	_journal_body.add_child(_button("REPLAY CHAPTER", _replay))

func _evidence_summary() -> String:
	return "Sorted %d/6  ·  Clues %d/3\nDomains %d/3  ·  Captures %d/3" % [state["sorted"].size(),state["flags"].size(),state["domains"].size(),state["captures"].size()]

func _set_line(text: String) -> void:
	if _typing != null and _typing.is_valid(): _typing.kill()
	_line.text = text
	_line.scroll_to_line(0)
	_line.visible_characters = -1
	if SettingsService.text_speed != "instant":
		_line.visible_characters = 0
		_typing = create_tween()
		_typing.tween_property(_line, "visible_characters", text.length(), text.length() / (42.0 * SettingsService.text_speed_multiplier()))
		_typing.finished.connect(_update_advance)
	_update_advance()

func _update_advance() -> void:
	var typed: bool = _line.visible_characters < 0 or _line.visible_characters >= _line.text.length()
	_advance_button.text = "›" if typed else "…"
	_advance_button.disabled = not _can_act() or _sending
	if typed and state.get("phase") in ["sort", "highlight", "notes", "capture", "seal"]:
		_advance_button.visible = false
	else:
		_advance_button.visible = true
	if typed and state.get("phase") == "day" and int(state.get("beat", 0)) == 11:
		_advance_button.disabled = state["read"].size() < 6 or not _can_act()

func _advance() -> void:
	if not _can_act() or _sending:
		return
	if _line.visible_characters >= 0 and _line.visible_characters < _line.text.length():
		if _typing != null and _typing.is_valid(): _typing.kill()
		_line.visible_characters = -1
		_update_advance()
		return
	if state["phase"] == "day":
		if int(state["beat"]) == 11 and state["read"].size() < 6: return
		if int(state["beat"]) < Chapter.STORY.size() - 1:
			state["beat"] = int(state["beat"]) + 1
		else:
			state["phase"] = "sort"
	elif state["phase"] == "sleep":
		state["completed"] = true
		state = Chapter.clean(state)
		AudioManager.play_sfx("ui_confirm")
	else:
		return
	_save()
	_render()

func _evidence_changed(snapshot: Dictionary) -> void:
	if not _can_act(): return
	for field: String in ["read", "sorted", "flags", "domains", "captures", "mistakes"]:
		state[field] = snapshot[field]
	var summary: Label = _journal_body.get_node_or_null("EvidenceSummary") as Label
	if summary != null: summary.text = _evidence_summary()
	_save()
	_update_advance()

func _thought(text: String) -> void:
	if not _can_act(): return
	_speaker.text = "John / Thinking"
	_set_line(text)

func _phase_finished() -> void:
	if not _can_act() or not _phone.phase_ready(): return
	if state["phase"] == "day":
		if _typing != null and _typing.is_valid(): _typing.kill()
		_line.visible_characters = -1
		_advance()
		return
	state["phase"] = {"sort":"highlight", "highlight":"notes", "notes":"capture", "capture":"seal"}.get(str(state["phase"]), "seal")
	_save()
	_render()

func _hint() -> void:
	if not _can_act(): return
	state["hint_used"] = true
	_save()
	if state["phase"] == "capture" and is_instance_valid(_phone._camera):
		_phone._camera.frame = Rect2(0.02,0.02,0.96,0.96)
		_phone._camera._commit()
	_thought({"sort":"The three survey messages deserve a closer look. Compare their demands with the school updates you were expecting.", "highlight":"Look for unspecified pay, pressure not to verify, and unexplained requests for personal details. A typo is only supporting context.", "notes":"Read the address after @. Two survey senders use gmail.com; the coordinator uses yahoo.com. That alone does not prove a scam.", "capture":"Include the entire sender, subject and request. Framing assistance is available when a message is open."}.get(str(state["phase"]), "Keep each clue connected to its context."))

func _seal_exhibit() -> void:
	if not _can_act() or _sending or state["phase"] != "seal" or not Chapter.complete_evidence(state): return
	_sending = true
	_phone.set_locked(true)
	if _motion != null and _motion.is_valid(): _motion.kill()
	var generation: int = _seq
	_motion = create_tween()
	_motion.tween_property(_seal, "progress", 1.0, 0.05 if SettingsService.reduced_motion else 1.4)
	_motion.tween_callback(func() -> void:
		if not _active or generation != _seq: return
		state["sealed"] = true
		state["phase"] = "sleep"
		_save()
		_render())
	_update_advance()

func _save() -> void:
	if not replay and _owner == AuthService.participant_code() and _signed_owner == AuthService.is_signed_in():
		PlayerManager.save_survey_chapter(state, not _testing)

func _replay() -> void:
	if not _can_act(): return
	replay = true
	_phone._previews.clear()
	state = Chapter.fresh()
	_render()

func _load_art() -> void:
	if state.is_empty(): return
	var phase: String = str(state["phase"])
	var beat: Dictionary = Chapter.STORY[int(state["beat"])]
	var location: String = str(beat["bg"]) if phase == "day" else "room"
	_bg.texture = AssetManager.get_texture("opening_john_room_wake_v1" if location == "room" else "story_bg_" + location)
	var person: String = str(beat["who"]).to_lower() if phase == "day" else "john"
	var texture: Texture2D = AssetManager.get_texture("chapter1_" + person)
	_portrait.texture = null
	if texture != null and texture.get_width() == 1536 and texture.get_height() == 1024:
		var face: int = int(beat.get("face",0)) if phase == "day" else 2
		var split: int = {"john":517,"eric":506,"jobert":546}[person]
		var atlas: AtlasTexture = AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2((face % 3) * 512, 0 if face < 3 else split, 512, split if face < 3 else 1024 - split)
		atlas.filter_clip = true
		_portrait.texture = atlas

func _art_ready(_success: bool) -> void:
	_load_art()

func _layout() -> void:
	if not is_instance_valid(_area): return
	var w: float = _area.size.x
	var h: float = _area.size.y
	var physical: float = maxf(0.25, get_viewport().get_final_transform().get_scale().y)
	var touch: float = maxf(48, 48 / physical)
	_header.position = Vector2.ZERO
	_header.size = Vector2(w,touch)
	var has_phone: bool = _phone.visible
	var phase: String = str(state.get("phase", "day"))
	var top: float = touch + 16
	_phone.set_anchors_and_offsets_preset(PRESET_TOP_LEFT)
	_phone.position = Vector2(w * 0.47, top)
	_phone.size = Vector2(w * 0.53, h - top)
	_phone._metrics()
	_portrait.position = Vector2(w * 0.02,top)
	_portrait.size = Vector2(w * (0.43 if has_phone else 0.65), h - top)
	_dialogue.position = Vector2(0,h * 0.64)
	_dialogue.size = Vector2(w * 0.45 if has_phone else w,h * 0.36)
	_journal.position = Vector2(0,top)
	_journal.size = Vector2(w * 0.45, maxf(100,h * 0.61 - top))
	if phase in ["seal", "done"]:
		_journal.position = Vector2(w * 0.12,top)
		_journal.size = Vector2(w * 0.76,h - top - (h * 0.37 if phase == "seal" else 6))
	_menu.position = Vector2(w * 0.2,h * 0.15)
	_menu.size = Vector2(w * 0.6,h * 0.70)
	for node: Node in _area.find_children("*", "Button", true, false):
		var button: Button = node as Button
		button.custom_minimum_size.y = touch
		button.add_theme_font_size_override("font_size", maxi(20, int(16 / physical)))
	for node: Node in _header.get_children():
		if node is Button:
			var button: Button = node as Button
			button.autowrap_mode = TextServer.AUTOWRAP_OFF
			button.custom_minimum_size.x = button.get_theme_font("font").get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, button.get_theme_font_size("font_size")).x + 32
	for node: Node in _journal_body.find_children("*", "Label", true, false):
		(node as Label).add_theme_font_size_override("font_size", maxi(22, int(16 / physical)))
	_line.add_theme_font_size_override("normal_font_size", maxi(24,int(18 / physical)))
	_speaker.add_theme_font_size_override("font_size", maxi(22,int(16 / physical)))
	_heading.add_theme_font_size_override("font_size", maxi(20,int(14 / physical)))
	_advance_button.custom_minimum_size = Vector2.ONE * touch

func _can_act() -> bool:
	return _active and not _paused and not _backgrounded and not _suspended and _owner == AuthService.participant_code() and _signed_owner == AuthService.is_signed_in()

func _toggle_menu() -> void:
	if not _active: return
	_paused = not _paused
	_menu.visible = _paused
	_apply_pause()

func _apply_pause() -> void:
	var locked: bool = not _can_act()
	_phone.set_locked(locked or _sending)
	for tween: Tween in [_typing,_motion]:
		if tween != null and tween.is_valid():
			if locked: tween.pause()
			else: tween.play()
	_update_advance()

func _settings_changed() -> void:
	if SettingsService.text_speed == "instant":
		if _typing != null and _typing.is_valid(): _typing.kill()
		_line.visible_characters = -1
	if SettingsService.reduced_motion and not _sending:
		if _motion != null and _motion.is_valid(): _motion.kill()
		for control: Control in [_dialogue, _journal, _portrait, _phone]: control.modulate.a = 1.0
	_apply_pause()

func _settings() -> void:
	await Router.push(&"settings")

func _leave() -> void:
	if not _active: return
	_save()
	await Router.replace(&"stage_select")

func consume_back() -> bool:
	if _paused:
		_toggle_menu()
	else:
		_leave()
	return true

func _session_changed(_signed_in: bool) -> void:
	if _owner != AuthService.participant_code() or _signed_owner != AuthService.is_signed_in():
		_active = false
		_stop_tweens()
		_phone.stop()
		hide()

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT: _backgrounded = true
		NOTIFICATION_APPLICATION_FOCUS_IN: _backgrounded = false
		NOTIFICATION_APPLICATION_PAUSED: _suspended = true
		NOTIFICATION_APPLICATION_RESUMED: _suspended = false
		_: return
	if is_node_ready(): _apply_pause()

func _stop_tweens() -> void:
	for tween: Tween in [_typing,_motion]:
		if tween != null and tween.is_valid(): tween.kill()
	_typing = null
	_motion = null

func on_exit() -> void:
	_active = false
	_seq += 1
	_stop_tweens()
	_phone.stop()
	hide()

func on_resume() -> void:
	if _owner != AuthService.participant_code() or _signed_owner != AuthService.is_signed_in(): return
	_active = true
	_paused = false
	_menu.hide()
	show()
	_render()

func _exit_tree() -> void:
	_stop_tweens()
