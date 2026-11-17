extends Node
## Efectos de sonido generados por codigo: el proyecto no necesita ningun
## asset de audio. Cada sonido se calcula una vez al arrancar y se reproduce
## mediante un pool de AudioStreamPlayer.

class_name TymSfx

const MIX_RATE := 22050
const VOICES := 6

var _voices: Array[AudioStreamPlayer] = []
var _bank: Dictionary = {}
var enabled := true


func _ready() -> void:
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_voices.append(p)

	_bank = {
		"punch": _thud(0.16, 210.0, 55.0),
		"thud": _noise(0.14, 0.75),
		"crack": _crack(),
		"break": _shatter(),
		"bounce": _bounce(),
		"bell": _bell(),
		"win": _fanfare(true),
		"lose": _fanfare(false),
		"select": _blip(760.0, 0.06),
		"start": _blip(520.0, 0.10),
	}


func play(sound: String, pitch := 1.0, volume_db := 0.0) -> void:
	if not enabled or not _bank.has(sound):
		return
	for p in _voices:
		if not p.playing:
			_start(p, sound, pitch, volume_db)
			return
	# Si todas las voces estan ocupadas, robamos la primera.
	_start(_voices[0], sound, pitch, volume_db)


func _start(p: AudioStreamPlayer, sound: String, pitch: float, volume_db: float) -> void:
	p.stream = _bank[sound]
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.play()


# --- generadores -------------------------------------------------------

func _blank(seconds: float) -> PackedFloat32Array:
	var s := PackedFloat32Array()
	s.resize(maxi(1, int(MIX_RATE * seconds)))
	return s


func _stream(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = MIX_RATE
	w.stereo = false
	w.data = bytes
	return w


## Golpe seco: barrido de tono descendente + transitorio de ruido.
func _thud(seconds: float, f_start: float, f_end: float) -> AudioStreamWAV:
	var s := _blank(seconds)
	var phase := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 20250913
	for i in s.size():
		var t := float(i) / MIX_RATE
		var env := exp(-t * 20.0)
		var f := lerpf(f_start, f_end, minf(1.0, t * 14.0))
		phase += TAU * f / MIX_RATE
		var noise := rng.randf_range(-1.0, 1.0) * exp(-t * 70.0) * 0.55
		s[i] = (sin(phase) * 0.85 + noise) * env * 0.9
	return _stream(s)


## Estallido de ruido corto (caidas, polvo).
func _noise(seconds: float, decay: float) -> AudioStreamWAV:
	var s := _blank(seconds)
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var last := 0.0
	for i in s.size():
		var t := float(i) / MIX_RATE
		last = last * 0.55 + rng.randf_range(-1.0, 1.0) * 0.45
		s[i] = last * exp(-t * decay) * 0.55
	return _stream(s)


## Grieta: golpe seco metalico con un poco de ruido.
func _crack() -> AudioStreamWAV:
	var s := _blank(0.22)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var last := 0.0
	for i in s.size():
		var t := float(i) / MIX_RATE
		var env := exp(-t * 26.0)
		last = last * 0.4 + rng.randf_range(-1.0, 1.0) * 0.6
		var tone := sin(TAU * 340.0 * t) * 0.5 + sin(TAU * 517.0 * t) * 0.3
		s[i] = (tone + last * 0.7) * env * 0.75
	return _stream(s)


## Rotura: varios fragmentos de ruido a distinta frecuencia.
func _shatter() -> AudioStreamWAV:
	var s := _blank(0.7)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var last := 0.0
	for i in s.size():
		var t := float(i) / MIX_RATE
		var env := exp(-t * 6.0)
		last = last * 0.3 + rng.randf_range(-1.0, 1.0) * 0.7
		# Cada fragmento cae en un instante un poco distinto.
		var grain := 0.0
		for k in 6:
			var at := 0.03 * k + rng.randf_range(-0.01, 0.01)
			if t >= at:
				grain += sin(TAU * (700.0 + k * 260.0) * (t - at)) * exp(-(t - at) * 55.0) * 0.4
		s[i] = (last * 0.8 + grain) * env * 0.7
	return _stream(s)


## Rebote: el golpe no llega, suena sordo y opaco.
func _bounce() -> AudioStreamWAV:
	var s := _blank(0.18)
	var rng := RandomNumberGenerator.new()
	rng.seed = 313
	var last := 0.0
	for i in s.size():
		var t := float(i) / MIX_RATE
		last = last * 0.7 + rng.randf_range(-1.0, 1.0) * 0.3
		s[i] = last * exp(-t * 34.0) * 0.45
	return _stream(s)


## Campana de inicio de ronda.
func _bell() -> AudioStreamWAV:
	var s := _blank(0.45)
	for i in s.size():
		var t := float(i) / MIX_RATE
		var env := exp(-t * 7.0)
		s[i] = (
			sin(TAU * 880.0 * t) * 0.5
			+ sin(TAU * 1320.0 * t) * 0.3
			+ sin(TAU * 1760.0 * t) * 0.15
		) * env * 0.7
	return _stream(s)


## Pitido de interfaz.
func _blip(freq: float, seconds: float) -> AudioStreamWAV:
	var s := _blank(seconds)
	for i in s.size():
		var t := float(i) / MIX_RATE
		var env := minf(1.0, t * 60.0) * exp(-t * 12.0)
		s[i] = sin(TAU * freq * t) * env * 0.45
	return _stream(s)


## Fanfarria corta ascendente (victoria) o descendente (derrota).
func _fanfare(up: bool) -> AudioStreamWAV:
	var notes: Array = [523.25, 659.25, 783.99, 1046.50] if up else [523.25, 415.30, 349.23, 261.63]
	var s := _blank(0.6)
	var step := s.size() / notes.size()
	for i in s.size():
		var t := float(i) / MIX_RATE
		var idx := clampi(i / step, 0, notes.size() - 1)
		var local := t - float(idx * step) / MIX_RATE
		var env := exp(-local * 6.0) * minf(1.0, local * 90.0)
		var f: float = notes[idx]
		s[i] = (sin(TAU * f * t) * 0.6 + sin(TAU * f * 2.0 * t) * 0.2) * env * 0.6
	return _stream(s)
