class_name Synth
extends RefCounted
## Sintetizador de PLACEHOLDERS de áudio (efeitos e músicas chiptune).
## Usado automaticamente quando não existe o arquivo equivalente em
## assets/kenney/audio ou assets/custom/audio (veja AssetLib.audio()).
## Tudo é gerado em memória como AudioStreamWAV — nenhum arquivo é necessário.

const RATE := 22050
const SQUARE := 0
const SAW := 1
const SINE := 2
const TRI := 3


# ---------------------------------------------------------------- utilitários

static func to_wav(samples: PackedFloat32Array, rate: int = RATE, loop: bool = false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		var v := int(clampf(samples[i], -1.0, 1.0) * 32000.0)
		data.encode_s16(i * 2, v)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	return wav


static func _wave(kind: int, phase: float) -> float:
	match kind:
		SQUARE:
			return 1.0 if phase < 0.5 else -1.0
		SAW:
			return 2.0 * phase - 1.0
		SINE:
			return sin(phase * TAU)
		TRI:
			return 4.0 * absf(phase - 0.5) - 1.0
	return 0.0


static func _env(t: float, dur: float, attack: float, release: float) -> float:
	var a := 1.0
	if attack > 0.0 and t < attack:
		a = t / attack
	var left := dur - t
	if release > 0.0 and left < release:
		a *= maxf(left / release, 0.0)
	return a


## Tom com glissando de f0 para f1 (Hz). Vibrato opcional.
static func tone(f0: float, f1: float, dur: float, kind: int = SQUARE, vol: float = 0.4,
		attack: float = 0.004, release: float = 0.06, vib_hz: float = 0.0, vib_depth: float = 0.0) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := lerpf(f0, f1, t / dur)
		if vib_hz > 0.0:
			f *= 1.0 + sin(TAU * vib_hz * t) * vib_depth
		phase = fmod(phase + f / RATE, 1.0)
		out[i] = _wave(kind, phase) * vol * _env(t, dur, attack, release)
	return out


## Ruído com filtro passa-baixa simples (lp 1.0 = sem filtro, 0.02 = bem abafado).
static func noise(dur: float, vol: float = 0.4, attack: float = 0.003, release: float = 0.1,
		lp_from: float = 1.0, lp_to: float = 1.0) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var y := 0.0
	for i in n:
		var t := float(i) / RATE
		var a := lerpf(lp_from, lp_to, t / dur)
		y += (randf() * 2.0 - 1.0 - y) * a
		out[i] = y * vol * _env(t, dur, attack, release)
	return out


static func silence(dur: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(dur * RATE))
	return out


## Soma b dentro de a a partir de offset (segundos).
static func mix(a: PackedFloat32Array, b: PackedFloat32Array, offset: float = 0.0) -> PackedFloat32Array:
	var start := int(offset * RATE)
	var out := a.duplicate()
	if out.size() < start + b.size():
		out.resize(start + b.size())
	for i in b.size():
		out[start + i] += b[i]
	return out


static func concat(parts: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for p in parts:
		out.append_array(p)
	return out


static func midi_hz(note: float) -> float:
	return 440.0 * pow(2.0, (note - 69.0) / 12.0)


# ---------------------------------------------------------------- efeitos

## Cria o efeito sonoro placeholder pelo nome. Nomes usados pelo jogo:
## click, type, whoosh, boom, count, go, pickup, roll, crash, boing, spin, rocket,
## explosion, zap, steam, magnet, boost, land, lap, finish, record, honk, teleport,
## banana, splat, clank, ops, star
static func make_sfx(sfx_name: String) -> AudioStream:
	var s := PackedFloat32Array()
	match sfx_name:
		"click":
			s = tone(900, 1400, 0.06, SQUARE, 0.22, 0.002, 0.04)
		"type":
			s = mix(noise(0.03, 0.35, 0.001, 0.02, 0.9, 0.4), tone(2400, 1900, 0.015, SQUARE, 0.1))
		"whoosh":
			s = noise(0.5, 0.9, 0.22, 0.25, 0.04, 0.5)
		"boom":
			s = mix(tone(75, 26, 1.5, SINE, 0.95, 0.002, 1.1), noise(1.3, 1.0, 0.002, 1.1, 0.6, 0.03))
		"count":
			s = tone(440, 440, 0.18, SQUARE, 0.28, 0.003, 0.05)
		"go":
			s = mix(tone(880, 880, 0.5, SQUARE, 0.26, 0.003, 0.2), tone(1320, 1320, 0.5, SQUARE, 0.12, 0.003, 0.2))
		"pickup":
			s = concat([tone(660, 660, 0.06, SQUARE, 0.25), tone(880, 880, 0.06, SQUARE, 0.25), tone(1320, 1320, 0.12, SQUARE, 0.25)])
		"roll":
			s = tone(1100, 1100, 0.03, SQUARE, 0.12, 0.001, 0.01)
		"crash":
			s = mix(noise(0.55, 0.9, 0.001, 0.45, 0.6, 0.08), tone(130, 40, 0.35, SINE, 0.8))
			s = mix(s, tone(1800, 1650, 0.18, TRI, 0.22), 0.06)
			s = mix(s, tone(2600, 2450, 0.14, TRI, 0.18), 0.16)
			s = mix(s, tone(1250, 1200, 0.2, TRI, 0.2), 0.27)
		"boing":
			s = tone(200, 560, 0.42, SINE, 0.6, 0.004, 0.18, 9.0, 0.18)
		"spin":
			s = tone(1300, 280, 0.65, TRI, 0.38, 0.01, 0.2, 14.0, 0.06)
		"rocket":
			s = noise(0.8, 0.7, 0.03, 0.35, 0.25, 0.7)
		"explosion":
			s = mix(noise(1.0, 1.0, 0.001, 0.9, 0.7, 0.04), tone(95, 30, 0.7, SINE, 0.8))
		"zap":
			s = mix(tone(120, 90, 0.5, SAW, 0.3, 0.004, 0.15, 30.0, 0.35), noise(0.5, 0.25, 0.002, 0.2))
		"steam":
			s = noise(0.8, 0.4, 0.06, 0.35, 0.95, 0.7)
		"magnet":
			s = tone(280, 620, 0.55, SINE, 0.45, 0.01, 0.12, 18.0, 0.15)
		"boost":
			s = mix(tone(180, 950, 0.5, SAW, 0.22, 0.01, 0.12), noise(0.5, 0.35, 0.01, 0.2, 0.15, 0.6))
		"land":
			s = mix(tone(150, 55, 0.16, SINE, 0.75), noise(0.13, 0.45, 0.001, 0.1, 0.3, 0.08))
		"lap":
			s = concat([tone(784, 784, 0.12, SQUARE, 0.25), tone(1047, 1047, 0.28, SQUARE, 0.25, 0.003, 0.12)])
		"finish":
			s = concat([tone(523, 523, 0.12, SQUARE, 0.25), tone(659, 659, 0.12, SQUARE, 0.25),
				tone(784, 784, 0.12, SQUARE, 0.25), tone(1047, 1047, 0.55, SQUARE, 0.25, 0.003, 0.3)])
		"record":
			var notes := [72, 76, 79, 84, 79, 84, 88, 91]
			var parts := []
			for nt in notes:
				parts.append(tone(midi_hz(nt), midi_hz(nt), 0.07, TRI, 0.35, 0.002, 0.03))
			s = concat(parts)
		"honk":
			s = concat([tone(392, 392, 0.14, SQUARE, 0.28), silence(0.04), tone(330, 330, 0.24, SQUARE, 0.28)])
		"teleport":
			s = concat([tone(300, 2200, 0.22, SINE, 0.35, 0.005, 0.02, 40.0, 0.1), tone(2200, 400, 0.2, SINE, 0.35)])
		"banana":
			s = tone(520, 140, 0.3, TRI, 0.42, 0.003, 0.1, 22.0, 0.2)
		"splat":
			s = noise(0.28, 0.75, 0.001, 0.22, 0.85, 0.05)
		"clank":
			s = mix(tone(1600, 1500, 0.2, TRI, 0.28), tone(2350, 2300, 0.15, TRI, 0.2))
		"ops":
			s = concat([tone(420, 400, 0.12, SQUARE, 0.22), tone(300, 150, 0.3, SQUARE, 0.22)])
		"star":
			s = tone(1800, 2600, 0.12, TRI, 0.25, 0.002, 0.08)
		_:
			return null
	return to_wav(s)


## Loop de motor (o pitch é controlado pelo carro do jogador).
static func engine_loop() -> AudioStreamWAV:
	var period := 360 # 22050/360 = 61,25 Hz — loop contém períodos inteiros
	var n := period * 16
	var out := PackedFloat32Array()
	out.resize(n)
	var y := 0.0
	for i in n:
		var ph := float(i % period) / period
		var saw := 2.0 * ph - 1.0
		var pulse := 1.0 if ph < 0.22 else -0.3
		y += (randf() * 2.0 - 1.0 - y) * 0.2
		out[i] = (saw * 0.3 + pulse * 0.25 + y * 0.22) * 0.55
	return to_wav(out, RATE, true)


# ---------------------------------------------------------------- músicas

## Definições das músicas chiptune (acordes em MIDI, padrões de 16 passos por compasso).
## Padrão "lead"/"bass": índice no acorde (0..5, >=3 sobe uma oitava) ou -1 = pausa.
static func song(song_name: String) -> Dictionary:
	var am := [57, 60, 64]
	var f := [53, 57, 60]
	var c := [55, 60, 64]
	var g := [55, 59, 62]
	var e := [56, 59, 64]
	var dm := [57, 62, 65]
	if song_name == "race":
		return {
			"bpm": 152.0,
			"chords": [am, f, c, g, am, f, e, e],
			"lead": [3, 2, 1, 2, 3, 2, 1, 2, 4, 3, 2, 3, 5, 4, 3, 1],
			"lead_alt": [5, -1, 5, 4, 3, -1, 3, 2, 1, -1, 2, 3, 4, -1, -1, -1],
			"bass": [0, -1, 2, -1, 0, -1, 2, -1, 0, -1, 2, -1, 0, 2, 3, 2],
			"kick": [0, 4, 8, 12],
			"snare": [4, 12],
			"hat": [2, 6, 10, 14],
		}
	# "menu" (padrão)
	return {
		"bpm": 124.0,
		"chords": [c, am, f, g, c, am, dm, g],
		"lead": [0, -1, 1, -1, 2, -1, 1, -1, 3, -1, 2, -1, 1, -1, -1, -1],
		"lead_alt": [3, 4, 5, -1, 4, -1, 3, -1, 2, -1, 1, -1, 0, -1, -1, -1],
		"bass": [0, -1, -1, -1, 2, -1, -1, -1, 0, -1, -1, -1, 2, -1, 1, -1],
		"kick": [0, 8],
		"snare": [4, 12],
		"hat": [0, 2, 4, 6, 8, 10, 12, 14],
	}


## Renderiza uma música inteira (chamado numa Thread pelo AudioManager).
static func render_song(def: Dictionary) -> AudioStreamWAV:
	var rate := 16000
	var bpm: float = def["bpm"]
	var chords: Array = def["chords"]
	var lead: Array = def["lead"]
	var lead_alt: Array = def["lead_alt"]
	var bass: Array = def["bass"]
	var kicks: Array = def["kick"]
	var snares: Array = def["snare"]
	var hats: Array = def["hat"]
	var spb := int(round(60.0 / bpm / 4.0 * rate)) # amostras por semicolcheia
	var total_steps := chords.size() * 16
	var out := PackedFloat32Array()
	out.resize(spb * total_steps)
	var noise_tab := PackedFloat32Array()
	noise_tab.resize(4096)
	for i in 4096:
		noise_tab[i] = randf() * 2.0 - 1.0
	var ph_lead := 0.0
	var ph_bass := 0.0
	var ph_kick := 0.0
	for s in total_steps:
		var bar := int(float(s) / 16.0)
		var st := s % 16
		var chord: Array = chords[bar]
		var pattern: Array = lead_alt if bar % 4 == 3 else lead
		var li: int = pattern[st]
		var bi: int = bass[st]
		var lead_f := 0.0
		var bass_f := 0.0
		if li >= 0:
			var ln: int = chord[li % 3] + 12 * int(li / 3.0) + 12
			lead_f = midi_hz(ln)
		if bi >= 0:
			var bn: int = chord[bi % 3] + 12 * int(bi / 3.0) - 24
			bass_f = midi_hz(bn)
		var is_kick := kicks.has(st)
		var is_snare := snares.has(st)
		var is_hat := hats.has(st)
		ph_kick = 0.0
		for j in spb:
			var idx := s * spb + j
			var tl := float(j) / rate
			var v := 0.0
			if lead_f > 0.0:
				ph_lead = fmod(ph_lead + lead_f / rate, 1.0)
				v += (0.13 if ph_lead < 0.25 else -0.13) * (1.0 - float(j) / spb * 0.7)
			if bass_f > 0.0:
				ph_bass = fmod(ph_bass + bass_f / rate, 1.0)
				v += (4.0 * absf(ph_bass - 0.5) - 1.0) * 0.22 * (1.0 - float(j) / spb * 0.3)
			if is_kick and tl < 0.14:
				var kf := 150.0 * exp(-tl * 30.0) + 42.0
				ph_kick = fmod(ph_kick + kf / rate, 1.0)
				v += sin(ph_kick * TAU) * 0.42 * exp(-tl * 22.0)
			if is_snare and tl < 0.12:
				v += noise_tab[idx & 4095] * 0.2 * exp(-tl * 24.0)
			if is_hat and tl < 0.04:
				v += (noise_tab[idx & 4095] - noise_tab[(idx + 1) & 4095]) * 0.05 * exp(-tl * 90.0)
			out[idx] = v
	return to_wav(out, rate, true)
