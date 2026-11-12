extends AudioStreamPlayer
## One scene-owned voice channel. A new cue detaches this player from any outstanding request.
## Recordings persist in cache_dir keyed by their full versioned path, so each version downloads once.
const BASE_URL: String = "https://res.cloudinary.com/nfd5bhkz/video/upload/"
const MAX_BYTES: int = 2 * 1024 * 1024
static var cache_dir: String = "user://voice"
static var base_url: String = BASE_URL
## One request per path for every player; it lives under the tree root so leaving a screen never cuts a download short.
static var _downloads: Dictionary[String, HTTPRequest] = {}
var _request: HTTPRequest
var _waiting: Callable = Callable()
var _cache: Dictionary[String, AudioStream] = {}
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
	if not _cache.has(path):
		var stored: AudioStream = cached_stream(path)
		if stored == null:
			_fetch(path, true)
			return
		_cache[path] = stored
	_play_stream(_cache[path])

func _fetch(path: String, can_retry: bool) -> void:
	_request = download(path)
	_waiting = _received.bind(_request, path, can_retry)
	_request.request_completed.connect(_waiting, CONNECT_ONE_SHOT)

## The single in-flight request for path, started if needed. It stores a valid body even after every listener detaches.
static func download(path: String, timeout: float = 6.0) -> HTTPRequest:
	var existing: Variant = _downloads.get(path)
	if is_instance_valid(existing):
		return existing as HTTPRequest
	var request: HTTPRequest = HTTPRequest.new()
	request.timeout = timeout
	request.body_size_limit = MAX_BYTES
	_downloads[path] = request
	request.request_completed.connect(_downloaded.bind(path, request), CONNECT_ONE_SHOT)
	(Engine.get_main_loop() as SceneTree).root.add_child.call_deferred(request)
	_start_download.call_deferred(request, path)
	return request

static func _start_download(request: HTTPRequest, path: String) -> void:
	if is_instance_valid(request) and request.request(base_url + path) != OK:
		request.request_completed.emit(HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray())

static func _downloaded(result: int, status: int, _headers: PackedStringArray, body: PackedByteArray, path: String, request: HTTPRequest) -> void:
	if _downloads.get(path) == request:
		_downloads.erase(path)
	request.queue_free()
	if result == HTTPRequest.RESULT_SUCCESS and status == 200:
		store_download(path, body)

func _received(result: int, status: int, _headers: PackedStringArray, body: PackedByteArray, source: HTTPRequest, path: String, can_retry: bool) -> void:
	if source != _request:
		return
	_request = null
	_waiting = Callable()
	if result != HTTPRequest.RESULT_SUCCESS or status != 200 or body.is_empty():
		if can_retry and audible() and (result in [HTTPRequest.RESULT_CONNECTION_ERROR, HTTPRequest.RESULT_TIMEOUT, HTTPRequest.RESULT_NO_RESPONSE] or status >= 500):
			if _downloads.get(path) == source:
				_downloads.erase(path)
			_fetch(path, false)
		return
	# Storage can be unwritable; the validated body still plays for this session.
	var clip: AudioStream = cached_stream(path)
	if clip == null:
		clip = decode(path, body)
	if clip != null:
		_cache[path] = clip
		_play_stream(clip)

static func cache_file(path: String) -> String:
	return cache_dir.path_join("%s_%s" % [path.sha256_text(), path.get_file()])

## A cached file that no longer decodes is removed, so the next request fetches it once more.
static func cached_stream(path: String) -> AudioStream:
	var file: String = cache_file(path)
	if not FileAccess.file_exists(file):
		return null
	var stream: AudioStream = decode(path, FileAccess.get_file_as_bytes(file))
	if stream == null:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
	return stream

static func decode(path: String, body: PackedByteArray) -> AudioStream:
	if body.is_empty() or body.size() > MAX_BYTES:
		return null
	var stream: AudioStream = AudioStreamWAV.load_from_buffer(body) if path.get_extension().to_lower() == "wav" else AudioStreamMP3.load_from_buffer(body)
	return stream if stream != null and stream.get_length() > 0.0 else null

## Only a body that decodes is written: temporary file, read-back comparison, then rename into place.
static func store_download(path: String, body: PackedByteArray) -> AudioStream:
	var stream: AudioStream = decode(path, body)
	if stream == null:
		return null
	var file: String = cache_file(path)
	var temp: String = file + ".tmp"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(cache_dir))
	var out: FileAccess = FileAccess.open(temp, FileAccess.WRITE)
	if out == null:
		return stream
	var written: bool = out.store_buffer(body)
	out.close()
	if written and FileAccess.get_file_as_bytes(temp) == body:
		if FileAccess.file_exists(file):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
		if DirAccess.rename_absolute(ProjectSettings.globalize_path(temp), ProjectSettings.globalize_path(file)) == OK:
			return stream
	DirAccess.remove_absolute(ProjectSettings.globalize_path(temp))
	return stream

func _play_stream(clip: AudioStream) -> void:
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

## Detaches from the shared download; it still completes and caches for the next request.
func clear_clip() -> void:
	stop()
	stream_paused = false
	_update_mix()
	if _request != null:
		if is_instance_valid(_request) and _waiting.is_valid() and _request.request_completed.is_connected(_waiting):
			_request.request_completed.disconnect(_waiting)
		_request = null
		_waiting = Callable()

func _exit_tree() -> void:
	clear_clip()
