extends Node
## Persistent UI audio: two music decks and a bounded, rate-limited SFX pool.
const BGM_PATH: String = "res://assets/audio/bgm/"
const SFX_PATH: String = "res://assets/audio/sfx/"
const MUSIC_GAIN: float = 0.7
const SOUND_IDS: PackedStringArray = ["ui_click", "ui_confirm", "ui_transition", "ui_notification", "ui_success", "ui_error", "loading_ready"]

@onready var bgm_player: AudioStreamPlayer = $BGMPlayer
@onready var sfx_pool: Node = $SFXPool
@onready var dialogue_player: AudioStreamPlayer = $DialoguePlayer
const BLIP_RATE: int = 22050
const BLIP_DURATION: float = 0.055
const BLIP_INTERVAL_MS: int = 95
const VOICE_PROFILES: Dictionary = {
	"Alex": {"hz": 230.0, "third": 0.26, "second": 0.08},
	"Mia": {"hz": 320.0, "third": 0.16, "second": 0.20},
	"Ms. Reyes": {"hz": 175.0, "third": -0.12, "second": 0.06},
	"Leah": {"hz": 275.0, "third": 0.08, "second": -0.18},
}
var _voice_streams: Dictionary[String, AudioStreamWAV] = {}
var _dialogue_owner: WeakRef
var _last_blip_ms: int = -10000
const REACTION_PROFILES: Dictionary = {
	"shocked": {"duration": 0.18, "start": 1.0, "end": 1.65, "pulses": 1, "wobble": 0.0},
	"worried": {"duration": 0.24, "start": 1.05, "end": 0.9, "pulses": 1, "wobble": 0.07},
	"frustrated": {"duration": 0.22, "start": 0.98, "end": 0.78, "pulses": 2, "wobble": 0.0},
	"sad": {"duration": 0.28, "start": 1.0, "end": 0.65, "pulses": 1, "wobble": 0.02},
	"relieved": {"duration": 0.25, "start": 1.15, "end": 0.86, "pulses": 1, "wobble": 0.0},
	"determined": {"duration": 0.20, "start": 0.85, "end": 1.08, "pulses": 2, "wobble": 0.0},
}
const REACTION_INTERVAL_MS: int = 1200
var _reaction_streams: Dictionary[String, AudioStreamWAV] = {}
var _reaction_active: bool = false
var _last_reaction_ms: int = -10000
var _opening_laugh: AudioStreamWAV
var _opening_cues: Dictionary[String, AudioStreamWAV] = {}
var _opening_owner: WeakRef
var _opening_morning: bool = false
var _opening_paused: bool = false
var _opening_score: bool = false
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
	for speaker: String in VOICE_PROFILES:
		_voice_streams[speaker] = _synthesize_blip(VOICE_PROFILES[speaker])
		for emotion: String in REACTION_PROFILES:
			_reaction_streams[speaker + "/" + emotion] = _synthesize_reaction(VOICE_PROFILES[speaker], REACTION_PROFILES[emotion])
	dialogue_player.finished.connect(func() -> void: _reaction_active = false)
	_decks = [$BGMPlayer, $BGMPlayerB]
	for key: String in ["loading", "hub", "pvp", "study"]:
		var stream: AudioStreamOggVorbis = load(BGM_PATH + key + ".ogg") as AudioStreamOggVorbis
		if stream != null:
			stream.loop = true
			_tracks[key] = stream
	hub_track = _tracks.get("hub") as AudioStream
	var morning: AudioStreamWAV = load(BGM_PATH + "morning.wav") as AudioStreamWAV
	if morning != null:
		morning.loop_mode = AudioStreamWAV.LOOP_FORWARD
		morning.loop_begin = 0
		morning.loop_end = int(morning.get_length() * morning.mix_rate)
		_tracks["morning"] = morning
	for key: String in ["alarm", "thump", "shuffle", "takeover", "meeting", "montage", "closing", "rewind"]:
		_opening_cues[key] = load(SFX_PATH + "opening_" + key + ".wav") as AudioStreamWAV
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
	stop_dialogue_blips()
	_screen_id = screen_id
	if screen_id != &"opening":
		_opening_owner = null
		_opening_morning = false
		_opening_paused = false
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
		&"gameplay", &"pvp_battle", &"pvp_online": play_bgm(null)
		&"splash", &"asset_loading": play_bgm(_tracks.get("loading"))
		&"opening": play_bgm(_tracks.get("morning") if _opening_morning else null)
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
			target.stream_paused = _music_paused()
		bgm_player = target
	var duration: float = maxf(0.01, crossfade_time)
	_bgm_tween = create_tween().set_parallel(true)
	_bgm_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	for deck: AudioStreamPlayer in _decks:
		_bgm_tween.tween_property(deck, "volume_linear", MUSIC_GAIN if deck == target else 0.0, duration)
		if deck != target:
			_bgm_tween.tween_callback(deck.stop).set_delay(duration)
	if _music_paused():
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
	if _screen_id != &"opening" and (not SettingsService.dialogue_blips_enabled or SettingsService.text_speed == "instant"):
		stop_dialogue_blips()
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
	stop_dialogue_blips()
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
		deck.stream_paused = _music_paused()
	if _suspended():
		_stop_effects()
	if _bgm_tween != null and _bgm_tween.is_valid():
		if _music_paused(): _bgm_tween.pause()
		else: _bgm_tween.play()

func _exit_tree() -> void:
	_kill_bgm_tween()

func _synthesize_blip(profile: Dictionary) -> AudioStreamWAV:
	# Original, soft-edged chip timbres, made once at startup. No sampled voices.
	# 16-bit storage retains a clean fade around a deliberately quantized waveform.
	var count: int = int(BLIP_RATE * BLIP_DURATION)
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(count * 2)
	for i: int in count:
		var time: float = float(i) / BLIP_RATE
		var phase: float = TAU * float(profile.hz) * time
		var wave: float = sin(phase) + float(profile.third) * sin(3.0 * phase) + float(profile.second) * sin(2.0 * phase)
		wave = roundf(wave * 24.0) / 24.0
		var envelope: float = minf(1.0, float(i) / (BLIP_RATE * 0.006)) * minf(1.0, float(count - 1 - i) / (BLIP_RATE * 0.014))
		bytes.encode_s16(i * 2, int(clampf(wave * envelope * 0.30, -1.0, 1.0) * 32767.0))
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = BLIP_RATE
	stream.data = bytes
	return stream

func _dialogue_allowed(source: Control) -> bool:
	if _screen_id != &"gameplay" or _suspended() or get_tree().paused or not is_instance_valid(source) or not source.is_visible_in_tree() or not source.can_process():
		return false
	if not SettingsService.dialogue_blips_enabled or not SettingsService.sound_enabled or SettingsService.sfx_volume <= 0 or SettingsService.master_volume <= 0 or SettingsService.text_speed == "instant":
		return false
	return true

func play_dialogue_blip(speaker: String, emotion: String, letter_index: int, source: Control) -> void:
	if not _dialogue_allowed(source) or (_reaction_active and dialogue_player.playing):
		return
	if not _voice_streams.has(speaker):
		return # Narrators and unapproved cast stay silent.
	var now: int = Time.get_ticks_msec()
	if now - _last_blip_ms < BLIP_INTERVAL_MS:
		return # No catch-up bursts, even at fast text speed or after a frame stall.
	_last_blip_ms = now
	_dialogue_owner = weakref(source)
	var expression: float = 1.0
	match emotion:
		"worried", "scared", "shocked": expression = 1.04
		"sad", "crying": expression = 0.96
		"determined", "angry", "frustrated": expression = 1.02
	var variation: float = [-0.012, 0.0, 0.012, 0.0][posmod(letter_index, 4)]
	dialogue_player.pitch_scale = expression + variation
	dialogue_player.stream = _voice_streams[speaker]
	dialogue_player.play()

func _reaction_kind(emotion: String) -> String:
	match emotion:
		"scared": return "worried"
		"crying": return "sad"
		"angry": return "frustrated"
	return emotion

func play_dialogue_reaction(speaker: String, emotion: String, source: Control) -> void:
	var key: String = speaker + "/" + _reaction_kind(emotion)
	if not _dialogue_allowed(source) or not _reaction_streams.has(key):
		return
	var now: int = Time.get_ticks_msec()
	if now - _last_reaction_ms < REACTION_INTERVAL_MS:
		return # Repeated taps/rapid emotion changes never build a noisy queue.
	_last_reaction_ms = now
	_last_blip_ms = now
	_dialogue_owner = weakref(source)
	_reaction_active = true
	dialogue_player.pitch_scale = 1.0
	dialogue_player.stream = _reaction_streams[key]
	dialogue_player.play()

func _synthesize_reaction(voice: Dictionary, reaction: Dictionary) -> AudioStreamWAV:
	# Short nonverbal chip inflections, not copied samples or spoken interjections.
	var duration: float = float(reaction.duration)
	var count: int = int(duration * BLIP_RATE)
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(count * 2)
	var phase: float = 0.0
	var pulse_length: float = duration / int(reaction.pulses)
	for i: int in count:
		var time: float = float(i) / BLIP_RATE
		var pitch: float = lerpf(float(reaction.start), float(reaction.end), time / duration)
		pitch += float(reaction.wobble) * sin(TAU * 9.0 * time)
		phase += TAU * float(voice.hz) * pitch / BLIP_RATE
		var wave: float = sin(phase) + float(voice.third) * sin(phase * 3.0) + float(voice.second) * sin(phase * 2.0)
		wave = roundf(wave * 24.0) / 24.0
		var pulse_time: float = fposmod(time, pulse_length)
		var envelope: float = minf(1.0, pulse_time / 0.012) * clampf((pulse_length - pulse_time) / 0.045, 0.0, 1.0)
		if i == count - 1: envelope = 0.0
		bytes.encode_s16(i * 2, int(wave * envelope * 0.26 * 32767.0))
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = BLIP_RATE
	stream.data = bytes
	return stream

func stop_dialogue_blips(source: Control = null) -> void:
	if source != null and (_dialogue_owner == null or _dialogue_owner.get_ref() != source):
		return # An old workspace cannot stop a newer speaker's sound.
	if is_instance_valid(dialogue_player):
		dialogue_player.stop()
		dialogue_player.stream_paused = false
	_opening_score = false
	_dialogue_owner = null
	_reaction_active = false


func play_opening_laugh(source: Control) -> void:
	# A source-owned, nonverbal SFX, independent of text-speed/blip preferences.
	# Reuse the dialogue player so route changes, focus loss and mute stop it.
	if not _opening_cue_allowed(source):
		return
	if _opening_laugh == null:
		_opening_laugh = _synthesize_robot_laugh()
	stop_dialogue_blips()
	_dialogue_owner = weakref(source)
	_reaction_active = true
	dialogue_player.pitch_scale = 1.0
	dialogue_player.stream = _opening_laugh
	dialogue_player.play()


func _opening_cue_allowed(source: Control) -> bool:
	return _screen_id == &"opening" and not _opening_paused and not _suspended() and not get_tree().paused and is_instance_valid(source) and source.is_visible_in_tree() and source.can_process() and SettingsService.sound_enabled and SettingsService.sfx_volume > 0 and SettingsService.master_volume > 0


func play_opening_cue(cue: String, source: Control) -> void:
	if not _opening_cue_allowed(source) or not _opening_cues.has(cue):
		return
	stop_dialogue_blips()
	_dialogue_owner = weakref(source)
	_reaction_active = true
	dialogue_player.pitch_scale = 1.0
	dialogue_player.stream = _opening_cues[cue]
	dialogue_player.play()


func play_opening_score(cue: String, source: Control, at: float = 0.0) -> void:
	if not _opening_cue_allowed(source) or not _opening_cues.has(cue):
		return
	stop_dialogue_blips()
	_dialogue_owner = weakref(source)
	_opening_score = true
	_reaction_active = true
	dialogue_player.pitch_scale = 1.0
	dialogue_player.stream = _opening_cues[cue]
	dialogue_player.play(at)


func cut_opening_audio(source: Control) -> void:
	if _opening_owner == null or _opening_owner.get_ref() != source:
		return
	_opening_morning = false
	_desired_bgm = null
	_kill_bgm_tween()
	_stop_music()
	_stop_effects()


func set_opening_morning(source: Control, morning: bool) -> void:
	if not is_instance_valid(source) or not source.is_inside_tree():
		return
	# on_enter runs before Router emits screen_changed; remember this request.
	_opening_owner = weakref(source)
	_opening_morning = morning
	if _screen_id == &"opening":
		_select_music()


func pause_opening_audio(source: Control, value: bool) -> void:
	if _opening_owner == null or _opening_owner.get_ref() != source:
		return
	_opening_paused = value
	if _opening_score:
		dialogue_player.stream_paused = value or _suspended()
	elif value:
		stop_dialogue_blips(source)
	for deck: AudioStreamPlayer in _decks:
		deck.stream_paused = _music_paused()
	if _bgm_tween != null and _bgm_tween.is_valid():
		if _music_paused(): _bgm_tween.pause()
		else: _bgm_tween.play()


func release_opening_audio(source: Control) -> void:
	if _opening_owner == null or _opening_owner.get_ref() != source:
		return
	pause_opening_audio(source, false)
	stop_dialogue_blips(source)
	_opening_owner = null
	_opening_morning = false
	if _screen_id == &"opening":
		play_bgm(null)


func _music_paused() -> bool:
	return _suspended() or (_screen_id == &"opening" and _opening_paused)


func _synthesize_robot_laugh() -> AudioStreamWAV:
	# Five descending "ha" pulses, ring modulation and quantization; no samples.
	var count: int = int(BLIP_RATE * 1.65)
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(count * 2)
	var phase: float = 0.0
	for i: int in count:
		var time: float = float(i) / BLIP_RATE
		var pulse: int = mini(4, int(time / 0.33))
		var local_time: float = fposmod(time, 0.33)
		var hz: float = 175.0 - pulse * 13.0 + 42.0 * exp(-local_time * 18.0)
		phase += TAU * hz / BLIP_RATE
		var wave: float = sin(phase) + 0.35 * sin(phase * 3.0) + 0.18 * sin(phase * 7.0)
		wave *= 0.65 + 0.35 * sin(TAU * 38.0 * time)
		wave = roundf(wave * 14.0) / 14.0
		var envelope: float = clampf(local_time / 0.018, 0.0, 1.0) * clampf((0.25 - local_time) / 0.12, 0.0, 1.0)
		bytes.encode_s16(i * 2, int(clampf(wave * envelope * 0.24, -1.0, 1.0) * 32767.0))
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = BLIP_RATE
	stream.data = bytes
	return stream

func _process(_delta: float) -> void:
	if not dialogue_player.playing:
		return
	var source: Control = _dialogue_owner.get_ref() as Control if _dialogue_owner != null else null
	if get_tree().paused or source == null or not source.is_visible_in_tree() or not source.can_process():
		stop_dialogue_blips()
