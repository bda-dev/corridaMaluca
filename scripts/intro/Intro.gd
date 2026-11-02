extends Control
## INTRO cinemática (~15 s) + TELA DE TÍTULO. Um toque pula direto para o título;
## no título, um toque vai para o menu principal.
##
## Linha do tempo:
##   0,0 – 4,0  tela preta + texto datilografado "1898… o homem decidiu ir mais rápido que o vento."
##   4,0 – 8,2  montagem em filme antigo com as silhuetas dos 6 carros históricos de recorde
##   8,2 – 11,6 versões cartoon dos pilotos acelerando
##   11,6       o ThrustSSC do Doutor Thrust rompe a barreira do som: BOOM + título
##   13,4       slogan  |  14,6 "TOQUE PARA COMEÇAR"

const T_TYPE := 0.5
const T_TYPE_FADE := 3.6
const T_MONTAGE := 4.0
const MONTAGE_STEP := 0.7
const T_CARTOON := 8.2
const T_TITLE := 11.6
const T_SLOGAN := 13.4
const T_PROMPT := 14.6
const TYPE_SPEED := 0.048

const INTRO_TEXT := "1898… o homem decidiu ir mais rápido que o vento."
const TITLE_1 := "CORRIDA MALUCA"
const TITLE_2 := "DOS RECORDES"
const SLOGAN := "Quebre o recorde… ou quebre o carro!"
## Ordem dos carros cartoon: o Doutor Thrust (ThrustSSC, supersônico) passa por último.
const CARTOON_ORDER: Array[String] = ["comte_eclair", "ze_vapor", "lady_nitro", "capitao_foguete", "doutor_thrust"]

var t := 0.0
var _accept_at := 0.0
var _last_montage := -1
var _launched := {}
var _boom_done := false
var _shake := 0.0
var _flash := 0.0
var _cracks: Array[PackedVector2Array] = []
var _rng := RandomNumberGenerator.new()

var _type_label: Label
var _title_center: CenterContainer
var _letters: Array[Label] = []
var _slogan: Label
var _prompt: Label
var _cartoon: Array[CharacterData] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	for id in CARTOON_ORDER:
		var c := GameManager.get_character(id)
		if c != null:
			_cartoon.append(c)
	_build_ui()
	AudioManager.stop_music()


func _build_ui() -> void:
	_type_label = UIStyle.make_label(INTRO_TEXT, 38, UIStyle.CREAM, 0)
	_type_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_type_label.visible_characters = 0
	_type_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_type_label)

	_title_center = CenterContainer.new()
	_title_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title_center.offset_bottom = -110
	_title_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title_center)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", -8)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_center.add_child(vb)
	vb.add_child(_make_letter_row(TITLE_1, 96, UIStyle.YELLOW))
	vb.add_child(_make_letter_row(TITLE_2, 70, UIStyle.ORANGE))

	_slogan = UIStyle.make_label(SLOGAN, 36, UIStyle.CREAM, 10)
	_slogan.set_anchors_preset(Control.PRESET_FULL_RECT)
	_slogan.offset_top = 250
	_slogan.visible = false
	add_child(_slogan)

	_prompt = UIStyle.make_label("TOQUE PARA COMEÇAR", 30, UIStyle.YELLOW, 8)
	_prompt.set_anchors_preset(Control.PRESET_FULL_RECT)
	_prompt.offset_top = 470
	_prompt.visible = false
	add_child(_prompt)

	var version := UIStyle.make_label("protótipo v0.1", 16, Color(1, 1, 1, 0.5), 4, HORIZONTAL_ALIGNMENT_RIGHT)
	version.anchor_left = 1.0
	version.anchor_top = 1.0
	version.anchor_right = 1.0
	version.anchor_bottom = 1.0
	version.offset_left = -200
	version.offset_top = -36
	version.offset_right = -14
	version.offset_bottom = -8
	add_child(version)


func _make_letter_row(text: String, font_size: int, color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 0)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ls := UIStyle.label_settings(font_size, color, 16, true)
	for ch in text:
		var l := Label.new()
		l.text = ch if ch != " " else "  "
		l.label_settings = ls
		l.modulate.a = 0.0
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(l)
		_letters.append(l)
	return row


func _process(delta: float) -> void:
	t += delta
	_update_typewriter()
	_update_montage_sfx()
	_update_cartoon_sfx()
	if t >= T_TITLE and not _boom_done:
		_do_boom()
	if t >= T_SLOGAN and not _slogan.visible:
		_show_slogan()
	if t >= T_PROMPT:
		_prompt.visible = true
		_prompt.modulate.a = 0.55 + 0.45 * sin(t * 5.0)
	_shake = maxf(_shake - delta * 2.2, 0.0)
	_flash = maxf(_flash - delta * 2.5, 0.0)
	position = Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * _shake * 22.0
	queue_redraw()


# ---------------------------------------------------------------- fases

func _update_typewriter() -> void:
	if t < T_TYPE or t >= T_MONTAGE:
		_type_label.visible = false
		return
	_type_label.visible = true
	var n := clampi(int((t - T_TYPE) / TYPE_SPEED), 0, INTRO_TEXT.length())
	if n != _type_label.visible_characters:
		if n > 0 and n % 2 == 0 and INTRO_TEXT[n - 1] != " ":
			AudioManager.play_sfx("type", randf_range(0.9, 1.15), -4.0)
		_type_label.visible_characters = n
	_type_label.modulate.a = clampf((T_MONTAGE - t) / (T_MONTAGE - T_TYPE_FADE), 0.0, 1.0)


func _update_montage_sfx() -> void:
	if t < T_MONTAGE or t >= T_CARTOON:
		return
	var i := int((t - T_MONTAGE) / MONTAGE_STEP)
	if i != _last_montage and i < GameManager.HISTORIC_CARS.size():
		_last_montage = i
		_flash = 0.45
		AudioManager.play_sfx("whoosh", randf_range(0.85, 1.2))


func _cartoon_start(i: int) -> float:
	# os 4 primeiros largam em sequência; o último (ThrustSSC) cruza o centro exatamente no BOOM
	if i == _cartoon.size() - 1:
		return T_TITLE - 0.75
	return T_CARTOON + 0.35 + i * 0.55


func _update_cartoon_sfx() -> void:
	if t < T_CARTOON:
		return
	for i in _cartoon.size():
		if not _launched.has(i) and t >= _cartoon_start(i):
			_launched[i] = true
			AudioManager.play_sfx("honk" if i % 2 == 0 else "boost", randf_range(0.9, 1.2))


func _do_boom() -> void:
	_boom_done = true
	_flash = 1.0
	_shake = 1.0
	AudioManager.play_sfx("boom")
	AudioManager.play_music("menu")
	_make_cracks()
	for i in _letters.size():
		var l := _letters[i]
		l.pivot_offset = l.size * 0.5
		l.scale = Vector2(3.5, 3.5)
		l.rotation = _rng.randf_range(-0.6, 0.6)
		var tw := create_tween().set_parallel(true)
		var d := 0.12 + i * 0.035
		tw.tween_property(l, "modulate:a", 1.0, 0.12).set_delay(d)
		tw.tween_property(l, "scale", Vector2.ONE, 0.45).set_delay(d).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(l, "rotation", _rng.randf_range(-0.06, 0.06), 0.45).set_delay(d).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _show_slogan() -> void:
	_slogan.visible = true
	_slogan.pivot_offset = _slogan.size * 0.5
	_slogan.scale = Vector2(0.2, 0.2)
	var tw := create_tween()
	tw.tween_property(_slogan, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	AudioManager.play_sfx("boing", 1.3)


func _make_cracks() -> void:
	_cracks.clear()
	var c := size * 0.5
	for i in 12:
		var ang := TAU * i / 12.0 + _rng.randf_range(-0.2, 0.2)
		var pts := PackedVector2Array([c])
		var p := c
		var dist := 0.0
		while dist < size.length() * 0.6:
			var step := _rng.randf_range(40, 90)
			dist += step
			p = c + Vector2(cos(ang), sin(ang)) * dist + Vector2(_rng.randf_range(-22, 22), _rng.randf_range(-22, 22))
			pts.append(p)
		_cracks.append(pts)


# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	var pressed := false
	if event is InputEventScreenTouch:
		pressed = (event as InputEventScreenTouch).pressed
	elif event is InputEventKey:
		pressed = (event as InputEventKey).pressed and not (event as InputEventKey).echo
	elif event is InputEventJoypadButton:
		pressed = (event as InputEventJoypadButton).pressed
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	if t < T_PROMPT:
		_skip_to_title()
	elif t >= _accept_at:
		_go_to_menu()


func _skip_to_title() -> void:
	t = T_PROMPT
	_accept_at = T_PROMPT + 0.3
	_type_label.visible = false
	if not _boom_done:
		_boom_done = true
		_make_cracks()
		AudioManager.play_sfx("boom", 1.2, -6.0)
		AudioManager.play_music("menu")
	_flash = 0.6
	for l in _letters:
		l.modulate.a = 1.0
		l.scale = Vector2.ONE
		l.rotation = 0.0
	_slogan.visible = true
	_slogan.scale = Vector2.ONE


func _go_to_menu() -> void:
	_accept_at = INF
	GameManager.intro_seen = true
	GameManager.save_game()
	AudioManager.play_sfx("click")
	GameManager.go_to("menu")


# ---------------------------------------------------------------- desenho

func _draw() -> void:
	var s := size
	draw_rect(Rect2(Vector2(-60, -60), s + Vector2(120, 120)), Color.BLACK)
	if t >= T_MONTAGE and t < T_CARTOON:
		_draw_montage(s)
	elif t >= T_CARTOON:
		_draw_cartoon(s)
	if _boom_done:
		_draw_title_fx(s)
	if _flash > 0.0:
		draw_rect(Rect2(Vector2(-60, -60), s + Vector2(120, 120)), Color(1, 1, 1, _flash))


## Filme antigo sépia com silhuetas históricas.
func _draw_montage(s: Vector2) -> void:
	var i := clampi(int((t - T_MONTAGE) / MONTAGE_STEP), 0, GameManager.HISTORIC_CARS.size() - 1)
	var lt := fmod(t - T_MONTAGE, MONTAGE_STEP) / MONTAGE_STEP
	var info: Dictionary = GameManager.HISTORIC_CARS[i]
	_rng.seed = int(t * 24.0) # tremulação a 24 quadros/s
	var flicker := _rng.randf_range(0.9, 1.0)
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.86, 0.72, 0.48) * flicker)
	draw_circle(s * 0.5, s.x * 0.36, Color(0.95, 0.84, 0.6, 0.5))
	var ground := s.y * 0.7
	draw_rect(Rect2(0, ground, s.x, s.y - ground), Color(0.7, 0.55, 0.35) * flicker)
	draw_line(Vector2(0, ground), Vector2(s.x, ground), CarArt.SIL, 3.0)
	# carro: entra rápido pela direita e "freia" no centro
	var k := 1.0 - pow(1.0 - clampf(lt * 1.8, 0.0, 1.0), 3.0)
	var x := lerpf(s.x + 320.0, s.x * 0.5, k) - lt * 60.0
	for j in 6:
		var ly := ground - 30.0 - j * 22.0
		draw_line(Vector2(x + 180 + j * 25, ly), Vector2(x + 420 + j * 60, ly), Color(0.2, 0.15, 0.1, 0.5), 3.0)
	draw_set_transform(Vector2(x, ground), 0.0, Vector2(1.5, 1.5))
	CarArt.draw_side(self, info["shape"], Color.BLACK, Color.BLACK, true, -t * 20.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# legendas
	UIStyle.draw_text(self, Vector2(s.x * 0.5, s.y * 0.2), info["year"], 92, Color(0.22, 0.14, 0.08), 0, true)
	UIStyle.draw_text(self, Vector2(s.x * 0.5, s.y * 0.84), "%s  ·  %s" % [info["name"], info["kmh"]], 34, Color(0.22, 0.14, 0.08), 0)
	# arranhões, poeira e vinheta
	for j in 3:
		var sx := _rng.randf_range(0, s.x)
		draw_line(Vector2(sx, 0), Vector2(sx + _rng.randf_range(-8, 8), s.y), Color(0.25, 0.18, 0.1, 0.35), 1.5)
	for j in 14:
		draw_circle(Vector2(_rng.randf_range(0, s.x), _rng.randf_range(0, s.y)), _rng.randf_range(1, 3), Color(0.2, 0.12, 0.05, 0.5))
	draw_rect(Rect2(0, 0, s.x, s.y * 0.08), Color.BLACK)
	draw_rect(Rect2(0, s.y * 0.92, s.x, s.y * 0.08), Color.BLACK)


## Cenário cartoon com os pilotos acelerando.
func _draw_cartoon(s: Vector2) -> void:
	var horizon := s.y * 0.55
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(s.x, 0), Vector2(s.x, horizon), Vector2(0, horizon)]),
		PackedColorArray([Color(0.3, 0.6, 1.0), Color(0.3, 0.6, 1.0), Color(1.0, 0.85, 0.6), Color(1.0, 0.85, 0.6)]))
	draw_circle(Vector2(s.x * 0.78, horizon - 40), 90, Color(1, 0.95, 0.6))
	for m in 7:
		var mx := fposmod(m * 260.0 - t * 30.0, s.x + 400.0) - 200.0
		draw_colored_polygon(PackedVector2Array([Vector2(mx - 190, horizon), Vector2(mx, horizon - 110 - (m % 3) * 30), Vector2(mx + 190, horizon)]), Color(0.55, 0.42, 0.68))
	draw_rect(Rect2(0, horizon, s.x, s.y - horizon), Color(0.95, 0.91, 0.82))
	var road_y := s.y * 0.8
	draw_rect(Rect2(0, road_y - 70, s.x, 120), Color(0.33, 0.32, 0.38))
	var dash := fposmod(-t * 1400.0, 120.0)
	var dx := dash - 120.0
	while dx < s.x:
		draw_rect(Rect2(dx, road_y - 14, 60, 8), Color(1, 0.95, 0.8))
		dx += 120.0
	# pilotos (pista de trás primeiro)
	var lanes := [-40.0, 0.0, 30.0, -20.0, 18.0]
	var order := [0, 3, 1, 4, 2]
	for idx in order:
		if idx >= _cartoon.size():
			continue
		var start := _cartoon_start(idx)
		if t < start:
			continue
		var dt := t - start
		var x := -320.0 + 650.0 * dt * dt + 120.0 * dt
		if idx == _cartoon.size() - 1:
			x = -420.0 + (s.x * 0.5 + 420.0) * pow(dt / 0.75, 2.0) if dt <= 0.75 else s.x * 0.5 + (dt - 0.75) * 3200.0
		if x > s.x + 400.0:
			continue
		var y: float = road_y + lanes[idx] + sin(t * 32.0 + idx) * 2.5
		var data := _cartoon[idx]
		# poeira e linhas de velocidade
		for p in 5:
			var px := x - 160.0 - p * 46.0
			draw_circle(Vector2(px, y - 8 - p * 4), 12.0 + p * 7.0, Color(0.95, 0.88, 0.72, 0.6 - p * 0.1))
		for j in 4:
			var ly := y - 40.0 - j * 22.0
			draw_line(Vector2(x - 200 - j * 30, ly), Vector2(x - 420 - j * 50, ly), Color(1, 1, 1, 0.7), 4.0)
		var lane_off: float = lanes[idx]
		var sc := 0.62 + (lane_off + 40.0) / 70.0 * 0.12
		CarArt.draw_side_for(self, data, Vector2(x, y), sc, x / 24.0)
		if idx == _cartoon.size() - 1 and dt > 0.55 and dt < 1.4:
			# cone de vapor da barreira do som
			var a := clampf(1.4 - dt, 0.0, 0.7)
			draw_colored_polygon(PackedVector2Array([Vector2(x + 110, y - 50), Vector2(x - 120, y - 150), Vector2(x - 120, y + 50)]), Color(1, 1, 1, a))
			draw_circle(Vector2(x + 100, y - 50), 60, Color(1, 1, 1, a * 0.8))


## Pós-BOOM: raios de fundo do título, ondas de choque e "rachaduras" da barreira do som.
func _draw_title_fx(s: Vector2) -> void:
	var c := s * 0.5
	var bt := t - T_TITLE
	var reach := s.length()
	var rays := 18
	var bg_alpha := clampf(bt * 1.5, 0.0, 0.92)
	draw_rect(Rect2(Vector2(-60, -60), s + Vector2(120, 120)), Color(0.18, 0.08, 0.3, bg_alpha))
	for i in rays:
		var a0 := TAU * i / rays + t * 0.15
		var a1 := a0 + TAU / rays * 0.5
		draw_colored_polygon(PackedVector2Array([c, c + Vector2(cos(a0), sin(a0)) * reach, c + Vector2(cos(a1), sin(a1)) * reach]),
			Color(1.0, 0.6, 0.15, 0.22 * bg_alpha))
	for k in 3:
		var rt := bt - k * 0.18
		if rt > 0.0 and rt < 1.4:
			var r := rt * 1500.0
			draw_arc(c, r, 0, TAU, 64, Color(1, 1, 1, (1.4 - rt) * 0.6), maxf(30.0 - rt * 20.0, 2.0), true)
	var crack_a := clampf(1.0 - bt * 0.5, 0.18, 1.0)
	for pts in _cracks:
		draw_polyline(pts, Color(1, 1, 1, crack_a), 4.0, true)
		draw_polyline(pts, Color(0.1, 0.05, 0.2, crack_a * 0.6), 1.5, true)
