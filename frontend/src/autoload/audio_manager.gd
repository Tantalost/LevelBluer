extends Node
## Persistent UI audio: two music decks and a bounded, rate-limited SFX pool.
const BGM_PATH: String = "res://assets/audio/bgm/"
const SFX_PATH: String = "res://assets/audio/sfx/"
const MUSIC_GAIN: float = 0.7
const SOUND_IDS: PackedStringArray = ["ui_click", "ui_confirm", "ui_transition", "ui_notification", "ui_success", "ui_error", "loading_ready"]

@onready var bgm_player: AudioStreamPlayer = $BGMPlayer
@onready var sfx_pool: Node = $SFXPool
var hub_track: AudioStream
## Reserved for existing combat callers; this milestone does not add battle music.
var level_track: AudioStream
var _tracks: Dictionary[String, AudioStream] = {}
var _sounds: Dictionary[String, AudioStream] = {}
var _last_sound: Dictionary[String, int] = {}
var _decks: Array[AudioStreamPlayer] = []
var _desired_bgm: AudioStream
var _bgm_tween: Tween
var _screen_id: StringName = &"intro"
var _dashboard_mode: StringName = &"SOLO"
var _route_queued: bool = false
var _focus_lost: bool = false
var _app_paused: bool = false
var _steal_index: int = 0

func _ready() -> void:
	_decks = [$BGMPlayer, $BGMPlayerB]
	for key: String in ["loading", "hub", "pvp", "study"]:
		var stream: AudioStreamOggVorbis = load(BGM_PATH + key + ".ogg") as AudioStreamOggVorbis
		if stream != null:
			stream.loop = true
			_tracks[key] = stream
	hub_track = _tracks.get("hub") as AudioStream
	for key: String in SOUND_IDS:
		var stream: AudioStream = load(SFX_PATH + key + ".wav") as AudioStream
		if stream != null:
			_sounds[key] = stream
	SettingsService.settings_changed.connect(_apply_buses)
	Router.screen_changed.connect(_on_screen_changed)
	get_tree().node_added.connect(_on_node_added)
	_bind_existing.call_deferred(get_tree().root)
	_apply_buses()

func _bind_existing(node: Node) -> void:
	_on_node_added(node)
	for child: Node in node.get_children():
		_bind_existing(child)

func _on_node_added(node: Node) -> void:
	if node is BaseButton or node is HudGeoButton:
		var callback: Callable = _on_ui_pressed.bind(node)
		if not node.is_connected("pressed", callback):
			node.connect("pressed", callback)
	if node.has_signal("mode_switch_finished") and not node.is_connected("mode_switch_finished", _on_dashboard_mode):
		_dashboard_mode = &"SOLO"
		node.connect("mode_switch_finished", _on_dashboard_mode)

func _on_ui_pressed(button: Control) -> void:
	if not button.is_visible_in_tree() or (button is BaseButton and (button as BaseButton).disabled):
		return
	play_sfx(str(button.get_meta("ui_sound", "ui_click")))

func play_sfx(sfx_id: String) -> void:
	if _screen_id == &"intro" or _suspended() or not SettingsService.sound_enabled or SettingsService.sfx_volume <= 0 or SettingsService.master_volume <= 0:
		return
	if not _sounds.has(sfx_id):
		return
	var now: int = Time.get_ticks_msec()
	var cooldown: int = 55 if sfx_id == "ui_click" else 120
	if now - _last_sound.get(sfx_id, -10000) < cooldown:
		return
	_last_sound[sfx_id] = now
	var player: AudioStreamPlayer = _next_sfx_player()
	if player == null:
		return
	player.stream = _sounds[sfx_id]
	player.play()

func _next_sfx_player() -> AudioStreamPlayer:
	var children: Array[Node] = sfx_pool.get_children()
	for child: Node in children:
		var player: AudioStreamPlayer = child as AudioStreamPlayer
		if player != null and not player.playing:
			return player
	if children.is_empty():
		return null
	var stolen: AudioStreamPlayer = children[_steal_index % children.size()] as AudioStreamPlayer
	_steal_index += 1
	stolen.stop()
	return stolen

func _on_screen_changed(screen_id: StringName) -> void:
	_screen_id = screen_id
	# Router may replace Dashboard and push a child in one operation. Use its final route.
	if not _route_queued:
		_route_queued = true
		_commit_screen_audio.call_deferred()

func _commit_screen_audio() -> void:
	_route_queued = false
	if _screen_id not in [&"intro", &"splash", &"asset_loading"]:
		play_sfx("ui_transition")
	_select_music()

func _on_dashboard_mode(mode: StringName) -> void:
	_dashboard_mode = mode
	if _screen_id == &"dashboard":
		play_sfx("ui_confirm")
		_select_music()

func _select_music() -> void:
	match _screen_id:
		&"intro":
			_desired_bgm = null
			_kill_bgm_tween()
			_stop_music()
			_stop_effects()
		&"gameplay", &"pvp_battle": play_bgm(null)
		&"splash", &"asset_loading": play_bgm(_tracks.get("loading"))
		&"lessons", &"lesson_player", &"school_content", &"pretest", &"codex": play_bgm(_tracks.get("study"))
		&"login", &"password_change": play_bgm(hub_track)
		_: play_bgm(_tracks.get("pvp" if _dashboard_mode == &"PVP" else "hub"))

func play_bgm(stream: AudioStream, crossfade_time: float = 0.65) -> void:
	if stream == _desired_bgm and (stream == null or bgm_player.playing):
		return
	_desired_bgm = stream
	_kill_bgm_tween()
	if not SettingsService.music_enabled:
		_stop_music()
		return
	var target: AudioStreamPlayer = null
	if stream != null:
		for deck: AudioStreamPlayer in _decks:
			if deck.stream == stream and deck.playing:
				target = deck
		if target == null:
			target = _decks[0] if _decks[0].volume_linear <= _decks[1].volume_linear else _decks[1]
			target.stop()
			target.stream = stream
			target.volume_linear = 0.0
			target.play()
			target.stream_paused = _suspended()
		bgm_player = target
	var duration: float = maxf(0.01, crossfade_time)
	_bgm_tween = create_tween().set_parallel(true)
	_bgm_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	for deck: AudioStreamPlayer in _decks:
		_bgm_tween.tween_property(deck, "volume_linear", MUSIC_GAIN if deck == target else 0.0, duration)
		if deck != target:
			_bgm_tween.tween_callback(deck.stop).set_delay(duration)
	if _suspended():
		_bgm_tween.pause()

func _stop_music() -> void:
	for deck: AudioStreamPlayer in _decks:
		deck.stop()
		deck.volume_linear = 0.0

func _kill_bgm_tween() -> void:
	if _bgm_tween != null and _bgm_tween.is_valid():
		_bgm_tween.kill()
	_bgm_tween = null

func _apply_buses() -> void:
	_set_bus("Master", SettingsService.master_volume, false)
	_set_bus("BGM", SettingsService.music_volume, not SettingsService.music_enabled)
	_set_bus("SFX", SettingsService.sfx_volume, not SettingsService.sound_enabled)
	if not SettingsService.sound_enabled or SettingsService.sfx_volume <= 0 or SettingsService.master_volume <= 0:
		_stop_effects()
	if not SettingsService.music_enabled:
		_kill_bgm_tween()
		_stop_music()
	elif _desired_bgm != null and not bgm_player.playing:
		play_bgm(_desired_bgm)

func _set_bus(bus_name: String, percent: int, muted: bool) -> void:
	var index: int = AudioServer.get_bus_index(bus_name)
	if index >= 0:
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(0.0001, clampf(percent / 100.0, 0.0, 1.0))))
		AudioServer.set_bus_mute(index, muted or percent <= 0)

func _stop_effects() -> void:
	for child: Node in sfx_pool.get_children():
		(child as AudioStreamPlayer).stop()

func _suspended() -> bool:
	return _focus_lost or _app_paused

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT: _focus_lost = true
		NOTIFICATION_APPLICATION_FOCUS_IN: _focus_lost = false
		NOTIFICATION_APPLICATION_PAUSED: _app_paused = true
		NOTIFICATION_APPLICATION_RESUMED: _app_paused = false
		_: return
	if not is_node_ready():
		return
	for deck: AudioStreamPlayer in _decks:
		deck.stream_paused = _suspended()
	if _suspended():
		_stop_effects()
	if _bgm_tween != null and _bgm_tween.is_valid():
		if _suspended(): _bgm_tween.pause()
		else: _bgm_tween.play()

func _exit_tree() -> void:
	_kill_bgm_tween()
