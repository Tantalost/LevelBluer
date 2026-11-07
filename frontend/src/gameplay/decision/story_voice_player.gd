extends AudioStreamPlayer
## One scene-owned voice channel. A new cue invalidates any outstanding request.
const BASE_URL: String = "https://res.cloudinary.com/nfd5bhkz/video/upload/"
var _request: HTTPRequest
var _cache: Dictionary[String, AudioStreamMP3] = {}
var _suspended: bool = false
var _ducking: bool = false

func _ready() -> void:
	bus = &"SFX"
	finished.connect(_update_mix)
	SettingsService.settings_changed.connect(_update_mix)

func play_clip(path: String) -> void:
	clear_clip()
	if path.is_empty() or not audible():
		return
	if _cache.has(path):
		_play_stream(_cache[path])
		return
	_fetch(path, true)

func _fetch(path: String, can_retry: bool) -> void:
	_request = HTTPRequest.new()
	_request.timeout = 6.0
	_request.body_size_limit = 2 * 1024 * 1024
	add_child(_request)
	_request.request_completed.connect(_received.bind(_request, path, can_retry), CONNECT_ONE_SHOT)
	if _request.request(BASE_URL + path) != OK:
		clear_clip()

func _received(result: int, status: int, _headers: PackedStringArray, body: PackedByteArray, source: HTTPRequest, path: String, can_retry: bool) -> void:
	if source != _request:
		return
	_request = null
	source.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or status != 200 or body.is_empty():
		if can_retry and audible() and (result in [HTTPRequest.RESULT_CONNECTION_ERROR, HTTPRequest.RESULT_TIMEOUT, HTTPRequest.RESULT_NO_RESPONSE] or status >= 500):
			_fetch(path, false)
		return
	var clip: AudioStreamMP3 = AudioStreamMP3.load_from_buffer(body)
	if clip != null and clip.get_length() > 0.0:
		_cache[path] = clip
		_play_stream(clip)

func _play_stream(clip: AudioStreamMP3) -> void:
	stream = clip
	play()
	stream_paused = _suspended
	_update_mix()

func audible() -> bool:
	return SettingsService.sound_enabled and SettingsService.sfx_volume > 0 and SettingsService.master_volume > 0

func pending_or_playing() -> bool:
	return audible() and (_request != null or playing or stream_paused)

func suspend_clip(value: bool) -> void:
	_suspended = value
	if playing or stream_paused:
		stream_paused = value
	_update_mix()

func _update_mix() -> void:
	var lower_music: bool = playing and not _suspended and audible()
	if lower_music != _ducking:
		_ducking = lower_music
		AudioManager.set_story_duck(get_parent() as Control, 0.28 if _ducking else 1.0)

func clear_clip() -> void:
	stop()
	stream_paused = false
	_update_mix()
	if _request != null:
		var source: HTTPRequest = _request
		_request = null
		source.cancel_request()
		source.queue_free()

func _exit_tree() -> void:
	clear_clip()
