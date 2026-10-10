extends SceneTree
var failures: int = 0
var audio: Node
var settings: Node

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
	var old: Array = [settings.music_enabled, settings.sound_enabled, settings.music_volume, settings.sfx_volume, settings.master_volume]
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
	prefs.save_settings()
	prefs.music_volume = 99
	prefs.music_enabled = true
	prefs.sound_enabled = true
	prefs.load_settings()
	check(prefs.music_volume == 37 and not prefs.music_enabled and not prefs.sound_enabled, "Music volume and mute preferences round-trip")
	prefs.queue_free()
	# Opening Settings reads preferences without firing save handlers.
	var scene: PackedScene = load("res://src/ui/screens/settings/settings_screen.tscn") as PackedScene
	var panel: Control = scene.instantiate()
	root.add_child(panel)
	panel.on_enter({})
	check(panel._music_slider.value == settings.music_volume, "Music slider reflects saved preferences")
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
		if "--render" in OS.get_cmdline_user_args():
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.godot/audio_settings_%dx%d.png" % [dimensions.x, dimensions.y])
	panel.queue_free()
	settings.music_enabled = old[0]
	settings.sound_enabled = old[1]
	settings.music_volume = old[2]
	settings.sfx_volume = old[3]
	settings.master_volume = old[4]
	audio._on_screen_changed(&"intro")
	audio._apply_buses()
	await wait()
	print("[GAME AUDIO] failures=%d" % failures)
	quit(1 if failures else 0)
