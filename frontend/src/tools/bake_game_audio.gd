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
	if "--debate-only" in OS.get_cmdline_user_args():
		_bake_debate()
		quit()
		return
	if "--hearing-only" in OS.get_cmdline_user_args():
		_bake_hearing()
		quit()
		return
	if "--chapter-complete-only" in OS.get_cmdline_user_args():
		_bake_chapter_complete()
		quit()
		return
	if "--cinematic-only" in OS.get_cmdline_user_args():
		_bake_cinematic()
		quit()
		return
	if "--opening-only" in OS.get_cmdline_user_args():
		_bake_opening()
		quit()
		return
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


func _bake_debate() -> void:
	# Original 112 BPM minor pulse; bounded offline synthesis with circular echoes.
	var beat: float = 60.0/112.0
	var buffer: PackedFloat32Array = PackedFloat32Array()
	buffer.resize(int(RATE*beat*32))
	var roots: Array[int] = [38,38,34,37,38,41,34,37]
	var motif: Array[int] = [0,12,7,15,0,10,7,13]
	for bar: int in 8:
		var base: float = bar*beat*4
		for interval: int in [12,15,19]:
			_tone(buffer,base,beat*4.4,roots[bar]+interval,.045,"pad",true)
		for step: int in 8:
			var at: float = base+step*.5*beat
			_tone(buffer,at,beat*.44,roots[bar],.18,"bass",true)
			_tone(buffer,at,beat*.75,roots[bar]+24+motif[step],.08,"pluck",true)
			_tone(buffer,at,.06,72,.035,"hat",true)
			if step % 2 == 0: _tone(buffer,at,.24,36,.23,"kick",true)
			if step in [2,6]:
				_tone(buffer,at,.16,65,.085,"hat",true)
				_tone(buffer,at,.2,50,.085,"pluck",true)
	var dry: PackedFloat32Array = buffer.duplicate()
	for index: int in buffer.size():
		buffer[index] += dry[posmod(index-int(RATE*beat*.75),buffer.size())]*.17
	_save(buffer,"res://assets/audio/bgm/hearing_debate.wav",.53)
	_effect("debate_hit",[84,60,36],.18,.035,.5)
	_effect("debate_counter",[50,62,69,74],.5,.045,.6)
	_effect("debate_start",[38,50,57,62],.4,.1,.5)

func _bake_hearing() -> void:
	# Original 80 BPM minor ostinato, low drums and suspended strings; circular tails.
	var beat: float = .75
	var buffer: PackedFloat32Array = PackedFloat32Array()
	buffer.resize(RATE*24)
	var roots: Array[int] = [38,38,34,37,38,38,34,37]
	var motif: Array[int] = [0,7,12,3,0,7,13,7]
	for bar: int in 8:
		var at: float = bar*4*beat
		for interval: int in [12,19,25]:
			_tone(buffer,at,beat*4.8,roots[bar]+interval,.065,"pad",true)
		for pulse: int in 8:
			var start: float = at+pulse*.5*beat
			_tone(buffer,start,beat*.8,roots[bar]+24+motif[pulse],.09,"pluck",true)
			if pulse % 2 == 0:
				_tone(buffer,start,beat*.85,roots[bar],.23,"bass",true)
			if pulse in [0,3,4,7]:
				_tone(buffer,start,.35,36,.26,"kick",true)
			_tone(buffer,start,.09,60,.018,"hat",true)
	var dry: PackedFloat32Array = buffer.duplicate()
	for index: int in buffer.size():
		buffer[index] += dry[posmod(index-int(RATE*beat*.75),buffer.size())]*.24
	_save(buffer,"res://assets/audio/bgm/hearing_decision.wav",.57)

func _bake_chapter_complete() -> void:
	# Original six-second major-key reward flourish, with a soft resolving tail.
	var buffer: PackedFloat32Array = PackedFloat32Array()
	buffer.resize(RATE * 6)
	var chords: Array[int] = [48, 53, 55, 60]
	for bar: int in chords.size():
		var at: float = bar * 1.05
		for interval: int in [0, 4, 7, 12]:
			_tone(buffer, at, 1.7, chords[bar] + interval, 0.07, "pad")
		_tone(buffer, at, 0.6, chords[bar] - 12, 0.13, "bass")
		_tone(buffer, at, 0.2, 36, 0.08, "kick")
	var melody: Array[int] = [72, 76, 79, 84, 81, 84, 86, 88, 86, 83, 79, 84]
	for i: int in melody.size():
		_tone(buffer, 0.15 + i * 0.28, 0.65 if i < 11 else 1.5, melody[i], 0.18, "pluck")
	_save(buffer, "res://assets/audio/bgm/chapter_complete.wav", 0.62)

func _bake_opening() -> void:
	# Warm, sparse 80 BPM original loop: soft major-seventh plucks and a light pulse.
	# Bake once, not at runtime. Only this milestone's four assets are written.
	var beat: float = 0.75
	var music: PackedFloat32Array = PackedFloat32Array()
	music.resize(int(RATE * beat * 32.0))
	var roots: Array[int] = [48, 53, 57, 55, 48, 53, 50, 55]
	for bar: int in 8:
		var root_note: int = roots[bar]
		var third: int = 3 if bar in [2, 6] else 4
		for interval: int in [0, third, 7, 11 if third == 4 else 10]:
			_tone(music, bar * beat * 4.0, beat * 3.9, root_note + 12 + interval, 0.025, "pad", true)
		_tone(music, bar * beat * 4.0, beat * 1.7, root_note, 0.065, "bass", true)
		_tone(music, (bar * 4.0 + 0.5) * beat, beat * 1.3, root_note + 24 + third, 0.12, "pluck", true)
		_tone(music, (bar * 4.0 + 2.5) * beat, beat * 1.2, root_note + 31, 0.085, "pluck", true)
		for pulse: int in [0, 2]:
			_tone(music, (bar * 4.0 + pulse) * beat, 0.15, 40, 0.045, "kick", true)
		_tone(music, (bar * 4.0 + 3) * beat, 0.06, 60, 0.012, "hat", true)
	var dry: PackedFloat32Array = music.duplicate()
	for i: int in music.size():
		music[i] += dry[posmod(i - int(RATE * beat * 0.75), music.size())] * 0.12
	_save(music, "res://assets/audio/bgm/morning.wav", 0.25)
	# Two gentle digital alarm pairs, ending before the thump cue at 0.82s.
	var alarm: PackedFloat32Array = PackedFloat32Array()
	alarm.resize(int(RATE * 0.72))
	for i: int in 4:
		_tone(alarm, i * 0.17, 0.12, 81 if i % 2 == 0 else 88, 0.3, "bass")
	_save(alarm, "res://assets/audio/sfx/opening_alarm.wav", 0.25)
	var thump: PackedFloat32Array = PackedFloat32Array()
	thump.resize(int(RATE * 0.24))
	_tone(thump, 0.0, 0.22, 42, 0.4, "kick")
	_save(thump, "res://assets/audio/sfx/opening_thump.wav", 0.30)
	var shuffle: PackedFloat32Array = PackedFloat32Array()
	shuffle.resize(int(RATE * 0.58))
	var noise: float = 0.0
	for i: int in shuffle.size():
		var t: float = float(i) / RATE
		noise = lerpf(noise, _rng.randf_range(-1.0, 1.0), 0.16)
		var envelope: float = pow(sin(PI * t / 0.58), 2.0) * (0.60 + 0.40 * sin(TAU * 6.0 * t))
		shuffle[i] = noise * envelope
	_save(shuffle, "res://assets/audio/sfx/opening_shuffle.wav", 0.20)


func _heartbeat(buffer: PackedFloat32Array, at: float, gain: float) -> void:
	_tone(buffer, at, 0.18, 36, gain, "kick")
	_tone(buffer, at + 0.16, 0.14, 36, gain * 0.55, "kick")


func _bake_cinematic() -> void:
	# Original, offline scene mixes: one bounded source-owned player at runtime.
	var hit: PackedFloat32Array = PackedFloat32Array()
	hit.resize(RATE * 6)
	for i: int in int(RATE * 1.2):
		var t: float = float(i) / RATE
		var ramp: float = t / 1.2
		hit[int(0.6 * RATE) + i] += sin(TAU * 92.0 * t) * (0.7 + 0.3 * sin(TAU * 19.0 * t)) * ramp * 0.15 * minf(1.0, (1.2 - t) / 0.04)
	_tone(hit, 1.8, 0.65, 30, 0.65, "kick")
	_tone(hit, 1.8, 1.2, 24, 0.08, "bass")
	# Two synchronized voices plus decaying echoes; not repeated player nodes.
	var laugh: PackedFloat32Array = PackedFloat32Array()
	laugh.resize(int(RATE * 1.65))
	var phase: float = 0.0
	for i: int in laugh.size():
		var t: float = float(i) / RATE
		var syllable: int = mini(4, int(t / 0.33))
		var local: float = fposmod(t, 0.33)
		phase += TAU * (175.0 - syllable * 13.0 + 42.0 * exp(-local * 18.0)) / RATE
		var upper: float = sin(phase) + 0.35 * sin(phase * 3.0) + 0.18 * sin(phase * 7.0)
		var lower: float = sin(phase * 0.67) + 0.25 * sin(phase * 2.01)
		var envelope: float = clampf(local / 0.018, 0, 1) * clampf((0.25 - local) / 0.12, 0, 1)
		laugh[i] = roundf((upper + lower * 0.65) * 14.0) / 14.0 * envelope * 0.16
	for echo: int in 6:
		var offset: int = int((1.94 + echo * 0.39) * RATE)
		for i: int in laugh.size():
			if offset + i < hit.size():
				hit[offset + i] += laugh[i] * pow(0.48, echo)
	_save(hit, "res://assets/audio/sfx/opening_takeover.wav", 0.48)
	var meeting: PackedFloat32Array = PackedFloat32Array()
	meeting.resize(RATE * 7)
	for i: int in meeting.size():
		var t: float = float(i) / RATE
		var envelope: float = minf(t / 1.5, 1.0) * clampf((6.65 - t) / 0.55, 0, 1)
		meeting[i] = (sin(TAU * (42.0 * t + 0.6 * t * t)) + 0.3 * sin(TAU * 63.0 * t)) * envelope * (0.03 + t * 0.006)
	_heartbeat(meeting, 5.4, 0.3)
	_save(meeting, "res://assets/audio/sfx/opening_meeting.wav", 0.33)
	var victims: PackedFloat32Array = PackedFloat32Array()
	victims.resize(RATE * 9)
	for panel: int in 5:
		var at: float = 0.4 + panel * 0.7
		_tone(victims, at, 0.3, 78 - panel, 0.12, "pluck")
		_tone(victims, at + 0.045, 0.27, 79 - panel, 0.045, "pluck")
	var beat_at: float = 0.4
	var beat_index: int = 0
	while beat_at < 8.7:
		_heartbeat(victims, beat_at, 0.16)
		beat_at += lerpf(1.05, 0.72, minf(beat_index / 5.0, 1.0))
		beat_index += 1
	_tone(victims, 6.4, 1.0, 31, 0.13, "bass")
	_save(victims, "res://assets/audio/sfx/opening_montage.wav", 0.38)
	var closing: PackedFloat32Array = PackedFloat32Array()
	closing.resize(RATE * 6)
	for beat: int in 5:
		_heartbeat(closing, beat * 0.64, 0.17 + beat * 0.035)
	# The final word lands at 2.8s; no tail may cross that silence boundary.
	for i: int in closing.size():
		closing[i] *= clampf((2.8 - float(i) / RATE) / 0.08, 0, 1)
	_save(closing, "res://assets/audio/sfx/opening_closing.wav", 0.40)
	var rewind: PackedFloat32Array = PackedFloat32Array()
	rewind.resize(RATE)
	var smooth_noise: float = 0.0
	for i: int in rewind.size():
		var t: float = float(i) / RATE
		smooth_noise = lerpf(smooth_noise, _rng.randf_range(-1, 1), 0.23)
		var tape: float = sin(TAU * (1200.0 * t - 470.0 * t * t)) * (0.5 + 0.5 * sin(TAU * 21.0 * t))
		rewind[i] = (smooth_noise * 0.25 + tape * 0.09) * sin(PI * t)
	_save(rewind, "res://assets/audio/sfx/opening_rewind.wav", 0.32)
