class_name SongRender
extends RefCounted
## Renderizador INCREMENTAL de uma música chiptune (definição de Synth.song()).
## process(n) gera n semicolcheias por chamada — permite sintetizar a música em fatias
## dentro de _process() quando não há threads (exportação web), sem travar o jogo.

const RATE := 16000

var _chords: Array
var _lead: Array
var _lead_alt: Array
var _bass: Array
var _kicks: Array
var _snares: Array
var _hats: Array
var _spb := 0
var _total_steps := 0
var _step := 0
var _out := PackedFloat32Array()
var _noise := PackedFloat32Array()
var _ph_lead := 0.0
var _ph_bass := 0.0


func _init(def: Dictionary) -> void:
	var bpm: float = def["bpm"]
	_chords = def["chords"]
	_lead = def["lead"]
	_lead_alt = def["lead_alt"]
	_bass = def["bass"]
	_kicks = def["kick"]
	_snares = def["snare"]
	_hats = def["hat"]
	_spb = int(round(60.0 / bpm / 4.0 * RATE)) # amostras por semicolcheia
	_total_steps = _chords.size() * 16
	_out.resize(_spb * _total_steps)
	_noise.resize(4096)
	for i in 4096:
		_noise[i] = randf() * 2.0 - 1.0


## Gera até max_steps semicolcheias. Retorna true quando a música está completa.
func process(max_steps: int) -> bool:
	var end := mini(_step + max_steps, _total_steps)
	while _step < end:
		_render_step(_step)
		_step += 1
	return _step >= _total_steps


func progress() -> float:
	return float(_step) / maxf(float(_total_steps), 1.0)


func get_stream() -> AudioStreamWAV:
	return Synth.to_wav(_out, RATE, true)


func _render_step(s: int) -> void:
	var bar := int(float(s) / 16.0)
	var st := s % 16
	var chord: Array = _chords[bar]
	var pattern: Array = _lead_alt if bar % 4 == 3 else _lead
	var li: int = pattern[st]
	var bi: int = _bass[st]
	var lead_f := 0.0
	var bass_f := 0.0
	if li >= 0:
		var ln: int = chord[li % 3] + 12 * int(li / 3.0) + 12
		lead_f = Synth.midi_hz(ln)
	if bi >= 0:
		var bn: int = chord[bi % 3] + 12 * int(bi / 3.0) - 24
		bass_f = Synth.midi_hz(bn)
	var is_kick := _kicks.has(st)
	var is_snare := _snares.has(st)
	var is_hat := _hats.has(st)
	var ph_kick := 0.0
	for j in _spb:
		var idx := s * _spb + j
		var tl := float(j) / RATE
		var v := 0.0
		if lead_f > 0.0:
			_ph_lead = fmod(_ph_lead + lead_f / RATE, 1.0)
			v += (0.13 if _ph_lead < 0.25 else -0.13) * (1.0 - float(j) / _spb * 0.7)
		if bass_f > 0.0:
			_ph_bass = fmod(_ph_bass + bass_f / RATE, 1.0)
			v += (4.0 * absf(_ph_bass - 0.5) - 1.0) * 0.22 * (1.0 - float(j) / _spb * 0.3)
		if is_kick and tl < 0.14:
			var kf := 150.0 * exp(-tl * 30.0) + 42.0
			ph_kick = fmod(ph_kick + kf / RATE, 1.0)
			v += sin(ph_kick * TAU) * 0.42 * exp(-tl * 22.0)
		if is_snare and tl < 0.12:
			v += _noise[idx & 4095] * 0.2 * exp(-tl * 24.0)
		if is_hat and tl < 0.04:
			v += (_noise[idx & 4095] - _noise[(idx + 1) & 4095]) * 0.05 * exp(-tl * 90.0)
		_out[idx] = v
