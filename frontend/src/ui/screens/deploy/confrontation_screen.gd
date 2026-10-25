extends BaseScreen
## Mobile hearing controller. Widgets emit intent; only this owner mutates a run.
const Case: GDScript = preload("res://src/gameplay/decision/confrontation_chapter.gd")
const Perks: GDScript = preload("res://src/gameplay/decision/story_perks.gd")
const W: GDScript = preload("res://src/ui/screens/deploy/confrontation_widgets.gd")
const UI: GDScript = preload("res://src/ui/screens/intel/study_ui.gd")
var state: Dictionary = {}
var _testing: bool = false
var _replay: bool = false
var _active: bool = false
var _backgrounded: bool = false
var _owner: String = ""
var _signed: bool = false
var _u: float = 1.0
var _safe: SafeAreaContainer
var _layout: VBoxContainer
var _body: Control
var _overlay: Control
var _shade: ColorRect
var _stage: Control
var _title: Label
var _credit: Label
var _bar: ProgressBar
var _elapsed: float = 0.0
var _voice: int = 0
var _held: bool = false
var _armed: String = ""
var _impact: bool = false
var _rebuild_pending: bool = false
var _dialogue: Label
var _letters: float = 0.0
var _dialogue_next: Callable
var _dialogue_text: String = ""
var _dialogue_lines: PackedStringArray = []
var _dialogue_line: int = 0
var _cinematic_art: TextureRect
var _rebuttal_fx: W.RebuttalImpact
var _chat_text: RichTextLabel
var _chat_status: Label
var _chat_match: Button
var _result_audio: AudioStreamPlayer
var _suspect_selected: String = ""
var _round_intro: float = 0.0
var _reflecting: bool = false
var _counter_sound: bool = false
var _connecting: bool = false
var _arrival_cue: int = -1

func _ready() -> void:
	var background: ColorRect = ColorRect.new()
	background.color = W.BG
	background.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	background.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(background)
	_safe = SafeAreaContainer.new()
	_safe.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(_safe)
	get_viewport().size_changed.connect(_queue_build)
	AssetManager.sync_finished.connect(_art_ready)
	AuthService.session_changed.connect(_session_changed)
	_result_audio = AudioStreamPlayer.new()
	_result_audio.bus = &"Master"
	_result_audio.stream = preload("res://assets/audio/bgm/chapter_complete.wav")
	add_child(_result_audio)
	_result_audio.finished.connect(func() -> void: AudioManager.set_story_duck(self,1.0))
	SettingsService.settings_changed.connect(_sync_result_audio)

func on_enter(args: Dictionary) -> void:
	_testing = args.get("test",false) == true
	_replay = args.get("replay",false) == true
	_owner = AuthService.participant_code()
	_signed = AuthService.is_signed_in()
	_active = true
	state = PlayerManager.begin_story_attempt(Case.ID,_replay,not _testing)
	AudioManager.set_opening_morning(self,false)
	show()
	_build()

func _valid() -> bool:
	return _active and not state.is_empty() and _owner == AuthService.participant_code() and _signed == AuthService.is_signed_in()

func _interactive() -> bool:
	return _valid() and not _backgrounded and not is_instance_valid(_overlay)

func _save() -> void:
	if _valid(): PlayerManager.save_story_attempt(state,_replay,not _testing,Case.ID)

func on_exit() -> void:
	_save()
	_active = false
	AudioManager.stop_dialogue_blips(self)
	AudioManager.release_opening_audio(self)
	_result_audio.stop()
	AudioManager.set_story_duck(self,1.0)
	hide()

func on_resume() -> void:
	if _owner != AuthService.participant_code() or _signed != AuthService.is_signed_in(): return
	_active = true
	show()
	AudioManager.set_opening_morning(self,false)
	if not state.is_empty() and state.phase == "prep" and not state.perk_run.is_empty():
		state.perk_run.loadout = PlayerManager.perk_loadout.duplicate()
		_save()
	_build()

func _session_changed(_value: bool) -> void:
	if _owner != AuthService.participant_code() or _signed != AuthService.is_signed_in():
		_active = false
		AudioManager.release_opening_audio(self)
		if is_instance_valid(_result_audio): _result_audio.stop()
		AudioManager.set_story_duck(self,1.0)
		hide()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_APPLICATION_FOCUS_OUT]:
		_backgrounded = true
		_save()
		AudioManager.pause_opening_audio(self,true)
	elif what in [NOTIFICATION_APPLICATION_RESUMED,NOTIFICATION_APPLICATION_FOCUS_IN]:
		_backgrounded = false
		AudioManager.pause_opening_audio(self,is_instance_valid(_overlay) or _held)
	if is_instance_valid(_result_audio): _sync_result_audio()

func _sync_result_audio() -> void:
	if not is_instance_valid(_result_audio): return
	_result_audio.stream_paused = _backgrounded or is_instance_valid(_overlay) or not _active
	_result_audio.volume_linear = SettingsService.music_volume/100.0*.65 if SettingsService.music_enabled else 0.0
	if not SettingsService.music_enabled:
		_result_audio.stop()
		AudioManager.set_story_duck(self,1.0)

func _art_ready(_success: bool) -> void:
	_queue_build()

func _queue_build() -> void:
	if _active and not _rebuild_pending:
		_rebuild_pending = true
		_build.call_deferred()

func _build() -> void:
	_rebuild_pending = false
	if not _active: return
	_u = W.unit(self)
	_safe.extra_margin = ceili(10*_u)
	_close_overlay()
	UI.clear(_safe)
	_dialogue = null
	_cinematic_art = null
	_rebuttal_fx = null
	_chat_text = null
	_stage = null
	_layout = UI.column(_safe,ceili(8*_u))
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation",ceili(10*_u))
	_layout.add_child(header)
	header.add_child(W.button("BACK",_menu,_u))
	_title = W.copy("CHAPTER 05 / CONFRONTATION",_u,W.CYAN,16)
	_title.size_flags_horizontal = SIZE_EXPAND_FILL
	header.add_child(_title)
	var credibility: VBoxContainer = UI.column(header,2)
	credibility.custom_minimum_size.x = 126*_u
	_credit = W.copy("",_u,W.CREAM,16)
	credibility.add_child(_credit)
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.custom_minimum_size.y = 6*_u
	_bar.add_theme_stylebox_override("background",UI.box(W.CARD,W.CARD,0))
	_bar.add_theme_stylebox_override("fill",UI.box(W.GREEN,W.GREEN,0))
	credibility.add_child(_bar)
	if not state.is_empty() and state.phase in ["debate","final","comic"] and not state.perk_run.get("loadout",[]).is_empty():
		header.add_child(W.button("PERKS",_perk_menu,_u))
	header.add_child(W.button("MENU",_menu,_u))
	_body = Control.new()
	_body.size_flags_vertical = SIZE_EXPAND_FILL
	_layout.add_child(_body)
	if state.is_empty():
		var locked: VBoxContainer = _column()
		locked.add_child(W.copy("Seal Chapters 1–4 to open this hearing.",_u))
		locked.add_child(W.button("CHAPTER SELECT",_leave,_u,true))
		return
	_credit.text = "CREDIBILITY / %d" % int(state.credibility)
	_bar.value = int(state.credibility)
	AudioManager.set_hearing_decision(self,state.phase == "suspect",state.phase in ["debate","rebuttal"])
	match str(state.phase):
		"prep": _prep()
		"suspect": _suspects()
		"intro": _intro()
		"debate": _debate()
		"rebuttal": _rebuttal()
		"final": _final_blow()
		"admission": _story(Case.ADMISSION[int(state.admission_step)],_next_admission,"story_bg_john_bed_night")
		"comic": _comic()
		"animatic": _animatic()
		"aftermath": _story(Case.AFTERMATH[int(state.aftermath_step)],_next_aftermath,"opening_collector_meeting_v2")
		"lights": _lights()
		"done": _results()

func _column() -> VBoxContainer:
	var column: VBoxContainer = UI.column(_body,ceili(8*_u))
	column.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	return column

func _prep() -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	row.add_theme_constant_override("separation",ceili(16*_u))
	_body.add_child(row)
	var visual: VBoxContainer = UI.column(row,ceili(8*_u))
	visual.size_flags_horizontal = SIZE_EXPAND_FILL
	visual.add_child(W.copy("THE HEARING",_u,W.CREAM,28))
	var art: TextureRect = _hearing_art()
	art.size_flags_vertical = SIZE_EXPAND_FILL
	visual.add_child(art)
	var action_area: VBoxContainer = UI.column(row,ceili(8*_u))
	action_area.size_flags_horizontal = SIZE_EXPAND_FILL
	var actions: VBoxContainer = UI.scroll_column(action_area)
	actions.add_theme_constant_override("separation",ceili(8*_u))
	actions.add_child(_large_action("NEW EXHIBITS"+ (" / READ" if state.briefed else ""),_briefing))
	actions.add_child(_large_action("REVIEW CASE RECORD",_evidence.bind(true,false)))
	var loadout: Array = state.perk_run.get("loadout",[])
	actions.add_child(_large_action("SET PERKS / %d OF 2" % loadout.size(),_set_perks))
	var begin: Button = _large_action("FINISH PREPARATIONS",_begin,true)
	begin.disabled = not state.briefed
	if begin.disabled: begin.text = "READ EXHIBITS FIRST"
	action_area.add_child(begin)
	begin.tooltip_text = "Read the new exhibits before joining." if not state.briefed else "Enter the hearing"

func _large_action(text: String, action: Callable, primary: bool = false) -> Button:
	var button: Button = W.button(text,action,_u,primary)
	button.custom_minimum_size.y = 64*_u
	button.add_theme_font_size_override("font_size",ceili(21*_u))
	return button

func _hearing_art() -> TextureRect:
	var art: TextureRect = W.art("hearing_mystery_v1",40*_u)
	return art

func _set_perks() -> void:
	if _interactive() and state.phase == "prep" and not _testing:
		Router.push(&"upgrades",{})

func _briefing() -> void:
	if not _interactive(): return
	var content: VBoxContainer = _modal("SIR RHAM / NEW EXHIBITS")
	var scroll: VBoxContainer = UI.scroll_column(content)
	scroll.add_child(W.copy(Case.BRIEFING,_u))
	content.add_child(W.button("ADD EXHIBITS TO CASE RECORD",_ack_briefing,_u,true))

func _ack_briefing() -> void:
	if not _valid() or _backgrounded or state.phase != "prep": return
	state.briefed = true
	_save()
	_build()

func _begin() -> void:
	if not _interactive() or state.phase != "prep" or not state.briefed: return
	_change("suspect")

func _suspects() -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	row.add_theme_constant_override("separation",ceili(18*_u))
	_body.add_child(row)
	var visual: VBoxContainer = UI.column(row,ceili(8*_u))
	visual.size_flags_horizontal = SIZE_EXPAND_FILL
	visual.size_flags_stretch_ratio = .32
	visual.add_child(W.copy("WHO IS BEHIND IT?",_u,W.CREAM,26))
	var art: TextureRect = _hearing_art()
	art.size_flags_vertical = SIZE_EXPAND_FILL
	visual.add_child(art)
	visual.add_child(W.copy("FOUR NAMES. ONE THEORY.",_u,W.CYAN,16))
	var column: VBoxContainer = UI.column(row,ceili(10*_u))
	column.size_flags_horizontal = SIZE_EXPAND_FILL
	column.size_flags_stretch_ratio = .68
	var scroll: VBoxContainer = UI.scroll_column(column)
	scroll.add_theme_constant_override("separation",ceili(6*_u))
	scroll.add_child(W.copy("CHOOSE WHO TO QUESTION",_u,W.CYAN,23))
	scroll.add_child(W.copy("Trust your evidence. A theory is not a verdict.",_u,W.CREAM,17))
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation",ceili(12*_u))
	grid.add_theme_constant_override("v_separation",ceili(8*_u))
	scroll.add_child(grid)
	for person: String in Case.SUSPECTS:
		var selected: bool = _suspect_selected == person
		var index: int = Case.SUSPECTS.find(person)+1
		var caption: String = "SELECTED" if selected else "TAP TO SELECT"
		if state.suspect_guesses.has(person): caption = "RECONSIDERED"
		var choice: Button = W.button("%02d / %s\n%s" % [index,person.to_upper(),caption],_select_suspect.bind(person),_u)
		choice.name = "Suspect_"+person
		choice.custom_minimum_size.y = 64*_u
		choice.add_theme_font_size_override("font_size",ceili(19*_u))
		choice.alignment = HORIZONTAL_ALIGNMENT_LEFT
		choice.add_theme_stylebox_override("normal",UI.box(Color("153b37") if selected else W.CARD,W.CYAN if selected else W.BORDER,ceili(12*_u)))
		choice.size_flags_horizontal = SIZE_EXPAND_FILL
		choice.disabled = state.theory_done or state.suspect_guesses.has(person)
		grid.add_child(choice)
	if not state.suspect_guesses.is_empty(): scroll.add_child(W.copy(Case.NAME_HINTS[mini(2,state.suspect_guesses.size()-1)],_u,W.ORANGE))
	if state.theory_done:
		scroll.add_child(W.copy("THEORY BONUS / +15 CREDIBILITY" if state.theory_bonus else "JOINING / 20 CREDIBILITY",_u,W.GREEN if state.theory_bonus else W.CREAM))
		column.add_child(_large_action("JOIN HEARING",_join,true))
	else:
		var confirm: Button = _large_action("QUESTION " + _suspect_selected.to_upper() if not _suspect_selected.is_empty() else "SELECT A SUSPECT",_pick_suspect.bind(_suspect_selected),true)
		confirm.name = "ConfirmSuspect"
		confirm.disabled = _suspect_selected.is_empty()
		column.add_child(confirm)

func _select_suspect(person: String) -> void:
	if not _interactive() or state.phase != "suspect" or state.theory_done or state.suspect_guesses.has(person): return
	_suspect_selected = person
	AudioManager.play_sfx("ui_click")
	_build()

func _pick_suspect(person: String) -> void:
	if not _interactive() or state.phase != "suspect" or state.theory_done or person not in Case.SUSPECTS or state.suspect_guesses.has(person): return
	_suspect_selected = ""
	if person == "Jobert":
		state.theory_done = true
		state.theory_bonus = true
		state.credibility = 35
	else:
		state.suspect_guesses.append(person)
		_mark_hint()
		if state.suspect_guesses.size() == 3: state.theory_done = true
	state.round_start = state.credibility
	_save()
	_build()

func _join() -> void:
	if _interactive() and state.phase == "suspect" and state.theory_done:
		_elapsed = 0
		_impact = false
		_connecting = false
		_arrival_cue = -1
		_change("intro")
		AudioManager.play_sfx("ui_notification")

func _intro() -> void:
	var column: VBoxContainer = _column()
	var title: W.JoiningImpact = W.JoiningImpact.new()
	title.size_flags_vertical = SIZE_EXPAND_FILL
	title.gentle = SettingsService.reduced_motion
	title.elapsed = _elapsed
	title.connecting = _connecting
	column.add_child(title)
	_stage = title
	if not _connecting:
		var join_link: Button = _large_action("OPEN ZOOM LINK",_connect_hearing,true)
		join_link.name = "OpenHearingLink"
		column.add_child(join_link)

func _connect_hearing() -> void:
	if not _interactive() or state.phase != "intro" or _connecting: return
	_connecting = true
	_elapsed = 0
	_impact = false
	_arrival_cue = -1
	AudioManager.play_opening_cue("meeting",self)
	_build()

func _start_round() -> void:
	if not _interactive() or state.phase not in ["intro","rebuttal"]: return
	if state.phase == "intro" and (not _connecting or _elapsed < W.JoiningImpact.FINISH_AT): return
	if state.phase == "rebuttal" and _elapsed < 2.2: return
	if state.solved.size() == 4:
		_change("final")
		return
	state.round = state.solved.size()
	state.round_start = maxi(20,int(state.credibility))
	_voice = 0
	_elapsed = 0
	_held = false
	_armed = ""
	_reflecting = false
	_round_intro = 2.4
	_change("debate")
	AudioManager.play_sfx("debate_start")

func _debate() -> void:
	var column: VBoxContainer = _column()
	var stage: W.DebateStage = W.DebateStage.new()
	stage.round_index = int(state.round)
	stage.size_flags_vertical = SIZE_EXPAND_FILL
	column.add_child(stage)
	stage.build(_u)
	stage.rebuttal_submitted.connect(_fire)
	stage.evidence_requested.connect(_evidence.bind(false,false))
	stage.hold_requested.connect(_toggle_hold)
	stage.reflection_finished.connect(_repeat_discussion)
	_stage = stage
	_update_statement()
	stage.animate(0,_round_intro)

func _update_statement() -> void:
	if not _stage is W.DebateStage: return
	_stage.reflecting = _reflecting
	if _reflecting:
		_stage.show_statement("John","Something doesn't fit. I should compare that claim with the evidence.","",_armed,_held)
		return
	var round_data: Dictionary = Case.ROUNDS[int(state.round)]
	var speaker: String = "Jobert" if _voice == 3 else str(round_data.voices[_voice].who)
	var text: String = str(round_data.claim) if _voice == 3 else str(round_data.voices[_voice].text)
	_stage.show_statement(speaker,text,str(round_data.weak) if _voice == 3 else "",_armed,_held)
	AudioManager.play_dialogue_reaction(speaker,"neutral",self)

func _repeat_discussion() -> void:
	if not _interactive() or state.phase != "debate" or not _reflecting or _held: return
	_reflecting = false
	_voice = 0
	_elapsed = 0
	_update_statement()

func _toggle_hold() -> void:
	if not _interactive() or state.phase != "debate": return
	_held = not _held
	AudioManager.pause_opening_audio(self,_held)
	_update_statement()

func _fire(evidence: String, weak_point: String) -> void:
	if not _interactive() or state.phase != "debate" or _voice != 3 or _held or _reflecting or _round_intro > 0: return
	var index: int = int(state.round)
	var round_data: Dictionary = Case.ROUNDS[index]
	if weak_point != round_data.weak: return
	if evidence.is_empty():
		_evidence(false,false)
		return
	if evidence not in round_data.options or state.solved.has(index): return
	if evidence == round_data.correct:
		state.solved.append(index)
		state.credibility = mini(100,int(state.credibility)+15)
		_counter_sound = false
		AudioManager.play_sfx("debate_hit")
		AudioManager.set_story_duck(self,.2)
		_change("rebuttal")
	else:
		state.credibility = maxi(0,int(state.credibility)-10)
		state.mistakes += 1
		state.round_errors[index] += 1
		if state.round_errors[index] >= 2 and not state.auto_hints.has(index):
			state.auto_hints.append(index)
			_mark_hint()
		_save()
		_build()
		AudioManager.play_sfx("ui_error")
		var content: VBoxContainer = _modal("CREDIBILITY −10" if state.credibility > 0 else "REGROUP / ROUND RESTART")
		var scroll: VBoxContainer = UI.scroll_column(content)
		scroll.add_child(W.copy("Jobert: "+str(round_data.smug),_u,W.ORANGE,21))
		scroll.add_child(W.copy(str(Case.exhibit(evidence).detail),_u))
		if state.auto_hints.has(index): scroll.add_child(W.copy("HINT / "+str(round_data.hint)+" The matching record is highlighted.",_u,W.CYAN))
		content.add_child(W.button("RESTART THIS ROUND" if state.credibility == 0 else "TRY ANOTHER RECORD",_retry,_u,true))

func _retry() -> void:
	if not _valid() or _backgrounded or state.phase != "debate": return
	if state.credibility == 0:
		state.credibility = maxi(20,int(state.round_start))
		state.restarts += 1
	_voice = 3
	_elapsed = 0
	_armed = ""
	_reflecting = false
	_round_intro = 0
	_save()
	_build()

func _rebuttal() -> void:
	var round_data: Dictionary = Case.ROUNDS[int(state.round)]
	_story("CLAIM REFUTED / +15\n"+str(round_data.result)+"\nFLASHBACK / "+str(round_data.flash),_start_round,str(round_data.art),true)
	if _elapsed < 2.2:
		(_body.get_child(0) as Control).hide()
		_rebuttal_fx = W.RebuttalImpact.new()
		_rebuttal_fx.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		_rebuttal_fx.gentle = SettingsService.reduced_motion
		_rebuttal_fx.phrase = str(round_data.weak)
		_rebuttal_fx.evidence = str(Case.exhibit(str(round_data.correct)).title)
		_rebuttal_fx.elapsed = _elapsed
		_rebuttal_fx.mouse_filter = MOUSE_FILTER_STOP
		_body.add_child(_rebuttal_fx)

func _final_blow() -> void:
	var column: VBoxContainer = _column()
	column.add_child(W.copy("MEETING CHAT / JOBERT",_u,W.CYAN,22))
	var scroll: VBoxContainer = UI.scroll_column(column)
	_chat_status = W.copy("Jobert is typing...",_u,W.CYAN,16)
	scroll.add_child(_chat_status)
	_chat_text = RichTextLabel.new()
	_chat_text.bbcode_enabled = true
	_chat_text.fit_content = true
	_chat_text.scroll_active = false
	_chat_text.add_theme_font_override("normal_font",UI.FONT)
	_chat_text.add_theme_font_size_override("normal_font_size",ceili(25*_u))
	_chat_text.text = "I didn't [color=#FFB648]recieve[/color] anything from those messages. You can't blame me for helping."
	scroll.add_child(_chat_text)
	for id: String in ["typo1","typo4"]:
		var item: Dictionary = Case.exhibit(id)
		scroll.add_child(W.copy(str(item.source)+"\n"+str(item.detail),_u,W.CYAN))
	_chat_match = W.button("MATCH ‘RECIEVE’ / CH1 + CH4",_match_typo,_u,true)
	column.add_child(_chat_match)
	_update_final_chat()

func _update_final_chat() -> void:
	if not is_instance_valid(_chat_text): return
	var letters: int = int(_elapsed*35)
	var finished: bool = SettingsService.text_speed == "instant" or letters >= _chat_text.get_total_character_count()
	_chat_text.visible_characters = -1 if finished else letters
	_chat_status.text = "CONVERSATION FROZEN / That spelling appeared before." if finished else "Jobert is typing..."
	_chat_match.text = "MATCH ‘RECIEVE’ / CH1 + CH4" if finished else "REVEAL MESSAGE"

func _match_typo() -> void:
	if not _interactive() or state.phase != "final" or state.solved.size() != 4 or state.final_matched: return
	if is_instance_valid(_chat_text) and _chat_text.visible_characters >= 0:
		_elapsed = 4.0
		_update_final_chat()
		return
	state.final_matched = true
	state.credibility = mini(100,int(state.credibility)+20)
	AudioManager.play_sfx("ui_success")
	_change("admission")

func _story(text: String, next: Callable, artwork: String, gray: bool = false) -> void:
	var column: VBoxContainer = _column()
	_cinematic_art = W.art(artwork,32*_u)
	_cinematic_art.size_flags_vertical = SIZE_EXPAND_FILL
	column.add_child(_cinematic_art)
	if gray: W.grayscale(_cinematic_art)
	var scroll: VBoxContainer = UI.scroll_column(column)
	(scroll.get_parent() as Control).size_flags_stretch_ratio = .65
	_dialogue = W.copy("",_u,W.CREAM,21)
	scroll.add_child(_dialogue)
	_dialogue_next = next
	if _dialogue_text != text:
		_dialogue_text = text
		_dialogue_lines = _sentences(text)
		_dialogue_line = 0
		_letters = 0
	_set_line()
	column.add_child(W.button("REVEAL / CONTINUE",_advance_dialogue,_u,true))

func _sentences(text: String) -> PackedStringArray:
	var result: PackedStringArray = []
	var boundary: RegEx = RegEx.new()
	boundary.compile("(?<=[.!?])\\s+(?=[A-Z])")
	for line: String in text.split("\n",false):
		var speaker: String = line.get_slice(": ",0)+": " if line.contains(": ") else ""
		var start: int = 0
		for found: RegExMatch in boundary.search_all(line):
			result.append((speaker if start > 0 else "")+line.substr(start,found.get_start()-start))
			start = found.get_end()
		result.append((speaker if start > 0 else "")+line.substr(start))
	return result

func _set_line() -> void:
	if not is_instance_valid(_dialogue): return
	_dialogue.text = _dialogue_lines[_dialogue_line]
	_dialogue.visible_characters = -1 if SettingsService.text_speed == "instant" else int(_letters)

func _advance_dialogue() -> void:
	if not _interactive() or not is_instance_valid(_dialogue): return
	if _dialogue.visible_characters >= 0 and _dialogue.visible_characters < _dialogue.text.length():
		_letters = _dialogue.text.length()
		_dialogue.visible_characters = -1
	elif _dialogue_line+1 < _dialogue_lines.size():
		_dialogue_line += 1
		_letters = 0
		_set_line()
	else:
		_dialogue_next.call()

func _next_admission() -> void:
	if not _interactive() or state.phase != "admission": return
	if state.admission_step < Case.ADMISSION.size()-1:
		state.admission_step += 1
		_save()
		_build()
	else:
		state.admitted = true
		_change("comic")

func _comic() -> void:
	var comic: W.ClosingArgument = W.ClosingArgument.new()
	comic.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_body.add_child(comic)
	comic.build(state.comic_order,_u)
	comic.frame_placed.connect(_place_frame)
	comic.check_requested.connect(_check_comic)
	_stage = comic

func _place_frame(id: String, slot: int) -> void:
	if not _interactive() or state.phase != "comic" or slot < 0 or slot >= 6 or Case.frame(id).is_empty(): return
	var previous: int = state.comic_order.find(id)
	if previous >= 0: state.comic_order[previous] = state.comic_order[slot]
	state.comic_order[slot] = id
	_save()
	if _stage is W.ClosingArgument:
		_stage.order = state.comic_order.duplicate()
		_stage._draw_slots()

func _check_comic() -> void:
	if not _interactive() or state.phase != "comic": return
	if state.comic_order == Case.COMIC_ORDER:
		state.comic_checked = true
		_save()
		var content: VBoxContainer = _modal("RECONSTRUCTION COMPLETE")
		content.add_child(W.copy("Six moments. One account supported by the records and admission.",_u,W.GREEN,24))
		content.add_child(W.button("PLAY CLOSING ARGUMENT",_play_animatic,_u,true))
	else:
		state.comic_errors += 1
		state.mistakes += 1
		_save()
		_message("REVIEW THE SEQUENCE","Begin with the survey, follow John's growing trust, then the prize, the hearing and the admission. A joke or a borrowing request is not proof.")

func _play_animatic() -> void:
	if not _valid() or _backgrounded or not state.comic_checked or state.phase != "comic": return
	_close_overlay()
	_change("animatic")

func _animatic() -> void:
	var frame: Dictionary = Case.frame(Case.COMIC_ORDER[int(state.animatic_step)])
	_story(str(frame.narration),_next_panel,str(frame.art),int(state.animatic_step)<4)
	_title.text = "CLOSING ARGUMENT / %d OF 6" % (int(state.animatic_step)+1)

func _next_panel() -> void:
	if not _interactive() or state.phase != "animatic": return
	if state.animatic_step < 5:
		state.animatic_step += 1
		_elapsed = 0
		_save()
		_build()
	else:
		state.animatic_done = true
		_change("aftermath")

func _next_aftermath() -> void:
	if not _interactive() or state.phase != "aftermath": return
	if state.aftermath_step < Case.AFTERMATH.size()-1:
		state.aftermath_step += 1
		if state.aftermath_step == 2: AudioManager.play_sfx("ui_notification")
		_save()
		_build()
	else:
		state.aftermath_done = true
		_elapsed = 0
		_change("lights")
		AudioManager.play_opening_score("closing",self)

func _lights() -> void:
	var column: VBoxContainer = _column()
	var image: W.MeetingLights = W.MeetingLights.new()
	image.gentle = SettingsService.reduced_motion
	image.elapsed = _elapsed
	image.size_flags_vertical = SIZE_EXPAND_FILL
	column.add_child(image)
	_stage = image
	column.add_child(W.copy("Four lights. One connection closes.",_u))
	var finish: Button = W.button("SEAL THE FINAL EXHIBIT",_finish,_u,true)
	finish.name = "FinishHearing"
	finish.disabled = _elapsed < 3.0
	column.add_child(finish)

func _finish() -> void:
	if not _interactive() or state.phase != "lights" or _elapsed < 3.0: return
	state.lights_done = true
	state.completed = true
	state = Case.clean(state)
	_save()
	_elapsed = 0
	AudioManager.stop_dialogue_blips(self)
	AudioManager.play_sfx("ui_success")
	_build()
	if SettingsService.music_enabled and SettingsService.music_volume > 0:
		_sync_result_audio()
		AudioManager.set_story_duck(self,.22)
		_result_audio.play()

func _results() -> void:
	_title.text = "CASE CLOSED"
	var column: VBoxContainer = _column()
	var scroll: VBoxContainer = UI.scroll_column(column)
	scroll.add_child(W.copy("MODULE 01 / EXHIBIT SEALED",_u,W.GREEN,22))
	var heading: Label = W.copy("CONFRONTATION COMPLETE",_u,W.CREAM,30)
	heading.name = "CompletionHeading"
	scroll.add_child(heading)
	var reward: W.RewardDisplay = W.RewardDisplay.new()
	reward.u = _u
	reward.award = 0 if _replay else int(state.reward)
	reward.balance = PlayerManager.credits
	reward.gentle = SettingsService.reduced_motion
	reward.elapsed = _elapsed
	reward.custom_minimum_size.y = 100*_u
	scroll.add_child(reward)
	_stage = reward
	scroll.add_child(W.copy("Replay / original rewards retained" if _replay else "100 completion + %d clean-work bonus" % maxi(0,int(state.reward)-100),_u))
	scroll.add_child(W.copy("%s clear / Final exhibit saved" % Perks.status(state.perk_run,state.hint_used).capitalize(),_u,W.CYAN))
	var actions: HBoxContainer = HBoxContainer.new()
	actions.add_theme_constant_override("separation",ceili(10*_u))
	column.add_child(actions)
	var chapters: Button = W.button("CHAPTER SELECT",_leave,_u,true)
	chapters.size_flags_horizontal = SIZE_EXPAND_FILL
	actions.add_child(chapters)
	var perks: Button = W.button("PERKS",func() -> void: Router.push(&"upgrades",{}),_u)
	perks.size_flags_horizontal = SIZE_EXPAND_FILL
	actions.add_child(perks)

func _perk_menu() -> void:
	if not _interactive(): return
	var content: VBoxContainer = _modal("EQUIPPED PERKS")
	content.add_child(W.copy("Using a perk records this attempt as assisted.",_u,W.CREAM,16))
	var row: VBoxContainer = UI.scroll_column(content)
	for id: String in state.perk_run.get("loadout",[]):
		var button: Button = W.button(str(Perks.DATA[id].name),_choose_perk.bind(id),_u)
		button.size_flags_horizontal = SIZE_EXPAND_FILL
		button.disabled = not Perks.allowed(state.perk_run,id,"story_chapter",state.phase,state.captures)
		row.add_child(button)
	content.add_child(W.button("CLOSE",_close_overlay,_u))

func _choose_perk(id: String) -> void:
	if not _valid() or _backgrounded: return
	_close_overlay()
	_use_perk(id)

func _use_perk(id: String) -> void:
	if not _interactive() or not Perks.activate(state.perk_run,id,"story_chapter",state.phase,int(state.round),state.captures): return
	_save()
	_build()
	if id == "reference": _evidence(true,true)
	elif id == "perspective": _message("FRESH PERSPECTIVE",str(Case.ROUNDS[int(state.round)].hint) if state.phase == "debate" else "Separate the order of events from guesses about people. The admission belongs after the hearing.")
	else: _message("CASE RECAP","A survey offered money. A copied advisor asked for details. A wallet link hid its destination. A prize reused John's coffee comment. Group access, presence status and repeated spelling do not identify an author by themselves.")

func _mark_hint() -> void:
	state.hint_used = true
	if not state.perk_run.is_empty():
		state.perk_run.builtin_hints += 1
		Perks.record(state.perk_run,"builtin_hint",state.phase,int(state.round))

func _evidence(review: bool = false, comparison: bool = false) -> void:
	if not _interactive(): return
	var options: Array = []
	if review:
		for item: Dictionary in Case.EXHIBITS: options.append(item.id)
	else: options = Case.ROUNDS[int(state.round)].options
	var hint: String = str(Case.ROUNDS[int(state.round)].correct) if state.auto_hints.has(int(state.round)) and not review else ""
	_modal("")
	var drawer: W.EvidenceDrawer = W.EvidenceDrawer.new()
	drawer.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_overlay.add_child(drawer)
	drawer.build(options,_u,hint,review,comparison)
	drawer.closed.connect(_close_overlay)
	drawer.evidence_selected.connect(_arm)

func _arm(id: String) -> void:
	if not _valid() or _backgrounded or state.phase != "debate" or id not in Case.ROUNDS[int(state.round)].options: return
	_armed = id
	_close_overlay()
	_update_statement()

func _modal(title: String, compact: bool = false) -> VBoxContainer:
	_close_overlay()
	AudioManager.pause_opening_audio(self,true)
	_shade = ColorRect.new()
	_shade.color = Color(0,0,0,.78)
	_shade.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(_shade)
	_overlay = PanelContainer.new()
	_overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_overlay.offset_left = 20*_u
	_overlay.offset_right = -20*_u
	_overlay.offset_top = 18*_u
	_overlay.offset_bottom = -18*_u
	# A freshly rebuilt layout has not been sized yet. Use stable safe-area insets.
	if is_instance_valid(_safe):
		_overlay.offset_left = maxf(_overlay.offset_left,_safe.get_theme_constant("margin_left"))
		_overlay.offset_right = -maxf(-_overlay.offset_right,_safe.get_theme_constant("margin_right"))
		_overlay.offset_top = maxf(_overlay.offset_top,_safe.get_theme_constant("margin_top"))
		_overlay.offset_bottom = -maxf(-_overlay.offset_bottom,_safe.get_theme_constant("margin_bottom"))
	if compact:
		_overlay.set_anchors_and_offsets_preset(PRESET_CENTER)
		var dimensions: Vector2 = Vector2(minf(440*_u,size.x-40*_u),minf(280*_u,size.y-36*_u))
		_overlay.offset_left = -dimensions.x*.5
		_overlay.offset_right = dimensions.x*.5
		_overlay.offset_top = -dimensions.y*.5
		_overlay.offset_bottom = dimensions.y*.5
	_overlay.add_theme_stylebox_override("panel",UI.box(W.PANEL,W.CYAN,ceili(14*_u)))
	add_child(_overlay)
	_sync_result_audio()
	var content: VBoxContainer = UI.column(_overlay,ceili(10*_u))
	if not title.is_empty(): content.add_child(W.copy(title,_u,W.CYAN,22))
	return content

func _close_overlay() -> void:
	if is_instance_valid(_overlay):
		remove_child(_overlay)
		_overlay.queue_free()
	_overlay = null
	if is_instance_valid(_shade):
		remove_child(_shade)
		_shade.queue_free()
	_shade = null
	if _active: AudioManager.pause_opening_audio(self,_held or _backgrounded)
	_sync_result_audio()

func _message(title: String, text: String) -> void:
	var content: VBoxContainer = _modal(title)
	var scroll: VBoxContainer = UI.scroll_column(content)
	scroll.add_child(W.copy(text,_u))
	content.add_child(W.button("CONTINUE",_close_overlay,_u,true))

func _menu() -> void:
	if not _active or _backgrounded: return
	if is_instance_valid(_overlay):
		# Zero credibility cannot be bypassed by closing the feedback sheet.
		if not state.is_empty() and state.phase == "debate" and state.credibility == 0: _retry()
		else: _close_overlay()
		return
	var content: VBoxContainer = _modal("HEARING PAUSED",true)
	content.add_child(W.button("RESUME",_close_overlay,_u,true))
	content.add_child(W.button("SETTINGS",func() -> void: Router.push(&"settings"),_u))
	content.add_child(W.button("SAVE & CHAPTER SELECT",_leave,_u))

func consume_back() -> bool:
	_menu()
	return true

func _leave() -> void:
	if not _active or _backgrounded: return
	_save()
	if not _testing: Router.replace(&"module_stages",{"module_index":0,"chapters":true})

func _change(phase: String) -> void:
	state.phase = phase
	_elapsed = 0
	_dialogue_text = ""
	_save()
	_build()

func _process(delta: float) -> void:
	if not _interactive(): return
	if state.phase == "debate" and _held: return
	_elapsed += delta
	if state.phase == "intro":
		if not _connecting:
			_elapsed = 0
			return
		if _stage is W.JoiningImpact:
			_stage.advance(_elapsed,true,SettingsService.reduced_motion)
		var arrival: int = mini(5,floori((_elapsed-1.8)/.45))
		if arrival >= 0 and arrival > _arrival_cue and _elapsed < 5.2:
			_arrival_cue = arrival
			AudioManager.play_sfx("ui_notification")
		if _elapsed >= W.JoiningImpact.REVEAL_AT and not _impact:
			_impact = true
			AudioManager.play_opening_cue("takeover",self)
		if _elapsed >= W.JoiningImpact.FINISH_AT: _start_round()
	elif state.phase == "debate":
		if _stage is W.DebateStage: _stage.animate(delta,_round_intro)
		if _round_intro > 0:
			_round_intro = maxf(0,_round_intro-delta)
			_elapsed = 0
			return
		if _reflecting or (_armed.is_empty() and _voice == 0):
			_elapsed = 0
			return
		if int(state.credibility) == 0:
			_retry()
			return
		if _elapsed >= (8.0 if _voice == 3 else 4.0):
			_elapsed = 0
			if _voice == 3: _reflecting = true
			else: _voice += 1
			_update_statement()
	elif state.phase == "lights":
		if _stage is W.MeetingLights:
			_stage.elapsed = _elapsed
			_stage.queue_redraw()
		var finish: Button = find_child("FinishHearing",true,false) as Button
		if finish != null: finish.disabled = _elapsed < 3
	elif state.phase == "final": _update_final_chat()
	elif state.phase == "rebuttal" and is_instance_valid(_rebuttal_fx):
		_rebuttal_fx.elapsed = _elapsed
		_rebuttal_fx.queue_redraw()
		if _elapsed >= .55 and not _counter_sound:
			_counter_sound = true
			AudioManager.play_sfx("debate_counter")
		if _elapsed >= 2.2:
			_rebuttal_fx.queue_free()
			_rebuttal_fx = null
			(_body.get_child(0) as Control).show()
			AudioManager.set_story_duck(self,1.0)
		else: return
	elif state.phase == "done":
		if _stage is W.RewardDisplay:
			_stage.elapsed = _elapsed
			_stage.queue_redraw()
		var heading: Label = find_child("CompletionHeading",true,false) as Label
		if heading != null: heading.modulate.a = 1.0 if SettingsService.reduced_motion else smoothstep(0,.7,_elapsed)
	if is_instance_valid(_dialogue) and _dialogue.visible_characters >= 0:
		_letters += delta*32*SettingsService.text_speed_multiplier()
		_dialogue.visible_characters = int(_letters)
		AudioManager.play_dialogue_blip(_dialogue.text.get_slice(":",0),"neutral",int(_letters),self)
		if _letters >= _dialogue.text.length():
			_dialogue.visible_characters = -1
			AudioManager.stop_dialogue_blips(self)
	if state.phase == "animatic" and is_instance_valid(_cinematic_art) and not SettingsService.reduced_motion:
		_cinematic_art.modulate.a = minf(1,.55+_elapsed*1.4)
