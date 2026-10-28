extends SceneTree
const Case: GDScript = preload("res://src/gameplay/decision/confrontation_chapter.gd")
const Survey: GDScript = preload("res://src/gameplay/decision/survey_chapter.gd")
const Advisor: GDScript = preload("res://src/gameplay/decision/advisor_chapter.gd")
const Payout: GDScript = preload("res://src/gameplay/decision/payout_chapter.gd")
const Prize: GDScript = preload("res://src/gameplay/decision/prize_chapter.gd")
const Perks: GDScript = preload("res://src/gameplay/decision/story_perks.gd")
var failures: int = 0
var screen: Control
var command_cues: PackedStringArray = []
var command_completions: int = 0

func command_completed() -> void:
	command_completions += 1

func verify_command_states() -> void:
	var widgets: GDScript = load("res://src/ui/screens/deploy/confrontation_widgets.gd")
	for gentle: bool in [false,true]:
		command_cues.clear()
		command_completions = 0
		var fx: Control = widgets.CommandAnimation.new()
		fx.size = Vector2(700,280)
		fx.gentle = gentle
		fx.durations = PackedFloat32Array([.1,.2,.3,.4,.5])
		fx.sound_offsets = PackedFloat32Array([.05,.05,.05,.05,.05])
		fx.evidence_title = "Reply-To + sender comparison"
		fx.sound_requested.connect(record_command_cue)
		fx.finished.connect(command_completed)
		root.add_child(fx)
		fx.advance(.02)
		check(command_cues.is_empty(),"Configured sound offset delays the opening cue")
		fx.advance(.04)
		check(command_cues == PackedStringArray(["command_open"]),"Cue fires at its configured offset")
		fx.advance(.4)
		check(fx.step == 2,"Custom durations route into typing")
		check(fx.command.visible_ratio == 1.0 if gentle else fx.command.visible_ratio < 1.0,"Reduced motion reveals text without typewriter motion")
		fx.advance(10)
		fx.advance(10)
		check(command_completions == 1 and not fx.running,"Large frames finish once without duplicate callbacks")
		check(command_cues == fx.sounds,"All configured state cues occur once in order")
		fx.queue_free()
	command_cues.clear()

func resolve_command(evidence: String, weak: String) -> void:
	screen._fire(evidence,weak)
	if is_instance_valid(screen._command_fx): screen._process(screen.command_fire_duration+.01)

func record_command_cue(id: String) -> void:
	command_cues.append(id)

func _initialize() -> void:
	_run.call_deferred()

func _process(_delta: float) -> bool:
	if is_instance_valid(screen): screen._backgrounded = false
	return false

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func settle() -> void:
	for index: int in 12: await process_frame

func capture(label: String) -> void:
	if "--render" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/chapter5_"+label+".png")

func touch_geometry(node: Node) -> void:
	if node is Button and (node as Button).is_visible_in_tree():
		var button: Button = node as Button
		var scale_unit: float = screen._u
		check(button.size.y/scale_unit >= 47.5,"Touch target height: "+button.text)
		check(button.size.x/scale_unit >= 47.5,"Touch target width: "+button.text)
	for child: Node in node.get_children(): touch_geometry(child)

func feedback_geometry() -> void:
	var overlay: Control = screen._overlay
	check(overlay.size.x >= screen.size.x * 0.75,"Feedback uses a readable sheet width after rebuilding the debate")
	check(screen.get_global_rect().encloses(overlay.get_global_rect()),"Feedback stays inside the mobile viewport")
	var content: VBoxContainer = overlay.get_child(0) as VBoxContainer
	var action: Button = content.get_child(content.get_child_count()-1) as Button
	check(action != null and overlay.get_global_rect().encloses(action.get_global_rect()),"Feedback action stays visible outside the scrolling text")
	touch_geometry(overlay)
	var elapsed: float = screen._elapsed
	screen._process(20)
	check(screen._elapsed == elapsed,"Feedback pauses the debate while the player reads")

func seed_chapters(player: Node) -> void:
	player.lesson_progress = {"mod_01":1}
	var first: Dictionary = Survey.fresh()
	for message: Dictionary in Survey.MESSAGES:
		first.read.append(message.id)
		first.sorted.append(message.id)
	for key: String in ["flags","domains","captures"]: first[key] = Survey.suspicious_ids()
	first.sealed = true
	first.completed = true
	player.save_chapter(first,Survey.ID,false)
	var second: Dictionary = Advisor.fresh()
	second.flags = ["domain","wording","signature"]
	second.domains = ["fake"]
	second.headers = ["From","Reply-To","Subject"]
	second.sealed = true
	second.completed = true
	player.save_chapter(second,Advisor.ID,false)
	var third: Dictionary = Payout.fresh()
	third.revealed = ["payout"]
	third.expanded = ["payout"]
	third.hotspots = ["logo","spelling","security"]
	third.reviewed = true
	third.sealed = true
	third.completed = true
	player.save_chapter(third,Payout.ID,false)
	check(not player.story_unlocked(Case.ID),"Hearing remains locked before Chapter 4")
	var fourth: Dictionary = Prize.fresh()
	fourth.timeline_order = Prize.ORDER.duplicate()
	fourth.timeline_checked = ["prize"]
	fourth.connections = Prize.PAIRS.keys()
	fourth.minutes_draft = "2"
	fourth.event_draft = "survey reply"
	fourth.notes = ["prize"]
	fourth.sealed = true
	fourth.claimed = true
	fourth.completed = true
	player.save_chapter(fourth,Prize.ID,false)

func _run() -> void:
	root.size = Vector2i(844,390)
	verify_command_states()
	var assets: Node = root.get_node("AssetManager")
	var hearing_ids: PackedStringArray = ["hearing_debate_v1","hearing_mystery_v1","john_counter_lettered_v1"]
	if "--sync-hearing-assets" in OS.get_cmdline_user_args():
		for entry: Dictionary in assets._gameplay_catalog():
			if str(entry.asset_id) in hearing_ids:
				check(await assets._sync_entry(entry),"Cloudinary hearing asset downloads: "+str(entry.asset_id))
		for id: String in hearing_ids:
			assets._textures.erase(id)
			check(assets.get_texture(id) != null,"Hearing texture reloads from disk cache: "+id)
	var player: Node = root.get_node("PlayerManager")
	var original: Dictionary = player.get_save_data()
	var auth: Node = root.get_node("AuthService")
	var signed: bool = auth._signed_in
	auth._signed_in = false
	var settings: Node = root.get_node("SettingsService")
	var speed: String = settings.text_speed
	var gentle: bool = settings.reduced_motion
	settings.text_speed = "instant"
	settings.reduced_motion = true
	player.reset_to_defaults()
	check(player.begin_story_attempt(Case.ID,false,false).is_empty(),"Locked hearing cannot start")
	seed_chapters(player)
	check(player.story_unlocked(Case.ID),"Sealing Chapter 4 unlocks hearing")
	check(not Case.clean({"completed":true,"lights_done":true}).completed,"Forged completion without evidence is rejected")
	player.owned_perks = Perks.ids(["recap","perspective","reference"])
	player.perk_loadout = Perks.ids(["perspective","reference"],2)
	var scene: PackedScene = load("res://src/ui/screens/deploy/confrontation_screen.tscn") as PackedScene
	if scene == null:
		check(false,"Confrontation scene compiles")
		player.apply_save_data(original)
		quit(1)
		return
	screen = scene.instantiate() as Control
	root.add_child(screen)
	if screen.get_script() == null:
		check(false,"Confrontation script compiles")
		player.apply_save_data(original)
		quit(1)
		return
	screen.on_enter({"test":true})
	await settle()
	screen._begin()
	check(screen.state.phase == "prep","New exhibit briefing is required")
	await capture("prep_844")
	screen._briefing()
	await settle()
	await capture("briefing_844")
	screen._ack_briefing()
	screen._begin()
	for dimensions: Vector2i in [Vector2i(844,390),Vector2i(720,360)]:
		root.size = dimensions
		await settle()
		await capture("suspects_"+str(dimensions.x))
		touch_geometry(screen)
		var confirm: Button = screen.find_child("ConfirmSuspect",true,false) as Button
		check(confirm != null and confirm.disabled,"Suspect requires an explicit selection")
		check(screen.get_global_rect().encloses(confirm.get_global_rect()),"Suspect confirmation stays inside mobile viewport")
		for person: String in Case.SUSPECTS:
			var card: Button = screen.find_child("Suspect_"+person,true,false) as Button
			var scroller: ScrollContainer = card.get_parent().get_parent().get_parent() as ScrollContainer
			check(scroller.get_global_rect().encloses(card.get_global_rect()),"Every suspect is visible without scrolling: "+person)
	screen.find_child("Suspect_Eric",true,false).pressed.emit()
	await settle()
	check(screen.state.suspect_guesses.is_empty(),"Selecting a card does not spend a guess")
	await capture("suspect_selected_720")
	screen.find_child("ConfirmSuspect",true,false).pressed.emit()
	var audio: Node = root.get_node("AudioManager")
	check(audio._hearing_decision and audio._tracks.has("hearing_decision"),"Decision phase selects its original tension score")
	audio._on_screen_changed(&"confrontation")
	await settle()
	check(audio._desired_bgm == audio._tracks["hearing_decision"],"Decision music is routed to the BGM deck")
	screen._menu()
	check(audio.bgm_player.stream_paused,"Decision score pauses with the menu")
	screen._close_overlay()
	var music_enabled: bool = settings.music_enabled
	settings.music_enabled = false
	settings.settings_changed.emit()
	check(not audio.bgm_player.playing,"Decision score respects music mute")
	settings.music_enabled = music_enabled
	settings.settings_changed.emit()
	root.size = Vector2i(844,390)
	await settle()
	screen._pick_suspect("Eric")
	check(screen.state.suspect_guesses.size() == 1,"Repeated suspect taps do not consume guesses")
	screen._pick_suspect("Dan")
	screen._pick_suspect("Mika")
	check(screen.state.theory_done and not screen.state.theory_bonus and screen.state.credibility == 20,"Three wrong theories join without bonus")
	screen._join()
	check(not audio._hearing_decision,"Joining restores the hearing soundtrack")
	screen.set_process(false)
	screen._start_round()
	check(screen.state.phase == "intro","Cannot bypass the invitation")
	screen._process(20)
	check(screen._elapsed == 0,"Invitation waits for a deliberate tap")
	await settle()
	await capture("invitation_844")
	touch_geometry(screen)
	screen._connect_hearing()
	screen._process(.8)
	await settle()
	await capture("connecting_844")
	var connection_time: float = screen._elapsed
	screen._connect_hearing()
	check(screen._elapsed == connection_time,"Repeated join taps do not restart the cinematic")
	screen._menu()
	await settle()
	await capture("pause_844")
	check(screen._overlay.get_global_rect().get_center().distance_to(screen.size*.5) < 2,"Pause menu is centered")
	check(root.get_node("AudioManager")._opening_paused,"Menu pauses owned cinematic audio")
	var elapsed: float = screen._elapsed
	screen._process(10)
	check(screen.state.phase == "intro" and screen._elapsed == elapsed,"Menu pauses title animation")
	screen._close_overlay()
	check(not root.get_node("AudioManager")._opening_paused,"Closing menu restores owned cinematic audio")
	screen._process(3.9)
	await settle()
	await capture("participants_844")
	root.size = Vector2i(720,360)
	await settle()
	await capture("participants_720")
	screen._backgrounded = true
	var paused_connection: float = screen._elapsed
	screen._process(10)
	check(screen._elapsed == paused_connection,"App backgrounding pauses joining")
	screen._backgrounded = false
	screen._process(1.5)
	await settle()
	await capture("title_844")
	screen._start_round()
	check(screen.state.phase == "intro","Title reveal cannot be skipped by a stray tap")
	screen._process(4)
	check(screen.state.phase == "debate","Joining cinematic reaches the debate exactly once")
	screen.set_process(true)
	root.size = Vector2i(844,390)
	await settle()
	await capture("round_entrance_844")
	var before_entrance: int = screen.state.credibility
	screen._voice = 3
	screen._fire(Case.ROUNDS[0].correct,Case.ROUNDS[0].weak)
	check(screen.state.credibility == before_entrance,"Round entrance rejects early rebuttals")
	screen._process(2.5)
	screen._voice = 3
	screen._update_statement()
	await settle()
	await capture("debate_844")
	touch_geometry(screen)
	var target: Button = screen.find_child("WeakPoint",true,false) as Button
	check(target.get_global_rect().end.y <= screen.size.y,"Weak point remains on-screen")
	screen._evidence(false,false)
	await settle()
	await capture("evidence_844")
	touch_geometry(screen)
	elapsed = screen._elapsed
	screen._process(40)
	check(screen._elapsed == elapsed,"Evidence drawer pauses statements")
	var drawer: Control = screen._overlay.get_child(1) as Control
	var tile: Button = drawer.find_child("Evidence_domain",true,false) as Button
	tile.pressed.emit()
	settings.reduced_motion = false
	drawer.select_button.pressed.emit()
	screen.set_process(false)
	check(screen._armed.is_empty() and is_instance_valid(screen._command_fx) and not is_instance_valid(screen._overlay),"Selecting evidence starts a load before arming")
	screen._command_fx.sound_requested.connect(record_command_cue)
	screen._process(.26)
	check(screen._command_fx.step == 1,"Load progresses from anticipation to terminal entrance")
	screen._menu()
	var load_age: float = screen._command_fx.age
	screen._process(10)
	check(screen._command_fx.age == load_age,"Menu freezes command animation")
	screen._close_overlay()
	screen._process(.55)
	await settle()
	await capture("command_load_844")
	check(screen._command_fx.step == 2,"Terminal types the selected record")
	screen._fire("domain",Case.ROUNDS[0].weak)
	check(screen.state.credibility == 20,"Load blocks premature firing")
	root.size = Vector2i(720,360)
	await settle()
	screen._position_command()
	await settle()
	await capture("command_load_720")
	check(screen._command_fx.step == 2,"Resize preserves the active load state")
	check(Rect2(Vector2.ZERO,screen._command_fx.size).encloses(screen._command_fx.command_bounds),"Terminal stays within the mobile safe area")
	screen._process(.7)
	check(screen._command_fx.step == 3,"Type completion enters confirmation")
	await capture("command_confirm_720")
	screen._process(2)
	check(screen._armed == "domain" and not is_instance_valid(screen._command_fx),"Complete load arms evidence once")
	check(screen._elapsed == elapsed,"Loading never consumes debate time")
	check(command_cues == PackedStringArray(["command_snap","command_type","command_ready","command_send"]),"Remaining load sounds trigger once despite pause and resize")
	root.size = Vector2i(844,390)
	await settle()
	screen.set_process(true)
	resolve_command("domain",Case.ROUNDS[0].weak)
	check(screen.state.credibility == 10 and screen.state.mistakes == 1,"Wrong record costs ten")
	await settle()
	feedback_geometry()
	await capture("wrong_record_844")
	screen._retry()
	resolve_command("borrow",Case.ROUNDS[0].weak)
	check(screen.state.credibility == 0 and screen.state.auto_hints.has(0),"Two mistakes mark and highlight assist")
	await settle()
	feedback_geometry()
	await capture("retry_844")
	screen._retry()
	check(screen.state.credibility == 20 and screen.state.restarts == 1,"Zero resets round to a recoverable checkpoint")
	screen._armed = "domain"
	screen._process(8.1)
	check(screen._reflecting and screen.state.credibility == 20,"Missed claim opens John's reflection without a penalty")
	await settle()
	await capture("reflection_844")
	screen._process(20)
	check(screen._reflecting,"Reflection waits for a deliberate tap")
	screen.find_child("ReplayDiscussion",true,false).pressed.emit()
	check(not screen._reflecting and screen._voice == 0 and screen._armed == "domain","Replay restarts discussion and preserves the selected command")
	screen._toggle_hold()
	elapsed = screen._elapsed
	screen._process(30)
	check(screen._elapsed == elapsed,"Hold freezes statement loop")
	screen._voice = 3
	screen._fire(Case.ROUNDS[0].correct,Case.ROUNDS[0].weak)
	check(screen.state.credibility == 20,"Held discussion rejects scoring input")
	screen._toggle_hold()
	for index: int in 4:
		check(screen.state.round == index,"Correct round index")
		screen._voice = 3
		screen._update_statement()
		screen._armed = Case.ROUNDS[index].correct
		screen._update_statement()
		await settle()
		screen.find_child("WeakPoint",true,false).pressed.emit()
		var credibility: int = screen.state.credibility
		screen._fire(Case.ROUNDS[index].correct,Case.ROUNDS[index].weak)
		check(screen.state.credibility == credibility,"Duplicate rebuttal cannot score")
		if index == 0:
			screen.set_process(false)
			screen._process(.16)
			await capture("command_fire_844")
			check(Rect2(Vector2.ZERO,screen._command_fx.size).encloses(screen._command_fx.command_bounds),"Flying command text stays in the mobile safe area")
			check(not screen._command_fx.terminal.visible,"Firing moves pixel text without a covering panel")
			check(screen._command_fx.target_fraction.y < screen._command_fx.source_fraction.y,"Command travels from the strip toward the actual claim")
			screen._process(.17)
			screen.set_process(true)
		else: screen._process(screen.command_fire_duration+.01)
		check(screen.state.solved.size() == index+1,"Correct evidence seals rebuttal")
		await settle()
		if index == 0:
			screen._process(.2)
			await capture("evidence_strike_844")
			screen._process(.5)
			await capture("counter_844")
			root.size = Vector2i(720,360)
			await settle()
			await capture("counter_720")
			root.size = Vector2i(844,390)
			await settle()
			screen._menu()
			var counter_elapsed: float = screen._elapsed
			screen._process(10)
			check(screen._elapsed == counter_elapsed,"Pause freezes the counter cut-in")
			screen._close_overlay()
			screen._start_round()
			check(screen.state.phase == "rebuttal","Counter cannot be skipped by a double tap")
		screen._process(2.3)
		if index == 0: await capture("rebuttal_844")
		var restored: Dictionary = Case.clean(screen.state)
		check(restored.phase == "rebuttal" and restored.round == index,"Rebuttal save preserves current explanation")
		screen._start_round()
		screen._process(2.5)
	check(screen.state.phase == "final" and screen.state.credibility == 80,"Four clean rebuttals after restart reach eighty")
	await settle()
	await capture("final_844")
	screen._match_typo()
	screen._match_typo()
	check(screen.state.credibility == 100 and screen.state.final_matched,"Final typo awards twenty once")
	for index: int in Case.ADMISSION.size(): screen._next_admission()
	check(screen.state.admitted and screen.state.phase == "comic","Admission precedes reconstruction")
	screen._place_frame("dan_prank",0)
	screen._check_comic()
	check(not screen.state.comic_checked,"Unsupported comic frame cannot finish")
	screen._close_overlay()
	for index: int in 6: screen._place_frame(Case.COMIC_ORDER[index],index)
	var comic_snapshot: Dictionary = player.story_checkpoint(Case.ID,false).duplicate(true)
	check(Case.clean(comic_snapshot).comic_order == Case.COMIC_ORDER,"Comic placement survives save cleaning")
	screen.on_exit()
	screen.queue_free()
	await settle()
	screen = scene.instantiate() as Control
	root.add_child(screen)
	screen.on_enter({"test":true})
	check(screen.state.phase == "comic" and screen.state.comic_order == Case.COMIC_ORDER,"Reopening hearing restores comic placement")
	await settle()
	await capture("comic_844")
	screen._check_comic()
	check(screen.state.comic_checked,"Correct six-frame sequence accepted")
	screen._play_animatic()
	await settle()
	await capture("animatic_844")
	for index: int in 6: screen._next_panel()
	check(screen.state.animatic_done and screen.state.phase == "aftermath","All panels shown before aftermath")
	for index: int in Case.AFTERMATH.size(): screen._next_aftermath()
	screen._finish()
	check(not screen.state.completed,"Lights finish gates completion")
	screen._process(3.1)
	await settle()
	await capture("lights_844")
	var balance: int = player.credits
	screen._finish()
	check(screen.state.completed and player.credits == balance+100,"Assisted hearing awards base coins")
	screen._save()
	check(player.credits == balance+100,"Repeated completion save cannot duplicate coins")
	check(player.perk_attempts.back().assist_status == "assisted","Attempt ledger records assisted status")
	await settle()
	await capture("results_844")
	screen._menu()
	check(screen._result_audio.stream_paused,"Results menu pauses celebration music")
	screen._close_overlay()
	var clean: Dictionary = screen.state.duplicate(true)
	clean.hint_used = false
	clean.suspect_guesses = []
	clean.auto_hints = []
	clean.round_errors = [0,0,0,0]
	clean.mistakes = 0
	clean.comic_errors = 0
	clean.perk_run = Perks.new_run("clean-check",Perks.ids([]),false,true,Case.ID)
	check(Case.clean(clean).reward == 125,"Unassisted clean hearing earns bonus")
	var saved: Dictionary = player.get_save_data()
	player.reset_to_defaults()
	player.apply_save_data(saved)
	check(player.chapter_progress[Case.ID].completed,"Chapter 5 completion survives save reload")
	screen.on_exit()
	screen.queue_free()
	await settle()
	screen = scene.instantiate() as Control
	root.add_child(screen)
	screen.on_enter({"test":true,"replay":true})
	screen._ack_briefing()
	screen._begin()
	screen._pick_suspect("Jobert")
	check(screen.state.theory_bonus and screen.state.credibility == 35,"Correct theory grants thirty-five starting credibility")
	check(not Perks.allowed(screen.state.perk_run,"perspective","research_test","debate",[]),"Research tests cannot use story perks")
	check(not Perks.allowed(screen.state.perk_run,"reference","checkpoint","debate",[1,2]),"Checkpoints cannot use story perks")
	settings.reduced_motion = false
	screen._join()
	screen.set_process(false)
	screen._connect_hearing()
	screen._process(2.45)
	await settle()
	await capture("joining_motion_844")
	screen._process(7.55)
	screen.set_process(true)
	screen._process(2.5)
	screen._voice = 3
	screen._update_statement()
	screen._use_perk("perspective")
	check(Perks.status(screen.state.perk_run) == "assisted","Trial perk usage recorded")
	screen._close_overlay()
	for index: int in 4:
		screen._voice = 3
		resolve_command(Case.ROUNDS[index].correct,Case.ROUNDS[index].weak)
		screen._process(2.3)
		screen._start_round()
		screen._process(2.5)
	check(screen.state.credibility == 95,"Theory bonus plus four correct rebuttals reaches ninety-five")
	settings.text_speed = "normal"
	screen._elapsed = 0
	screen._build()
	screen._match_typo()
	check(not screen.state.final_matched,"First tap reveals a message that is still typing")
	screen._match_typo()
	check(screen.state.credibility == 100,"Theory bonus never exceeds credibility cap")
	settings.text_speed = "instant"
	var replay_balance: int = player.credits
	var replay_clear: Dictionary = clean.duplicate(true)
	replay_clear.perk_run = screen.state.perk_run.duplicate(true)
	player.save_story_attempt(replay_clear,true,false,Case.ID)
	check(player.credits == replay_balance,"Replay clear never awards duplicate coins")
	# Return to a saved active round for responsive layout and retry checks.
	screen.state = Case.fresh()
	screen.state.briefed = true
	screen.state.theory_done = true
	screen.state.theory_bonus = true
	screen.state.solved = [0]
	screen.state.round = 1
	screen.state.phase = "debate"
	screen.state.credibility = 50
	screen.state.round_start = 50
	screen.state.perk_run = Perks.new_run("retry-check",Perks.ids(["perspective","reference"]),true,true,Case.ID)
	screen._build()
	for index: int in 5:
		screen._voice = 3
		resolve_command("short",Case.ROUNDS[1].weak)
		screen._retry()
	check(screen.state.solved == [0] and screen.state.credibility == 50,"Later zero retry preserves earlier rebuttals and checkpoint")
	screen._backgrounded = true
	var frozen: Dictionary = screen.state.duplicate(true)
	screen._fire("headers",Case.ROUNDS[1].weak)
	screen._process(40)
	check(screen.state == frozen,"Backgrounded hearing rejects input and timers")
	screen._backgrounded = false
	var old_owner: String = screen._owner
	screen._owner = "not-the-current-participant"
	screen._fire("headers",Case.ROUNDS[1].weak)
	check(screen.state == frozen,"A switched participant cannot alter this attempt")
	screen._owner = old_owner
	for dimensions: Vector2i in [Vector2i(720,360),Vector2i(932,430)]:
		root.size = dimensions
		screen._queue_build()
		await settle()
		await capture("debate_%d" % dimensions.x)
		touch_geometry(screen)
		for round_number: int in 4:
			var content_round: Dictionary = Case.ROUNDS[round_number]
			screen._stage.show_statement("Jobert",content_round.claim,content_round.weak,"coffee",false)
			await settle()
			var weak_button: Button = screen.find_child("WeakPoint",true,false) as Button
			check(weak_button.is_visible_in_tree() and screen.get_global_rect().encloses(weak_button.get_global_rect()),"Every inline weak phrase fits the phone")
			touch_geometry(screen)
		screen._update_statement()
		screen._evidence(false,false)
		await settle()
		await capture("evidence_%d" % dimensions.x)
		touch_geometry(screen)
		screen._close_overlay()
		screen._voice = 3
		resolve_command("short",Case.ROUNDS[1].weak)
		await settle()
		feedback_geometry()
		await capture("wrong_record_%d" % dimensions.x)
		var content: VBoxContainer = screen._overlay.get_child(0) as VBoxContainer
		(content.get_child(content.get_child_count()-1) as Button).pressed.emit()
		check(not is_instance_valid(screen._overlay) and screen.state.phase == "debate","Feedback action returns to the debate")
	settings.reduced_motion = false
	screen._build()
	screen._voice = 0
	screen._armed = "headers"
	screen._update_statement()
	screen._process(.2)
	await settle()
	await capture("speaker_transition_932")
	screen._menu()
	var transition_time: float = screen._stage.transition
	screen._process(10)
	check(screen._stage.transition == transition_time,"Menu freezes speaker motion")
	screen._close_overlay()
	screen._arm("headers")
	screen.set_process(false)
	screen._process(.8)
	var suspended_age: float = screen._command_fx.age
	screen._backgrounded = true
	screen._process(40)
	check(screen._command_fx.age == suspended_age,"App suspension freezes the command clock")
	screen._backgrounded = false
	screen.on_exit()
	check(not is_instance_valid(screen._command_fx) and screen._pending_command.is_empty(),"Leaving the hearing cancels pending commands")
	screen.queue_free()
	await settle()
	player.apply_save_data(original)
	auth._signed_in = signed
	settings.text_speed = speed
	settings.reduced_motion = gentle
	print("CONFRONTATION_CHECKS failures="+str(failures))
	quit(1 if failures else 0)
