extends Node
## Procedural sound effects. Every sound is synthesised into an AudioStreamWAV
## at startup, so the game ships with zero audio files.

const RATE := 22050
var enabled := true
var streams := {}
var players: Array[AudioStreamPlayer] = []
var _next := 0

func _ready() -> void:
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.volume_db = -8.0
		add_child(p)
		players.append(p)
	streams["chop"] = _make(0.12, func(t, k): return _sq(t * 160.0 * (1.0 - k * 0.5)) * 0.4 * (1.0 - k) + _noise() * 0.25 * (1.0 - k))
	streams["mine"] = _make(0.14, func(t, k): return (_tri(t * 900.0) * 0.3 + _noise() * 0.3) * pow(1.0 - k, 2.0))
	streams["hit"] = _make(0.1, func(t, k): return (_sq(t * 220.0 * (1.0 - k)) * 0.35 + _noise() * 0.35) * (1.0 - k))
	streams["swing"] = _make(0.09, func(t, k): return _noise() * 0.22 * sin(k * PI))
	streams["hurt"] = _make(0.22, func(t, k): return _sq(t * (300.0 - k * 200.0)) * 0.35 * (1.0 - k))
	streams["pickup"] = _make(0.1, func(t, k): return _tri(t * (660.0 + k * 500.0)) * 0.35 * (1.0 - k))
	streams["craft"] = _make(0.28, func(t, k): return _tri(t * (523.0 if k < 0.33 else (659.0 if k < 0.66 else 784.0))) * 0.35 * (1.0 - k * 0.6))
	streams["place"] = _make(0.12, func(t, k): return (_sq(t * 110.0) * 0.3 + _noise() * 0.2) * (1.0 - k))
	streams["eat"] = _make(0.2, func(t, k): return _noise() * 0.25 * (0.5 + 0.5 * sin(k * 40.0)) * (1.0 - k))
	streams["drink"] = _make(0.25, func(t, k): return sin(TAU * t * (400.0 + sin(k * 30.0) * 120.0)) * 0.3 * (1.0 - k))
	streams["shoot"] = _make(0.12, func(t, k): return _tri(t * (900.0 - k * 600.0)) * 0.3 * (1.0 - k))
	streams["fire"] = _make(0.3, func(t, k): return (_noise() * 0.35 + _sq(t * (180.0 - k * 120.0)) * 0.15) * (1.0 - k))
	streams["roar"] = _make(0.8, func(t, k): return (_sq(t * (70.0 + sin(k * 18.0) * 20.0)) * 0.3 + _noise() * 0.2) * sin(k * PI))
	streams["night"] = _make(1.0, func(t, k): return (sin(TAU * t * 196.0) * 0.25 + sin(TAU * t * 233.0) * 0.18) * pow(1.0 - k, 1.5))
	streams["dawn"] = _make(0.9, func(t, k): return (_tri(t * (392.0 if k < 0.3 else (494.0 if k < 0.6 else 587.0))) * 0.3) * (1.0 - k * 0.7))
	streams["die"] = _make(0.35, func(t, k): return (_sq(t * (260.0 - k * 220.0)) * 0.3 + _noise() * 0.15) * (1.0 - k))
	streams["win"] = _make(1.4, func(t, k): return _tri(t * [523.0, 659.0, 784.0, 1046.0][min(3, int(k * 4.0))]) * 0.32 * (1.0 - k * 0.5))
	streams["ui"] = _make(0.05, func(t, k): return _tri(t * 880.0) * 0.25 * (1.0 - k))

func _noise() -> float:
	return randf() * 2.0 - 1.0

func _sq(ph: float) -> float:
	return 1.0 if fmod(ph, 1.0) < 0.5 else -1.0

func _tri(ph: float) -> float:
	var f := fmod(ph, 1.0)
	return 4.0 * abs(f - 0.5) - 1.0

func _make(dur: float, f: Callable) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / RATE
		var k := float(i) / n
		var v: float = clamp(f.call(t, k), -1.0, 1.0)
		var s := int(v * 32000.0)
		data.encode_s16(i * 2, s)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w

func play(name: String, pitch: float = 1.0, vol: float = 0.0) -> void:
	if not enabled or not streams.has(name):
		return
	var p := players[_next]
	_next = (_next + 1) % players.size()
	p.stream = streams[name]
	p.pitch_scale = pitch * randf_range(0.94, 1.06)
	p.volume_db = -8.0 + vol
	p.play()
