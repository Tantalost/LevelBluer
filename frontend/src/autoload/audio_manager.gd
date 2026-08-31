extends Node
## Autoload singleton, registered as "AudioManager".
## One BGM player + an 8-voice SFX pool on dedicated buses.

const HUB_BGM_PATH := "res://assets/audio/bgm/hub_track.ogg"
const LEVEL_BGM_PATH := "res://assets/audio/bgm/level_track.ogg"
const SFX_CLICK_PATH := "res://assets/audio/sfx/ui_click.wav"
const SFX_SHOOT_PATH := "res://assets/audio/sfx/shoot.wav"
const SFX_EXPLOSION_PATH := "res://assets/audio/sfx/explosion.wav"

@onready var bgm_player: AudioStreamPlayer = $BGMPlayer
@onready var sfx_pool: Node = $SFXPool

var hub_track: AudioStream = null
var level_track: AudioStream = null
var _sounds: Dictionary = {}
var _steal_index: int = 0
var _bgm_tween: Tween = null
var _pending_bgm: AudioStream = null


func _ready() -> void:
	# Drop files at the paths below, then uncomment (or leave the exists-load).
	# _sounds["ui_click"] = preload("res://assets/audio/sfx/ui_click.wav")
	# _sounds["shoot"] = preload("res://assets/audio/sfx/shoot.wav")
	# _sounds["explosion"] = preload("res://assets/audio/sfx/explosion.wav")
	# hub_track = preload("res://assets/audio/bgm/hub_track.ogg")
	# level_track = preload("res://assets/audio/bgm/level_track.ogg")
	_bind_sfx("ui_click", SFX_CLICK_PATH)
	_bind_sfx("shoot", SFX_SHOOT_PATH)
	_bind_sfx("explosion", SFX_EXPLOSION_PATH)
	hub_track = _try_load_stream(HUB_BGM_PATH)
	level_track = _try_load_stream(LEVEL_BGM_PATH)
	_apply_buses()
	SettingsService.settings_changed.connect(_apply_buses)
	Router.screen_changed.connect(_on_screen_changed)
	var tree: SceneTree = get_tree()
	if tree != null:
		tree.node_added.connect(_on_node_added)


func play_bgm(stream: AudioStream, crossfade_time: float = 1.0) -> void:
	if stream == null:
		return
	if not SettingsService.music_enabled:
		bgm_player.stop()
		return
	if bgm_player.stream == stream and bgm_player.playing and _pending_bgm == null:
		return
	_pending_bgm = stream
	_kill_bgm_tween()
	var fade: float = maxf(0.0, crossfade_time)
	if fade <= 0.0 or not bgm_player.playing:
		_start_bgm(stream)
		return
	_bgm_tween = create_tween()
	_bgm_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_bgm_tween.tween_property(bgm_player, "volume_db", -40.0, fade * 0.45)
	_bgm_tween.tween_callback(_swap_bgm)
	_bgm_tween.tween_property(bgm_player, "volume_db", _bgm_volume_db(), fade * 0.55)


func play_sfx(sfx_id: String) -> void:
	if not SettingsService.sound_enabled:
		return
	if not _sounds.has(sfx_id):
		return
	var stream: AudioStream = _sounds[sfx_id] as AudioStream
	if stream == null:
		return
	var player: AudioStreamPlayer = _next_sfx_player()
	if player == null:
		return
	player.stream = stream
	player.play()


func _on_screen_changed(screen_id: StringName) -> void:
	if screen_id == &"gameplay":
		return
	if screen_id == &"intro" or screen_id == &"splash":
		return
	play_bgm(hub_track)


func _on_node_added(node: Node) -> void:
	var button: BaseButton = node as BaseButton
	if button == null:
		return
	if button.pressed.is_connected(_on_ui_pressed):
		return
	button.pressed.connect(_on_ui_pressed)


func _on_ui_pressed() -> void:
	play_sfx("ui_click")


func _bind_sfx(sfx_id: String, path: String) -> void:
	var stream: AudioStream = _try_load_stream(path)
	if stream != null:
		_sounds[sfx_id] = stream


func _try_load_stream(path: String) -> AudioStream:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as AudioStream


func _start_bgm(stream: AudioStream) -> void:
	bgm_player.stream = stream
	bgm_player.volume_db = _bgm_volume_db()
	bgm_player.play()
	_pending_bgm = null


func _swap_bgm() -> void:
	var stream: AudioStream = _pending_bgm
	_pending_bgm = null
	if stream == null:
		return
	bgm_player.stream = stream
	bgm_player.play()


func _next_sfx_player() -> AudioStreamPlayer:
	var kids: Array = sfx_pool.get_children()
	for i in kids.size():
		var player: AudioStreamPlayer = kids[i] as AudioStreamPlayer
		if player != null and not player.playing:
			return player
	if kids.is_empty():
		return null
	var stolen: AudioStreamPlayer = kids[_steal_index] as AudioStreamPlayer
	_steal_index = (_steal_index + 1) % kids.size()
	if stolen != null:
		stolen.stop()
	return stolen


func _apply_buses() -> void:
	_set_bus_volume("Master", SettingsService.master_volume)
	_set_bus_volume("BGM", 100 if SettingsService.music_enabled else 0)
	_set_bus_volume("SFX", SettingsService.sfx_volume if SettingsService.sound_enabled else 0)
	_mute_bus("BGM", not SettingsService.music_enabled)
	_mute_bus("SFX", not SettingsService.sound_enabled)
	if not SettingsService.music_enabled:
		bgm_player.stop()
		return
	if bgm_player.stream != null and not bgm_player.playing:
		bgm_player.play()
	if bgm_player.playing:
		bgm_player.volume_db = _bgm_volume_db()


func _set_bus_volume(bus_name: String, percent: int) -> void:
	var index: int = AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	var lin: float = clampf(float(percent) / 100.0, 0.0, 1.0)
	if lin <= 0.0:
		AudioServer.set_bus_volume_db(index, -80.0)
		return
	AudioServer.set_bus_volume_db(index, linear_to_db(lin))


func _mute_bus(bus_name: String, muted: bool) -> void:
	var index: int = AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	AudioServer.set_bus_mute(index, muted)


func _bgm_volume_db() -> float:
	return 0.0


func _kill_bgm_tween() -> void:
	if _bgm_tween != null and _bgm_tween.is_valid():
		_bgm_tween.kill()
	_bgm_tween = null
