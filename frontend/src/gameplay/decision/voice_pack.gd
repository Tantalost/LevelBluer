extends RefCounted
## Student-started offline voice download. The verified files in StoryVoicePlayer.cache_dir are the
## only state, so a download interrupted by cancel, network loss or an app restart resumes with
## whatever is still missing. Playback reads the same files and never needs this object.
const VoicePlayer = preload("res://src/gameplay/decision/story_voice_player.gd")
const SELF: String = "res://src/gameplay/decision/voice_pack.gd"
const OPENING: String = "res://src/ui/screens/intro/student_opening.gd"
const MODULE_INTRO: String = "res://src/ui/screens/deploy/module_intro_screen.gd"
const OPENING_GROUP: String = "Opening"
## Module number -> beat list in module_intro_screen.gd.
const INTRO_BEATS: Dictionary[int, String] = {1: "BEATS", 2: "AMANI_BEATS", 3: "LIZA_BEATS", 4: "RHAM_BEATS", 5: "MIKA_BEATS"}
const CONCURRENCY: int = 3
const ATTEMPTS: int = 3
const TIMEOUT: float = 30.0
## Consecutive network failures with no success in between end the run instead of retrying every clip.
const OFFLINE_STREAK: int = 6
const TRANSIENT: Array[int] = [HTTPRequest.RESULT_CANT_CONNECT, HTTPRequest.RESULT_CANT_RESOLVE, HTTPRequest.RESULT_CONNECTION_ERROR, HTTPRequest.RESULT_NO_RESPONSE, HTTPRequest.RESULT_TIMEOUT]

signal progress_changed(done: int, total: int)
signal finished(failed: int, cancelled: bool)

## Main-thread time a pump may spend verifying already-cached clips before yielding a frame.
const PUMP_BUDGET_USEC: int = 8000

static var _shared: RefCounted
static var _pattern: RegEx
## Authored data is constant for a launch, so the manifest is built once.
static var _manifest: Dictionary[String, Array] = {}
static var _coverage: Dictionary[String, Dictionary] = {}
static var _paths: Array[String] = []
static var _names: Dictionary[String, String] = {}
## Path -> byte size for cached files that decoded during this run. Each file is decoded at most once per launch.
static var _verified: Dictionary[String, int] = {}

var running: bool = false
var failed: Array[String] = []
var _queue: Array[String] = []
var _active: Dictionary[String, HTTPRequest] = {}
var _listeners: Dictionary[String, Callable] = {}
var _attempts: Dictionary[String, int] = {}
var _done: int = 0
var _total: int = 0
var _streak: int = 0

static func shared() -> RefCounted:
	if _shared == null:
		_shared = (load(SELF) as GDScript).new() as RefCounted
	return _shared

## Group name -> versioned asset paths in authored order. Lines without a recording add nothing.
## The returned dictionary is shared; callers must not modify it.
static func manifest() -> Dictionary[String, Array]:
	if _manifest.is_empty():
		_manifest = _build_manifest()
	return _manifest

static func _build_manifest() -> Dictionary[String, Array]:
	var groups: Dictionary[String, Array] = {OPENING_GROUP: []}
	_coverage.clear()
	for module: int in range(1, 6):
		groups["Module %d" % module] = []
	var opening: Dictionary = (load(OPENING) as GDScript).get_script_constant_map()
	var clips: Array = []
	for url: Variant in (opening["VOICE_CLIPS"] as Dictionary).values():
		_collect(str(url).trim_prefix(VoicePlayer.BASE_URL), clips)
	_add_source(groups, OPENING_GROUP, OPENING_GROUP, clips)
	var intros: Dictionary = (load(MODULE_INTRO) as GDScript).get_script_constant_map()
	for module: int in INTRO_BEATS:
		clips = []
		_collect(intros.get(INTRO_BEATS[module], []), clips)
		_add_source(groups, "Module %d" % module, "Intro", clips)
	for id: String in PlayerManager.authored_story_ids():
		var definition: GDScript = PlayerManager.story_definition(id)
		var group: String = "Module %d" % id.substr(4, 2).to_int()
		if definition != null and groups.has(group):
			clips = []
			_collect(definition.get_script_constant_map(), clips)
			_add_source(groups, group, "Ch %d" % id.substr(10).to_int(), clips)
	return groups

static func _add_source(groups: Dictionary[String, Array], group: String, source: String, clips: Array) -> void:
	if not _coverage.has(group):
		_coverage[group] = {}
	(_coverage[group] as Dictionary)[source] = clips.size()
	for path: String in clips:
		if path not in groups[group]:
			groups[group].append(path)

## Group -> {source ("Opening", "Intro", "Ch N") -> recorded clips}. A source with 0 is unvoiced.
static func coverage() -> Dictionary[String, Dictionary]:
	manifest()
	return _coverage

## Readable list of voiced and unvoiced parts of a group, e.g. "voiced: Intro, Ch 1 · text only: Ch 2–5".
static func coverage_note(group: String) -> String:
	var voiced: PackedStringArray = []
	var silent: PackedStringArray = []
	var sources: Dictionary = coverage().get(group, {})
	for source: String in sources:
		if int(sources[source]) > 0: voiced.append(source)
		else: silent.append(source)
	if voiced.is_empty():
		return "text only"
	return "voiced: %s%s" % [", ".join(voiced), "" if silent.is_empty() else " · text only: " + ", ".join(silent)]

## Every distinct path across all groups; a clip shared by two groups downloads once.
static func paths() -> Array[String]:
	if _paths.is_empty():
		for group: Array in manifest().values():
			for path: String in group:
				if path not in _paths:
					_paths.append(path)
	return _paths.duplicate()

static func _collect(value: Variant, into: Array) -> void:
	if value is Dictionary:
		for item: Variant in (value as Dictionary).values():
			_collect(item, into)
	elif value is Array:
		for item: Variant in value as Array:
			_collect(item, into)
	elif value is String:
		if _pattern == null:
			_pattern = RegEx.create_from_string("^v\\d+/[^\\s\"]+\\.(mp3|wav)$")
		var path: String = value as String
		if _pattern.search(path) != null and path not in into:
			into.append(path)

## Counts a clip only while its cached file exists and decodes; an undecodable file is removed.
static func is_ready(path: String) -> bool:
	if not FileAccess.file_exists(VoicePlayer.cache_file(path)):
		_verified.erase(path)
		return false
	if _verified.has(path):
		return true
	if VoicePlayer.cached_stream(path) == null:
		return false
	_verified[path] = _size(path)
	return true

## Verified this run and still on disk. Never decodes. stored comes from _stored() when checking many paths.
static func known_ready(path: String, stored: Dictionary = {}) -> bool:
	if not _verified.has(path):
		return false
	var on_disk: bool = stored.has(_name(path)) if not stored.is_empty() else FileAccess.file_exists(VoicePlayer.cache_file(path))
	if on_disk:
		return true
	_verified.erase(path)
	return false

## Cached files not yet decoded this run; readiness() does not count them until scan() checks them.
static func unchecked() -> Array[String]:
	var stored: Dictionary = _stored()
	return paths().filter(func(path: String) -> bool: return not _verified.has(path) and stored.has(_name(path)))

## One directory listing instead of a file check per clip, so per-frame refreshes stay cheap.
static func _stored() -> Dictionary:
	var names: Dictionary = {}
	for file: String in DirAccess.get_files_at(VoicePlayer.cache_dir):
		names[file] = true
	return names

static func _name(path: String) -> String:
	if not _names.has(path):
		_names[path] = VoicePlayer.cache_file(path).get_file()
	return _names[path]

## Decodes unchecked cached files until budget_usec is spent, always at least one per call.
## Returns true once none remain.
static func scan(budget_usec: int) -> bool:
	var pending: Array[String] = unchecked()
	var deadline: int = Time.get_ticks_usec() + budget_usec
	for index: int in pending.size():
		is_ready(pending[index])
		if Time.get_ticks_usec() >= deadline:
			return index == pending.size() - 1
	return true

## Per-group {"ready", "total", "bytes"}, plus "All" for the unique set. Counts only verified clips.
static func readiness() -> Dictionary[String, Dictionary]:
	var report: Dictionary[String, Dictionary] = {}
	var sizes: Dictionary[String, int] = {}
	var groups: Dictionary[String, Array] = manifest()
	var stored: Dictionary = _stored()
	for name: String in groups:
		for path: String in groups[name]:
			if not sizes.has(path):
				sizes[path] = _verified[path] if not stored.is_empty() and known_ready(path, stored) else -1
	for name: String in groups:
		var ready: int = 0
		var bytes: int = 0
		for path: String in groups[name]:
			if sizes[path] >= 0:
				ready += 1
				bytes += sizes[path]
		report[name] = {"ready": ready, "total": (groups[name] as Array).size(), "bytes": bytes}
	var stored_bytes: int = 0
	for size: int in sizes.values():
		stored_bytes += maxi(size, 0)
	report["All"] = {"ready": sizes.values().filter(func(size: int) -> bool: return size >= 0).size(), "total": sizes.size(), "bytes": stored_bytes}
	return report

static func _size(path: String) -> int:
	var file: FileAccess = FileAccess.open(VoicePlayer.cache_file(path), FileAccess.READ)
	return 0 if file == null else int(file.get_length())

func progress() -> Vector2i:
	return Vector2i(_done, _total)

## Queues only clips that are not verified on this device. Nothing runs until the student asks.
func start() -> void:
	if running:
		return
	_remove_partials()
	var all: Array[String] = paths()
	var stored: Dictionary = _stored()
	_queue = all.filter(func(path: String) -> bool: return stored.is_empty() or not known_ready(path, stored))
	_total = all.size()
	_done = _total - _queue.size()
	failed.clear()
	_attempts.clear()
	_streak = 0
	running = true
	progress_changed.emit(_done, _total)
	_pump()

## Stops queueing. Requests already in flight finish and cache in the background; nothing is deleted.
func cancel() -> void:
	if not running:
		return
	_stop()
	finished.emit(failed.size(), true)

func _stop() -> void:
	running = false
	_queue.clear()
	for path: String in _active:
		var request: HTTPRequest = _active[path]
		if is_instance_valid(request) and request.request_completed.is_connected(_listeners[path]):
			request.request_completed.disconnect(_listeners[path])
	_active.clear()
	_listeners.clear()

func _pump() -> void:
	var deadline: int = Time.get_ticks_usec() + PUMP_BUDGET_USEC
	while running and _active.size() < CONCURRENCY and not _queue.is_empty():
		if Time.get_ticks_usec() >= deadline:
			_pump.call_deferred()
			return
		var path: String = _queue.pop_front()
		if is_ready(path):
			_done += 1
			progress_changed.emit(_done, _total)
			continue
		var request: HTTPRequest = VoicePlayer.download(path, TIMEOUT)
		var listener: Callable = _completed.bind(path, request)
		_active[path] = request
		_listeners[path] = listener
		request.request_completed.connect(listener, CONNECT_ONE_SHOT)
	if running and _active.is_empty() and _queue.is_empty():
		running = false
		finished.emit(failed.size(), false)

func _completed(result: int, status: int, _headers: PackedStringArray, body: PackedByteArray, path: String, request: HTTPRequest) -> void:
	if _active.get(path) != request:
		return
	_active.erase(path)
	_listeners.erase(path)
	if not is_ready(path) and result == HTTPRequest.RESULT_SUCCESS and status == 200:
		VoicePlayer.store_download(path, body)
	if is_ready(path):
		_streak = 0
		_done += 1
		progress_changed.emit(_done, _total)
	else:
		_attempts[path] = int(_attempts.get(path, 0)) + 1
		var transient: bool = result in TRANSIENT or status >= 500 or status == 429
		_streak = _streak + 1 if transient else 0
		if _streak >= OFFLINE_STREAK:
			var missing: Array[String] = [path]
			missing.append_array(_queue)
			missing.append_array(_active.keys())
			_stop()
			for item: String in missing:
				if item not in failed:
					failed.append(item)
			finished.emit(failed.size(), false)
			return
		if transient and _attempts[path] < ATTEMPTS:
			_queue.append(path)
		else:
			failed.append(path)
	_pump()

## A temporary file only survives an interrupted write; it is never a usable clip.
static func _remove_partials() -> void:
	var dir: DirAccess = DirAccess.open(VoicePlayer.cache_dir)
	if dir == null:
		return
	for file: String in dir.get_files():
		if file.ends_with(".tmp"):
			dir.remove(file)
