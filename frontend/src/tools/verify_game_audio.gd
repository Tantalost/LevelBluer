extends SceneTree
var failures: int = 0
var audio: Node
var settings: Node
var speech_requests: int = 0
var reaction_requests: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func wait(seconds: float = 0.1) -> void:
	await create_timer(seconds).timeout

func voices() -> int:
	var total: int = 0
	for player: AudioStreamPlayer in audio.sfx_pool.get_children():
		if player.playing: total += 1
	return total

func music_voices() -> int:
	var total: int = 0
	for player: AudioStreamPlayer in audio._decks:
		if player.playing: total += 1
	return total

func _run() -> void:
	audio = root.get_node("AudioManager")
	settings = root.get_node("SettingsService")
	var old: Array = [settings.music_enabled, settings.sound_enabled, settings.music_volume, settings.sfx_volume, settings.master_volume, settings.dialogue_blips_enabled, settings.text_speed]
	settings.music_enabled = true
	settings.sound_enabled = true
	settings.music_volume = 55
	settings.sfx_volume = 70
	settings.master_volume = 80
	audio._focus_lost = false
	audio._app_paused = false
	audio._apply_buses()
	check(audio._tracks.size() == 4 and audio._sounds.size() == 7, "All original audio assets load")
	for key: String in audio._tracks:
		var stream: AudioStreamOggVorbis = audio._tracks[key]
		check(stream.loop and stream.get_length() >= 17.0, "Music loops are long, nonempty and looping: " + key)
	for key: String in audio._sounds:
		var stream: AudioStreamWAV = audio._sounds[key]
		check(stream.get_length() > 0.05 and stream.get_length() < 1.0, "Short, nonempty cue: " + key)
	# Disclaimer is deliberately silent, including its Continue button.
	audio._on_screen_changed(&"intro")
	await wait()
	audio.play_sfx("ui_click")
	check(voices() == 0 and music_voices() == 0, "Disclaimer stays silent")
	audio._on_screen_changed(&"splash")
	await wait(0.8)
	check(audio.bgm_player.stream == audio._tracks.loading and music_voices() == 1, "Loading selects its own loop")
	audio.play_sfx("loading_ready")
	check(voices() == 1, "Ready sting plays independently of music")
	audio._stop_effects()
	# Intermediate routes coalesce and equal tracks do not restart.
	audio._on_screen_changed(&"dashboard")
	audio._on_screen_changed(&"lesson_player")
	await wait(0.8)
	check(audio.bgm_player.stream == audio._tracks.study and music_voices() == 1, "Final route wins without stacked music")
	var position: float = audio.bgm_player.get_playback_position()
	audio._on_screen_changed(&"codex")
	await wait()
	check(audio.bgm_player.get_playback_position() >= position, "Shared study loop does not restart")
	# Rapid target changes must cancel old fade callbacks and stop the unused deck.
	audio.play_bgm(audio._tracks.hub, 0.2)
	await wait(0.05)
	audio.play_bgm(audio._tracks.pvp, 0.2)
	await wait(0.3)
	check(audio.bgm_player.stream == audio._tracks.pvp and music_voices() == 1, "Interrupted crossfade settles on newest track")
	check(is_equal_approx(audio.bgm_player.volume_linear, audio.MUSIC_GAIN), "Crossfade ends at nominal gain")
	audio._on_screen_changed(&"dashboard")
	await wait()
	audio._on_dashboard_mode(&"PVP")
	await wait(0.8)
	check(audio.bgm_player.stream == audio._tracks.pvp, "PvP mode selects darker loop")
	# Muted navigation must remember the new destination, not resume the old song.
	settings.music_enabled = false
	audio._apply_buses()
	audio._on_screen_changed(&"lesson_player")
	await wait()
	check(music_voices() == 0, "Music toggle stops both decks")
	settings.music_enabled = true
	audio._apply_buses()
	await wait(0.8)
	check(audio.bgm_player.stream == audio._tracks.study and music_voices() == 1, "Unmute uses latest screen's track")
	settings.music_volume = 25
	audio._apply_buses()
	check(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("BGM"))), 0.25), "Independent music volume uses the BGM bus")
	# Pause/background handling never resumes stale effects.
	audio._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(audio.bgm_player.stream_paused, "Focus loss pauses music")
	audio._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	audio._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	check(audio.bgm_player.stream_paused, "Focus alone does not override application suspension")
	audio.play_sfx("ui_notification")
	check(voices() == 0, "No effects while backgrounded")
	audio._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	check(not audio.bgm_player.stream_paused, "Resume restores music")
	# A dynamically added button is connected once; disabled and hidden controls are silent.
	var button: Button = Button.new()
	root.add_child(button)
	audio._on_node_added(button)
	audio._last_sound.clear()
	button.pressed.emit()
	button.pressed.emit()
	check(voices() == 1, "Rapid/double button signals play one click")
	audio._stop_effects()
	audio._last_sound.clear()
	button.disabled = true
	button.pressed.emit()
	check(voices() == 0, "Disabled button is silent")
	button.disabled = false
	button.hide()
	button.pressed.emit()
	check(voices() == 0, "Hidden button is silent")
	button.show()
	settings.sound_enabled = false
	audio._apply_buses()
	button.pressed.emit()
	check(voices() == 0 and music_voices() == 1, "SFX toggle leaves music independent")
	settings.sound_enabled = true
	audio._apply_buses()
	paused = true
	button.process_mode = Node.PROCESS_MODE_ALWAYS
	button.pressed.emit()
	check(voices() == 1, "Pause-menu UI can still make sound")
	paused = false
	button.queue_free()
	audio._stop_effects()
	for i: int in 25:
		audio._last_sound.clear()
		audio.play_sfx("ui_notification")
	check(voices() <= 8 and audio.sfx_pool.get_child_count() == 8, "Effect bursts never allocate unbounded players")
	audio._on_screen_changed(&"gameplay")
	await wait(0.8)
	check(music_voices() == 0, "UI music does not leak into battle")
	await _test_dialogue_blips()
	await _test_dialogue_reactions()
	# Validate persistence through the real service code, redirected to an ignored test file.
	var source: GDScript = load("res://src/autoload/settings_service.gd") as GDScript
	var isolated: GDScript = GDScript.new()
	isolated.source_code = source.source_code.replace("user://settings.cfg", "res://.godot/audio_settings_test.cfg")
	check(isolated.reload() == OK, "Isolated settings service compiles")
	var prefs: Node = isolated.new()
	root.add_child(prefs)
	prefs.music_volume = 37
	prefs.music_enabled = false
	prefs.sound_enabled = false
	prefs.dialogue_blips_enabled = false
	prefs.save_settings()
	prefs.music_volume = 99
	prefs.music_enabled = true
	prefs.sound_enabled = true
	prefs.dialogue_blips_enabled = true
	prefs.load_settings()
	check(prefs.music_volume == 37 and not prefs.music_enabled and not prefs.sound_enabled, "Music volume and mute preferences round-trip")
	check(not prefs.dialogue_blips_enabled, "Dialogue preference round-trips independently")
	prefs.queue_free()
	# Opening Settings reads preferences without firing save handlers.
	var scene: PackedScene = load("res://src/ui/screens/settings/settings_screen.tscn") as PackedScene
	var panel: Control = scene.instantiate()
	root.add_child(panel)
	panel.on_enter({})
	check(panel._music_slider.value == settings.music_volume, "Music slider reflects saved preferences")
	check(panel._dialogue_toggle.button_pressed == settings.dialogue_blips_enabled, "Dialogue toggle reflects preferences without saving")
	for dimensions: Vector2i in [Vector2i(1280, 720), Vector2i(844, 390)]:
		root.size = dimensions
		await wait()
		var scroll: ScrollContainer = panel.get_node("SafeAreaContainer/ScreenLayout/ScrollContainer") as ScrollContainer
		scroll.ensure_control_visible(panel._music_slider)
		await wait()
		var physical_scale: float = root.get_final_transform().get_scale().y
		check(scroll.get_global_rect().encloses(panel._music_slider.get_global_rect()), "Music slider reachable in landscape: %s" % dimensions)
		check(panel._music_slider.size.y * physical_scale >= 48.0, "Music slider retains a 48px touch target")
		check(panel._music_val.get_theme_font_size("font_size") * physical_scale >= 16.0, "Music volume label remains readable")
		scroll.ensure_control_visible(panel._dialogue_toggle)
		await wait()
		check(scroll.get_global_rect().encloses(panel._dialogue_toggle.get_global_rect()), "Dialogue toggle reachable")
		check(panel._dialogue_toggle.size.y * physical_scale >= 48.0, "Dialogue toggle retains touch size")
		if "--render" in OS.get_cmdline_user_args():
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.godot/audio_settings_%dx%d.png" % [dimensions.x, dimensions.y])
	panel.queue_free()
	settings.music_enabled = old[0]
	settings.sound_enabled = old[1]
	settings.music_volume = old[2]
	settings.sfx_volume = old[3]
	settings.master_volume = old[4]
	settings.dialogue_blips_enabled = old[5]
	settings.text_speed = old[6]
	audio._on_screen_changed(&"intro")
	audio._apply_buses()
	await wait()
	print("[GAME AUDIO] failures=%d" % failures)
	quit(1 if failures else 0)

func _test_dialogue_blips() -> void:
	settings.dialogue_blips_enabled = true
	settings.text_speed = "normal"
	check(audio._voice_streams.size() == 3 and audio.dialogue_player.bus == &"SFX", "Three original voices share SFX volume")
	var distinct: Dictionary = {}
	for speaker: String in audio._voice_streams:
		var stream: AudioStreamWAV = audio._voice_streams[speaker]
		check(stream.get_length() > 0.05 and stream.get_length() < 0.07 and stream.loop_mode == AudioStreamWAV.LOOP_DISABLED, "Short one-shot speech: " + speaker)
		check(stream.data.decode_s16(0) == 0 and stream.data.decode_s16(stream.data.size() - 2) == 0, "Sample fades to silence: " + speaker)
		distinct[hash(stream.data)] = true
	check(distinct.size() == 3, "Each speaker has a distinct waveform")
	if "--voice-preview" in OS.get_cmdline_user_args():
		_export_voice_preview()
	var owner: Control = Control.new()
	root.add_child(owner)
	for speaker: String in ["Alex", "Mia", "Ms. Reyes"]:
		audio._last_blip_ms = -10000
		audio.play_dialogue_blip(speaker, "neutral", 3, owner)
		check(audio.dialogue_player.playing and audio.dialogue_player.stream == audio._voice_streams[speaker], "Speaker voice plays: " + speaker)
		var pitch: float = audio.dialogue_player.pitch_scale
		audio.play_dialogue_blip(speaker, "worried", 4, owner)
		check(audio.dialogue_player.pitch_scale == pitch, "Cooldown prevents per-frame restarts")
		audio._last_blip_ms = -10000
		audio.play_dialogue_blip(speaker, "worried", 3, owner)
		check(is_equal_approx(audio.dialogue_player.pitch_scale - pitch, 0.04), "Subtle expression pitch change")
		audio.stop_dialogue_blips(owner)
	for setting: String in ["dialogue_blips_enabled", "sound_enabled", "sfx_volume", "master_volume"]:
		var previous: Variant = settings.get(setting)
		settings.set(setting, false if previous is bool else 0)
		audio._apply_buses()
		audio._last_blip_ms = -10000
		audio.play_dialogue_blip("Alex", "neutral", 3, owner)
		check(not audio.dialogue_player.playing, "Blips respect " + setting)
		settings.set(setting, previous)
	audio._apply_buses()
	var workspace: Control = load("res://src/gameplay/decision/decision_workspace.gd").new()
	root.add_child(workspace)
	workspace.set_process(false)
	workspace.configure_speech_blips("mod_01", 1)
	workspace.speech_blip_requested.connect(func(_speaker: String, _emotion: String, _letter: int) -> void: speech_requests += 1)
	var lines: Array[Dictionary] = [{"speaker": "Alex", "text": "abc,   def ghi jkl mno pqr stu vwx yz"}]
	workspace.show_story(lines, "VOICE TEST")
	audio._last_blip_ms = -10000
	workspace._process(3.1 / 42.0)
	check(speech_requests == 1 and audio.dialogue_player.playing, "Typewriter signals blip after three revealed letters")
	workspace._process(4.0 / 42.0)
	check(speech_requests == 1, "Punctuation and spaces do not trigger blips")
	workspace._reveal_line()
	check(not audio.dialogue_player.playing and speech_requests == 1, "Skip stops immediately without sounding skipped text")
	workspace.show_story(lines, "VOICE TEST")
	audio._last_blip_ms = -10000
	workspace._process(3.1 / 42.0)
	workspace.set_interaction_locked(true)
	check(not audio.dialogue_player.playing, "Story pause/lock stops current sound")
	workspace.set_interaction_locked(false)
	audio._last_blip_ms = -10000
	audio.play_dialogue_blip("Mia", "neutral", 3, workspace)
	workspace._review_open = true
	workspace._refresh_controls()
	check(not audio.dialogue_player.playing, "Opening logs silences speech")
	workspace._review_open = false
	audio._last_blip_ms = -10000
	audio.play_dialogue_blip("Mia", "neutral", 3, workspace)
	workspace._mail_open = true
	workspace._refresh_controls()
	check(not audio.dialogue_player.playing, "Opening phone silences speech")
	workspace._mail_open = false
	for module_id: String in ["mod_01", "mod_02"]:
		workspace.configure_speech_blips(module_id, 2 if module_id == "mod_01" else 1)
		workspace.show_story(lines, "OUT OF SCOPE")
		var before: int = speech_requests
		workspace._process(0.1)
		check(speech_requests == before, "Only Module 1 Stage 1 is enabled")
	workspace.configure_speech_blips("mod_01", 1)
	settings.text_speed = "instant"
	workspace.show_story(lines, "INSTANT")
	var before: int = speech_requests
	workspace._process(1.0)
	check(speech_requests == before and not audio.dialogue_player.playing, "Instant text remains silent")
	settings.text_speed = "normal"
	workspace.show_story(lines, "STALL")
	workspace._process(10.0)
	check(speech_requests == before, "Frame stall cannot emit a backlog")
	for speaker: String in ["", "Narrator", "Unknown"]:
		audio._last_blip_ms = -10000
		audio.play_dialogue_blip(speaker, "neutral", 3, workspace)
		check(not audio.dialogue_player.playing, "Unknown/narrator stays silent")
	audio._last_blip_ms = -10000
	audio.play_dialogue_blip("Alex", "neutral", 3, workspace)
	workspace.hide()
	check(not audio.dialogue_player.playing, "Hiding workspace stops its blip")
	workspace.show()
	audio._last_blip_ms = -10000
	audio.play_dialogue_blip("Alex", "neutral", 3, workspace)
	paused = true
	audio._process(0.0)
	check(not audio.dialogue_player.playing, "Tree pause silences dialogue but not UI effects")
	paused = false
	audio._last_blip_ms = -10000
	audio.play_dialogue_blip("Alex", "neutral", 3, workspace)
	audio._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not audio.dialogue_player.playing, "Backgrounding stops speech")
	audio._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	audio._last_blip_ms = -10000
	audio.play_dialogue_blip("Alex", "neutral", 3, workspace)
	workspace.free()
	check(not audio.dialogue_player.playing, "Removing workspace stops its sound")
	audio._last_blip_ms = -10000
	audio.play_dialogue_blip("Alex", "neutral", 3, owner)
	audio._on_screen_changed(&"dashboard")
	check(not audio.dialogue_player.playing, "Navigation stops speech before transition")
	owner.queue_free()
	audio._on_screen_changed(&"gameplay")
	await wait()

func _export_voice_preview() -> void:
	# Optional audition only, in ignored .godot/. Order: Alex, Mia, Ms. Reyes.
	var rate: int = audio.BLIP_RATE
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(rate * 7 * 2)
	bytes.fill(0)
	var section: int = 0
	for speaker: String in ["Alex", "Mia", "Ms. Reyes"]:
		var stream: AudioStreamWAV = audio._voice_streams[speaker]
		for syllable: int in 12:
			var offset: int = int((0.25 + section * 2.25 + syllable * 0.12) * rate)
			for sample: int in stream.data.size() / 2:
				# Nominal player -6dB, default SFX 70%, master 80%.
				bytes.encode_s16((offset + sample) * 2, int(stream.data.decode_s16(sample * 2) * db_to_linear(-6.0) * 0.70 * 0.80))
		section += 1
	var preview: AudioStreamWAV = AudioStreamWAV.new()
	preview.format = AudioStreamWAV.FORMAT_16_BITS
	preview.mix_rate = rate
	preview.data = bytes
	check(preview.save_to_wav("res://.godot/dialogue-voices-preview.wav") == OK, "Original voice audition exported")

func _test_dialogue_reactions() -> void:
	check(audio._reaction_streams.size() == 18, "Six reactions retain each of three character timbres")
	var fingerprints: Dictionary = {}
	for key: String in audio._reaction_streams:
		var stream: AudioStreamWAV = audio._reaction_streams[key]
		check(stream.get_length() >= 0.17 and stream.get_length() <= 0.29, "Reaction is brief: " + key)
		check(stream.data.decode_s16(0) == 0 and stream.data.decode_s16(stream.data.size() - 2) == 0, "Reaction endpoints are silent")
		fingerprints[hash(stream.data)] = true
	check(fingerprints.size() == 18, "Reactions and speakers have distinct waveforms")
	var workspace: Control = load("res://src/gameplay/decision/decision_workspace.gd").new()
	root.add_child(workspace)
	workspace.set_process(false)
	workspace.configure_speech_blips("mod_01", 1)
	workspace.speech_reaction_requested.connect(func(_speaker: String, _emotion: String) -> void: reaction_requests += 1)
	var lines: Array[Dictionary] = [
		{"speaker": "Alex", "text": "Wait, what just happened?", "emotion": "shocked"},
		{"speaker": "Alex", "text": "That cannot be right.", "emotion": "shocked"},
		{"speaker": "Alex", "text": "Let's check together.", "emotion": "neutral"},
		{"speaker": "Mia", "text": "Oh! That surprised me.", "emotion": "shocked"},
	]
	workspace.show_story(lines, "REACTION TEST")
	check(reaction_requests == 0, "Preparing a line does not sound a hidden reaction")
	audio._last_reaction_ms = -10000
	workspace._process(0.01)
	check(reaction_requests == 1 and audio._reaction_active and audio.dialogue_player.playing, "Shock cues once at active line start")
	var reaction: AudioStream = audio.dialogue_player.stream
	audio._last_blip_ms = -10000
	audio.play_dialogue_blip("Alex", "shocked", 3, workspace)
	check(audio.dialogue_player.stream == reaction, "Typing blips do not interrupt a reaction")
	audio.play_dialogue_reaction("Mia", "sad", workspace)
	check(audio.dialogue_player.stream == reaction, "Rapid emotion changes cannot stack cues")
	workspace._reveal_line()
	check(not audio.dialogue_player.playing and not audio._reaction_active, "Skip also stops reactions")
	workspace._continue()
	workspace._process(0.01)
	check(reaction_requests == 1, "Consecutive same-speaker/same-emotion lines stay restrained")
	workspace._reveal_line()
	workspace._continue()
	workspace._process(0.01)
	check(reaction_requests == 1, "Neutral line has no reaction")
	workspace._reveal_line()
	workspace._continue()
	audio._last_reaction_ms = -10000
	workspace._process(0.01)
	check(reaction_requests == 2 and audio.dialogue_player.stream == audio._reaction_streams["Mia/shocked"], "New emotional beat uses the active character's timbre")
	await wait(0.3)
	audio._last_blip_ms = -10000
	audio.play_dialogue_blip("Mia", "shocked", 3, workspace)
	check(not audio._reaction_active and audio.dialogue_player.stream == audio._voice_streams.Mia, "Regular speech resumes after reaction")
	workspace._reveal_line()
	workspace.show_story(lines, "SKIP BEFORE START")
	workspace._reveal_line()
	workspace._process(0.5)
	check(reaction_requests == 2, "Skipping before first frame cannot play a delayed reaction")
	workspace.show_story(lines, "OVERLAY")
	workspace._review_open = true
	workspace._process(0.1)
	check(reaction_requests == 2, "Log view never starts reaction")
	workspace._review_open = false
	workspace.configure_speech_blips("mod_01", 2)
	workspace._process(0.1)
	check(reaction_requests == 2, "Disabling pilot clears pending reaction")
	for setting: String in ["dialogue_blips_enabled", "sound_enabled", "sfx_volume", "master_volume", "text_speed"]:
		var previous: Variant = settings.get(setting)
		settings.set(setting, "instant" if setting == "text_speed" else (false if previous is bool else 0))
		audio._last_reaction_ms = -10000
		audio.play_dialogue_reaction("Alex", "shocked", workspace)
		check(not audio.dialogue_player.playing, "Reaction respects " + setting)
		settings.set(setting, previous)
	audio._last_reaction_ms = -10000
	audio.play_dialogue_reaction("Ms. Reyes", "relieved", workspace)
	settings.dialogue_blips_enabled = false
	audio._apply_buses()
	check(not audio.dialogue_player.playing, "Muting stops an in-flight reaction")
	settings.dialogue_blips_enabled = true
	audio._apply_buses()
	audio._last_reaction_ms = -10000
	audio.play_dialogue_reaction("Ms. Reyes", "relieved", workspace)
	workspace.free()
	check(not audio.dialogue_player.playing, "Scene cleanup stops reaction")
	if "--voice-preview" in OS.get_cmdline_user_args():
		var bytes: PackedByteArray = PackedByteArray()
		bytes.resize(audio.BLIP_RATE * 7 * 2)
		bytes.fill(0)
		var index: int = 0
		for emotion: String in ["shocked", "worried", "frustrated", "sad", "relieved", "determined"]:
			var stream: AudioStreamWAV = audio._reaction_streams["Alex/" + emotion]
			var start: int = int((0.25 + index) * audio.BLIP_RATE)
			for sample: int in stream.data.size() / 2:
				bytes.encode_s16((start + sample) * 2, int(stream.data.decode_s16(sample * 2) * db_to_linear(-6.0) * 0.70 * 0.80))
			index += 1
		var preview: AudioStreamWAV = AudioStreamWAV.new()
		preview.format = AudioStreamWAV.FORMAT_16_BITS
		preview.mix_rate = audio.BLIP_RATE
		preview.data = bytes
		check(preview.save_to_wav("res://.godot/dialogue-reactions-preview.wav") == OK, "Reaction audition exported")
