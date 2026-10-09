extends SceneTree
## Offline original synthesis; never runs during gameplay. No sampled/licensed audio.
## Music intermediates go in .godot/audio_bake for Vorbis encoding; SFX are final PCM.
const RATE: int = 22050
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _initialize() -> void:
	_rng.seed = 42710
	DirAccess.make_dir_recursive_absolute("res://.godot/audio_bake")
	DirAccess.make_dir_recursive_absolute("res://assets/audio/sfx")
	DirAccess.make_dir_recursive_absolute("res://assets/audio/bgm")
	call_deferred("_bake")

func _tone(buffer: PackedFloat32Array, start: float, duration: float, midi: int, gain: float, voice: String, wrap: bool = false) -> void:
	var count: int = int(duration * RATE)
	var offset: int = int(start * RATE)
	var frequency: float = 440.0 * pow(2.0, (midi - 69) / 12.0)
	for i: int in count:
		var index: int = offset + i
		if index >= buffer.size() and not wrap:
			break
		index %= buffer.size()
		var t: float = float(i) / RATE
		var phase: float = TAU * frequency * t
		var attack: float = minf(t / (0.13 if voice == "pad" else 0.008), 1.0)
		var release: float = minf((duration - t) / (0.22 if voice == "pad" else 0.035), 1.0)
		var value: float = sin(phase)
		match voice:
			"pluck": value = (sin(phase) + sin(phase * 2.0) * 0.22 + sin(phase * 3.0) * 0.1) * exp(-t * 8.0)
			"bass": value = sin(phase) + sin(phase * 2.0) * 0.15
			"pad": value = (sin(phase) + sin(phase * 1.003) * 0.3) * 0.7
			"kick": value = sin(TAU * (48.0 * t + 2.6 * (1.0 - exp(-t * 24.0)))) * exp(-t * 19.0)
			"hat": value = _rng.randf_range(-1.0, 1.0) * exp(-t * 60.0)
		buffer[index] += value * gain * attack * release

func _save(buffer: PackedFloat32Array, path: String, peak: float) -> void:
	var largest: float = 0.0001
	for value: float in buffer:
		largest = maxf(largest, absf(value))
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(buffer.size() * 2)
	for i: int in buffer.size():
		bytes.encode_s16(i * 2, int(clampf(buffer[i] * peak / largest, -1.0, 1.0) * 32767.0))
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = bytes
	var result: Error = stream.save_to_wav(path)
	assert(result == OK, "Cannot write " + path)
	print("BAKED ", path, " samples=", buffer.size(), " peak=", peak)

func _music(key: String, bpm: float) -> void:
	var beat: float = 60.0 / bpm
	var length: float = beat * 32.0
	var buffer: PackedFloat32Array = PackedFloat32Array()
	buffer.resize(int(length * RATE))
	var roots: Array[int] = [45, 41, 48, 43, 45, 41, 50, 40]
	var thirds: Array[int] = [3, 4, 4, 4, 3, 4, 3, 4]
	var motif: Array[int] = [0, 7, 12, 7, 3, 7, 10, 7]
	for bar: int in 8:
		var root_note: int = roots[bar]
		if key == "pvp": root_note -= 12
		for interval: int in [0, thirds[bar], 7, 14]:
			_tone(buffer, bar * beat * 4.0, beat * 4.3, root_note + 12 + interval, 0.052, "pad", true)
		for pulse: int in 8:
			var at: float = (bar * 4.0 + pulse * 0.5) * beat
			var note: int = root_note + 24 + motif[pulse]
			if pulse == 4: note = root_note + 24 + thirds[bar]
			if bar >= 4 and pulse == 6: note += 2
			if key == "study":
				if pulse in [0, 3, 6]: _tone(buffer, at, beat * 1.4, note, 0.085, "pluck", true)
			else:
				_tone(buffer, at, beat * 0.8, note, 0.10 if key == "loading" else 0.065, "pluck", true)
				if key == "loading" or pulse % 2 == 1:
					_tone(buffer, at, 0.075, 60, 0.023, "hat", true)
			if pulse % 2 == 0:
				_tone(buffer, at, beat * 0.8, root_note, 0.12, "bass", true)
				if key != "study": _tone(buffer, at, 0.2, 40, 0.14 if key == "pvp" else 0.10, "kick", true)
	# Circular delay carries the last bar's tail into the first, avoiding a dead loop seam.
	var dry: PackedFloat32Array = buffer.duplicate()
	var delay: int = int(beat * 0.75 * RATE)
	for i: int in buffer.size():
		buffer[i] += dry[posmod(i - delay, buffer.size())] * 0.16
	_save(buffer, "res://.godot/audio_bake/" + key + ".wav", 0.48)

func _effect(key: String, notes: Array[int], duration: float, step: float, gain: float = 0.55) -> void:
	var buffer: PackedFloat32Array = PackedFloat32Array()
	buffer.resize(int((duration + step * (notes.size() - 1) + 0.04) * RATE))
	for i: int in notes.size():
		_tone(buffer, i * step, duration, notes[i], 0.3, "pluck")
	_save(buffer, "res://assets/audio/sfx/" + key + ".wav", gain)

func _bake() -> void:
	_music("loading", 108.0)
	_music("hub", 90.0)
	_music("pvp", 96.0)
	_music("study", 72.0)
	_effect("ui_click", [79], 0.065, 0.0, 0.32)
	_effect("ui_confirm", [72, 79], 0.16, 0.065, 0.43)
	_effect("ui_notification", [76, 83], 0.23, 0.16, 0.43)
	_effect("ui_success", [72, 76, 79, 84], 0.28, 0.09, 0.48)
	_effect("ui_error", [64, 60], 0.17, 0.10, 0.38)
	_effect("loading_ready", [69, 72, 76, 81, 88], 0.38, 0.10, 0.48)
	var sweep: PackedFloat32Array = PackedFloat32Array()
	sweep.resize(int(RATE * 0.24))
	var smooth_noise: float = 0.0
	for i: int in sweep.size():
		var t: float = float(i) / RATE
		var envelope: float = sin(PI * t / 0.24)
		smooth_noise = lerpf(smooth_noise, _rng.randf_range(-1, 1), 0.12)
		sweep[i] = envelope * (smooth_noise * 0.5 + sin(TAU * (420 * t - 500 * t * t)) * 0.12)
	_save(sweep, "res://assets/audio/sfx/ui_transition.wav", 0.22)
	quit()
