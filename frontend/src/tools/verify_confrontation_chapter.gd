extends SceneTree
const Case: GDScript = preload("res://src/gameplay/decision/confrontation_chapter.gd")
const Survey: GDScript = preload("res://src/gameplay/decision/survey_chapter.gd")
const Advisor: GDScript = preload("res://src/gameplay/decision/advisor_chapter.gd")
const Payout: GDScript = preload("res://src/gameplay/decision/payout_chapter.gd")
const Prize: GDScript = preload("res://src/gameplay/decision/prize_chapter.gd")
const Perks: GDScript = preload("res://src/gameplay/decision/story_perks.gd")
var failures: int = 0
var screen: Control

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
	screen._pick_suspect("Eric")
	screen._pick_suspect("Eric")
	check(screen.state.suspect_guesses.size() == 1,"Repeated suspect taps do not consume guesses")
	screen._pick_suspect("Dan")
	screen._pick_suspect("Mika")
	check(screen.state.theory_done and not screen.state.theory_bonus and screen.state.credibility == 20,"Three wrong theories join without bonus")
	screen._join()
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
	screen._process(.7)
	await settle()
	await capture("title_844")
	screen._start_round()
	await settle()
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
	drawer.select_button.pressed.emit()
	check(screen._armed == "domain" and not is_instance_valid(screen._overlay),"Evidence buttons route selected record to the debate")
	screen._fire("domain",Case.ROUNDS[0].weak)
	check(screen.state.credibility == 10 and screen.state.mistakes == 1,"Wrong record costs ten")
	await settle()
	feedback_geometry()
	await capture("wrong_record_844")
	screen._retry()
	screen._fire("borrow",Case.ROUNDS[0].weak)
	check(screen.state.credibility == 0 and screen.state.auto_hints.has(0),"Two mistakes mark and highlight assist")
	await settle()
	feedback_geometry()
	await capture("retry_844")
	screen._retry()
	check(screen.state.credibility == 20 and screen.state.restarts == 1,"Zero resets round to a recoverable checkpoint")
	screen._toggle_hold()
	elapsed = screen._elapsed
	screen._process(30)
	check(screen._elapsed == elapsed,"Hold freezes statement loop")
	screen._toggle_hold()
	for index: int in 4:
		check(screen.state.round == index,"Correct round index")
		screen._voice = 3
		screen._update_statement()
		screen._fire(Case.ROUNDS[index].correct,Case.ROUNDS[index].weak)
		var credibility: int = screen.state.credibility
		screen._fire(Case.ROUNDS[index].correct,Case.ROUNDS[index].weak)
		check(screen.state.credibility == credibility,"Duplicate rebuttal cannot score")
		check(screen.state.solved.size() == index+1,"Correct evidence seals rebuttal")
		await settle()
		if index == 0: await capture("rebuttal_844")
		var restored: Dictionary = Case.clean(screen.state)
		check(restored.phase == "rebuttal" and restored.round == index,"Rebuttal save preserves current explanation")
		screen._start_round()
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
	screen._join()
	screen._start_round()
	screen._voice = 3
	screen._update_statement()
	screen._use_perk("perspective")
	check(Perks.status(screen.state.perk_run) == "assisted","Trial perk usage recorded")
	screen._close_overlay()
	for index: int in 4:
		screen._voice = 3
		screen._fire(Case.ROUNDS[index].correct,Case.ROUNDS[index].weak)
		screen._start_round()
	check(screen.state.credibility == 95,"Theory bonus plus four correct rebuttals reaches ninety-five")
	settings.text_speed = "normal"
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
		screen._fire("short",Case.ROUNDS[1].weak)
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
		screen._evidence(false,false)
		await settle()
		await capture("evidence_%d" % dimensions.x)
		touch_geometry(screen)
		screen._close_overlay()
		screen._voice = 3
		screen._fire("short",Case.ROUNDS[1].weak)
		await settle()
		feedback_geometry()
		await capture("wrong_record_%d" % dimensions.x)
		var content: VBoxContainer = screen._overlay.get_child(0) as VBoxContainer
		(content.get_child(content.get_child_count()-1) as Button).pressed.emit()
		check(not is_instance_valid(screen._overlay) and screen.state.phase == "debate","Feedback action returns to the debate")
	screen.on_exit()
	screen.queue_free()
	await settle()
	player.apply_save_data(original)
	auth._signed_in = signed
	settings.text_speed = speed
	settings.reduced_motion = gentle
	print("CONFRONTATION_CHECKS failures="+str(failures))
	quit(1 if failures else 0)
