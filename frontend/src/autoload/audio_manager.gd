extends Node
## Autoload singleton, registered as "AudioManager".
## Pooled SFX players so overlapping combat/UI cues are not cut off.

const MAX_PLAYERS: int = 8

var _sfx_players: Array[AudioStreamPlayer] = []


func _ready() -> void:
	for i in MAX_PLAYERS:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		_sfx_players.append(player)


func play_sfx(stream: AudioStream) -> void:
	if stream == null:
		return
	if not SettingsService.sound_enabled:
		return
	if SettingsService.sfx_volume <= 0:
		return
	var volume_linear: float = clampf(float(SettingsService.sfx_volume) / 100.0, 0.0, 1.0)
	var idle: AudioStreamPlayer = _next_idle_player()
	idle.volume_db = linear_to_db(volume_linear)
	idle.stream = stream
	idle.play()


func _next_idle_player() -> AudioStreamPlayer:
	for i in _sfx_players.size():
		var player: AudioStreamPlayer = _sfx_players[i]
		if not player.playing:
			return player
	return _sfx_players[0]
