class_name RaceHUD
extends CanvasLayer
## HUD MOBILE-FRIENDLY da corrida. Tudo desenhado por código (sem assets obrigatórios):
##  * Topo-esq.: retrato, posição (1º/5), volta, tempo   * Topo-dir.: minimapa + pausa
##  * Baixo-esq.: FREIO   * Baixo-centro: velocímetro + recorde   * Baixo-dir.: ITEM e ESPECIAL
##  * Centro: contagem regressiva e mensagens ("VOLTA FINAL!", "MACH 1!")
##  * Indicador do dedo ao arrastar, linhas de velocidade no turbo e dicas de controle na largada.
## Os botões NÃO usam o sistema de GUI: o TouchInput pergunta get_button_at(pos) — isso
## permite multi-toque real (segurar para acelerar + apertar item ao mesmo tempo).


class HudButton extends Control:
	var id := ""
	var radius := 60.0
	var color := Color.WHITE
	var pressed := false
	var hud: RaceHUD

	func _init(p_id: String, p_radius: float, p_color: Color, p_hud: RaceHUD) -> void:
		id = p_id
		radius = p_radius
		color = p_color
		hud = p_hud
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(radius, radius) * 2.0

	func center_global() -> Vector2:
		return global_position + size * 0.5

	func hit(p: Vector2) -> bool:
		return is_visible_in_tree() and p.distance_to(center_global()) <= radius * 1.2

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var r := radius * (0.9 if pressed else 1.0)
		draw_circle(c + Vector2(0, 6), r, Color(0, 0, 0, 0.3))
		draw_circle(c, r + 4.0, UIStyle.INK)
		draw_circle(c, r, Color(color, 0.9 if pressed else 0.72))
		hud.draw_button_content(self, c, r)


class Speedo extends Control:
	var hud: RaceHUD

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var p := hud.player
		if p == null:
			return
		var kmh := p.velocity.length() * Car.KMH
		var c := Vector2(size.x * 0.5, size.y - 12.0)
		var r := 104.0
		var max_kmh := 1400.0
		draw_arc(c, r, PI, TAU, 40, UIStyle.INK, 22.0, true)
		var k := clampf(kmh / max_kmh, 0.0, 1.0)
		var col := UIStyle.GREEN.lerp(UIStyle.YELLOW, clampf(k * 2.0, 0.0, 1.0)).lerp(UIStyle.RED, clampf(k * 2.0 - 1.0, 0.0, 1.0))
		if k > 0.01:
			draw_arc(c, r, PI, PI + PI * k, 40, col, 14.0, true)
		# marcas: recorde da pista e Mach 1
		var rec := hud.record_speed()
		if rec > 0.0:
			var ra := PI + PI * clampf(rec / max_kmh, 0.0, 1.0)
			draw_line(c + Vector2(cos(ra), sin(ra)) * (r - 16), c + Vector2(cos(ra), sin(ra)) * (r + 16), UIStyle.YELLOW, 4.0)
		var ma := PI + PI * (GameManager.MACH_1_KMH / max_kmh)
		draw_line(c + Vector2(cos(ma), sin(ma)) * (r - 16), c + Vector2(cos(ma), sin(ma)) * (r + 16), Color(0.6, 0.9, 1.0), 4.0)
		var na := PI + PI * k
		draw_line(c, c + Vector2(cos(na), sin(na)) * (r - 6), UIStyle.CREAM, 5.0, true)
		draw_circle(c, 9.0, UIStyle.INK)
		UIStyle.draw_text(self, c + Vector2(0, -42), "%d" % int(kmh), 42, UIStyle.CREAM, 8, true)
		UIStyle.draw_text(self, c + Vector2(0, -12), "km/h", 18, UIStyle.CREAM, 5)
		var rec_txt := "RECORDE: %d km/h" % int(rec) if rec > 0.0 else "SEM RECORDE AINDA"
		UIStyle.draw_text(self, Vector2(size.x * 0.5, -6), rec_txt, 17, UIStyle.YELLOW, 5)


class Minimap extends Control:
	var race: RaceController
	var pts := PackedVector2Array()
	var _origin := Vector2.ZERO
	var _k := 1.0
	var _off := Vector2.ZERO

	func setup(p_race: RaceController) -> void:
		race = p_race
		var b := Rect2(race.track.baked[0], Vector2.ZERO)
		for p in race.track.baked:
			b = b.expand(p)
		var pad := 12.0
		_k = minf((size.x - pad * 2.0) / maxf(b.size.x, 1.0), (size.y - pad * 2.0) / maxf(b.size.y, 1.0))
		_origin = b.position
		_off = (size - b.size * _k) * 0.5
		pts.clear()
		for i in range(0, race.track.baked.size(), 4):
			pts.append(to_map(race.track.baked[i]))
		pts.append(pts[0])

	func to_map(p: Vector2) -> Vector2:
		return (p - _origin) * _k + _off

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if race == null:
			return
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.07, 0.17, 0.55))
		draw_polyline(pts, UIStyle.INK, 10.0, true)
		draw_polyline(pts, Color(0.85, 0.82, 0.78), 5.0, true)
		draw_circle(to_map(race.track.sample(0.0)), 5.0, Color.WHITE)
		for c in race.cars:
			var m := to_map(c.global_position)
			var rr := 8.0 if c.is_player else 6.0
			draw_circle(m, rr + 2.5, UIStyle.CREAM if c.is_player else UIStyle.INK)
			draw_circle(m, rr, c.data.body_color)


class Overlay extends Control:
	var hud: RaceHUD
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		var p := hud.player
		if p == null:
			return
		# linhas de velocidade (turbo)
		if p.boost_timer > 0.0:
			var rng := RandomNumberGenerator.new()
			rng.seed = int(t * 30.0)
			var c := size * 0.5
			for i in 28:
				var a := rng.randf() * TAU
				var d := Vector2(cos(a), sin(a))
				var r0 := size.length() * rng.randf_range(0.32, 0.45)
				draw_line(c + d * r0, c + d * size.length() * 0.6, Color(1, 1, 1, 0.35), rng.randf_range(2.0, 5.0))
		# indicador do dedo (arrastar para virar)
		var touch := hud.race.touch
		if touch != null and touch.drive_active:
			draw_arc(touch.anchor, TouchInput.STEER_RANGE, 0, TAU, 40, Color(1, 1, 1, 0.25), 4.0, true)
			draw_line(touch.anchor - Vector2(TouchInput.STEER_RANGE, 0), touch.anchor + Vector2(TouchInput.STEER_RANGE, 0), Color(1, 1, 1, 0.2), 3.0)
			var knob := touch.anchor + Vector2(touch.steer_value * TouchInput.STEER_RANGE, 0)
			draw_circle(knob, 34.0, Color(1, 1, 1, 0.3))
			draw_arc(knob, 34.0, 0, TAU, 24, Color(1, 1, 1, 0.6), 3.0, true)
		# contramão
		if p.wrong_way_time > 1.0 and fmod(t, 0.6) < 0.4:
			UIStyle.draw_text(self, Vector2(size.x * 0.5, size.y * 0.42), "CONTRAMÃO!", 54, UIStyle.RED, 10, true)


class Tutorial extends Control:
	func _draw() -> void:
		var hints := [["ui_touch_hold", "SEGURE", "acelera"], ["ui_touch_swipe", "ARRASTE", "vira"], ["ui_touch_double", "TOQUE DUPLO", "especial"]]
		var w := 210.0
		var x0 := size.x * 0.5 - w * 1.5
		for i in hints.size():
			var h: Array = hints[i]
			var c := Vector2(x0 + w * i + w * 0.5, 60)
			draw_rect(Rect2(c.x - w * 0.5 + 8, 0, w - 16, 132), Color(0.1, 0.07, 0.17, 0.75))
			var tex := AssetLib.texture(h[0])
			if tex != null:
				draw_texture_rect(tex, Rect2(c - Vector2(30, 40), Vector2(60, 60)), false)
			else:
				_draw_hand(i, c + Vector2(0, -12))
			UIStyle.draw_text(self, c + Vector2(0, 38), h[1], 22, UIStyle.YELLOW, 5, true)
			UIStyle.draw_text(self, c + Vector2(0, 60), h[2], 18, UIStyle.CREAM, 4)

	func _draw_hand(kind: int, c: Vector2) -> void:
		draw_circle(c, 16.0, UIStyle.CREAM)
		draw_arc(c, 16.0, 0, TAU, 20, UIStyle.INK, 3.0, true)
		match kind:
			0:
				draw_arc(c, 26.0, 0, TAU, 24, Color(UIStyle.CREAM, 0.6), 3.0, true)
			1:
				for s in [-1.0, 1.0]:
					var tip := c + Vector2(s * 48.0, 0)
					draw_line(c + Vector2(s * 22.0, 0), tip, UIStyle.CREAM, 4.0)
					draw_line(tip, tip + Vector2(-s * 10.0, -8), UIStyle.CREAM, 4.0)
					draw_line(tip, tip + Vector2(-s * 10.0, 8), UIStyle.CREAM, 4.0)
			_:
				draw_arc(c, 24.0, 0, TAU, 24, Color(UIStyle.CREAM, 0.7), 3.0, true)
				draw_arc(c, 32.0, 0, TAU, 24, Color(UIStyle.CREAM, 0.4), 3.0, true)
				UIStyle.draw_text(self, c + Vector2(34, -20), "x2", 20, UIStyle.YELLOW, 4, true)


var race: RaceController
var player: Car

var _root: Control
var _portrait: Control
var _pos_label: Label
var _pos_total: Label
var _lap_label: Label
var _time_label: Label
var _msg: Label
var _msg_tween: Tween
var _buttons := {}
var _speedo: Speedo
var _minimap: Minimap
var _overlay: Overlay
var _tutorial: Tutorial
var _item_shown := ""
var _rolling := false
var _last_roll_icon := -1
var _record_at_start := 0.0
var _record_announced := false
var _t := 0.0


func setup(p_race: RaceController) -> void:
	race = p_race
	player = race.player
	_record_at_start = GameManager.track_top_speed()
	_build()
	player.item_changed.connect(_on_item_changed)
	GameManager.settings_changed.connect(_apply_settings)
	get_viewport().size_changed.connect(_layout)
	_layout()
	_layout.call_deferred()
	_apply_settings()


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_overlay = Overlay.new()
	_overlay.hud = self
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_overlay)

	_portrait = Control.new()
	_portrait.size = Vector2(96, 96)
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait.draw.connect(func() -> void: CarArt.draw_portrait(_portrait, player.data, Vector2(48, 48), 42))
	_root.add_child(_portrait)
	_pos_label = _hud_label(68, UIStyle.YELLOW, true)
	_pos_total = _hud_label(30, UIStyle.CREAM, true)
	_lap_label = _hud_label(26, UIStyle.CREAM, true)
	_time_label = _hud_label(22, UIStyle.CREAM, false)

	_minimap = Minimap.new()
	_minimap.size = Vector2(210, 150)
	_minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_minimap)
	_minimap.setup(race)

	_speedo = Speedo.new()
	_speedo.hud = self
	_speedo.size = Vector2(260, 130)
	_speedo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_speedo)

	_add_button("pause", 32.0, Color(0.75, 0.72, 0.8))
	_add_button("brake", 62.0, UIStyle.RED)
	_add_button("item", 72.0, UIStyle.YELLOW)
	_add_button("special", 56.0, UIStyle.TEAL)

	_msg = Label.new()
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_msg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_msg.visible = false
	_root.add_child(_msg)

	_tutorial = Tutorial.new()
	_tutorial.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tutorial.visible = false
	_root.add_child(_tutorial)


func _hud_label(size: int, color: Color, title: bool) -> Label:
	var l := Label.new()
	l.label_settings = UIStyle.label_settings(size, color, 8, title)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(l)
	return l


func _add_button(id: String, radius: float, color: Color) -> void:
	var b := HudButton.new(id, radius, color, self)
	_root.add_child(b)
	_buttons[id] = b


func _safe_margins() -> Rect2:
	# x = esquerda, y = topo, w = direita, h = baixo (em pixels do viewport)
	var m := Rect2(22, 18, 22, 18)
	if not GameManager.is_mobile():
		return m
	var safe := DisplayServer.get_display_safe_area()
	var screen := DisplayServer.screen_get_size()
	if screen.x <= 0 or screen.y <= 0:
		return m
	var vs := _root.size
	var kx := vs.x / float(screen.x)
	var ky := vs.y / float(screen.y)
	m.position.x += safe.position.x * kx
	m.position.y += safe.position.y * ky
	m.size.x += (screen.x - safe.end.x) * kx
	m.size.y += (screen.y - safe.end.y) * ky
	return m


func _layout() -> void:
	if _root == null:
		return
	var vs := _root.size
	if vs.x < 10.0:
		vs = get_viewport().get_visible_rect().size
	var m := _safe_margins()
	var l := m.position.x
	var t := m.position.y
	var r := vs.x - m.size.x
	var b := vs.y - m.size.y
	_portrait.position = Vector2(l, t)
	_pos_label.position = Vector2(l + 104, t - 14)
	_pos_total.position = Vector2(l + 172, t + 14)
	_lap_label.position = Vector2(l + 106, t + 60)
	_time_label.position = Vector2(l + 6, t + 100)
	var pause: HudButton = _buttons["pause"]
	pause.position = Vector2(r - pause.size.x, t)
	_minimap.position = Vector2(r - pause.size.x - 16 - _minimap.size.x, t)
	_speedo.position = Vector2(vs.x * 0.5 - _speedo.size.x * 0.5, b - _speedo.size.y)
	var brake: HudButton = _buttons["brake"]
	brake.position = Vector2(l, b - brake.size.y)
	var item: HudButton = _buttons["item"]
	item.position = Vector2(r - item.size.x, b - item.size.y)
	var special: HudButton = _buttons["special"]
	special.position = Vector2(r - item.size.x * 0.5 - special.size.x * 0.5 - 6, b - item.size.y - 22 - special.size.y)
	_msg.position = Vector2(0, vs.y * 0.22)
	_msg.size = Vector2(vs.x, 160)
	_msg.pivot_offset = _msg.size * 0.5
	_tutorial.position = Vector2(0, vs.y * 0.52)
	_tutorial.size = Vector2(vs.x, 140)


func _apply_settings() -> void:
	var show_extra := bool(GameManager.settings["show_buttons"])
	(_buttons["brake"] as HudButton).visible = show_extra
	(_buttons["special"] as HudButton).visible = show_extra


# ---------------------------------------------------------------- API usada pelo TouchInput

func get_button_at(pos: Vector2) -> String:
	for id in _buttons:
		var b: HudButton = _buttons[id]
		if b.hit(pos):
			return id
	return ""


func set_button_pressed(id: String, on: bool) -> void:
	if _buttons.has(id):
		(_buttons[id] as HudButton).pressed = on


# ---------------------------------------------------------------- mensagens

func show_message(text: String, color: Color = UIStyle.YELLOW, duration: float = 1.2, size: int = 64) -> void:
	_msg.text = text
	_msg.label_settings = UIStyle.label_settings(size, color, 14, true)
	_msg.visible = true
	_msg.modulate.a = 1.0
	_msg.scale = Vector2(0.3, 0.3)
	if _msg_tween != null and _msg_tween.is_valid():
		_msg_tween.kill()
	_msg_tween = create_tween()
	_msg_tween.tween_property(_msg, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_msg_tween.tween_interval(duration)
	_msg_tween.tween_property(_msg, "modulate:a", 0.0, 0.3)


func show_countdown(n: int) -> void:
	if n > 0:
		show_message(str(n), UIStyle.YELLOW, 0.5, 150)
	else:
		show_message("JÁ!", UIStyle.GREEN, 0.7, 150)


func show_tutorial(on: bool) -> void:
	if on and not bool(GameManager.settings["show_tutorial"]):
		return
	if on:
		_tutorial.visible = true
		_tutorial.modulate.a = 1.0
		_tutorial.queue_redraw()
	elif _tutorial.visible:
		var tw := create_tween()
		tw.tween_property(_tutorial, "modulate:a", 0.0, 0.6)
		tw.tween_callback(_tutorial.hide)


func record_speed() -> float:
	return maxf(_record_at_start, 0.0)


# ---------------------------------------------------------------- atualização

func _process(delta: float) -> void:
	if player == null:
		return
	_t += delta
	_pos_label.text = "%dº" % player.position_rank
	_pos_total.text = "/%d" % race.cars.size()
	_lap_label.text = "FIM!" if player.finished else "VOLTA %d/%d" % [player.current_lap(), race.total_laps]
	_time_label.text = GameManager.format_time(race.race_time) if race.race_time > 0.0 else "0:00.00"
	_portrait.queue_redraw()
	if _rolling:
		var icon := int(_t * 14.0) % PowerUps.ALL.size()
		if icon != _last_roll_icon:
			_last_roll_icon = icon
			AudioManager.play_sfx("roll", 1.0 + icon * 0.05, -8.0)
	if not _record_announced and _record_at_start > 0.0 and player.top_speed > _record_at_start:
		_record_announced = true
		show_message("NOVO RECORDE DE VELOCIDADE!", UIStyle.ORANGE, 1.4, 44)
		AudioManager.play_sfx("record")


func _on_item_changed(item: String) -> void:
	if item == "?":
		_rolling = true
		return
	_rolling = false
	_item_shown = item
	if item != "":
		var b: HudButton = _buttons["item"]
		b.pivot_offset = b.size * 0.5
		b.scale = Vector2(1.3, 1.3)
		var tw := create_tween()
		tw.tween_property(b, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		AudioManager.play_sfx("star")


## Conteúdo de cada botão (chamado pelo HudButton._draw).
func draw_button_content(b: HudButton, c: Vector2, r: float) -> void:
	match b.id:
		"pause":
			b.draw_rect(Rect2(c + Vector2(-11, -12), Vector2(8, 24)), UIStyle.INK)
			b.draw_rect(Rect2(c + Vector2(3, -12), Vector2(8, 24)), UIStyle.INK)
		"brake":
			b.draw_rect(Rect2(c + Vector2(-20, -24), Vector2(40, 30)), UIStyle.INK)
			b.draw_rect(Rect2(c + Vector2(-16, -20), Vector2(32, 22)), Color(0.75, 0.75, 0.8))
			UIStyle.draw_text(b, c + Vector2(0, 24), "FREIO", 20, UIStyle.CREAM, 5, true)
		"item":
			var id := _item_shown
			if _rolling:
				id = PowerUps.ALL[int(_t * 14.0) % PowerUps.ALL.size()]
			if id != "":
				PowerUps.draw_icon(b, id, c + Vector2(0, -6), r * 1.1)
				UIStyle.draw_text(b, c + Vector2(0, r * 0.62), "" if _rolling else PowerUps.item_name(id), 15, UIStyle.CREAM, 4)
			else:
				UIStyle.draw_text(b, c, "ITEM", 24, Color(UIStyle.CREAM, 0.6), 5, true)
		"special":
			var charge := player.special_charge
			CarArt.draw_portrait(b, player.data, c, r * 0.66)
			b.draw_arc(c, r - 3.0, -PI * 0.5, -PI * 0.5 + TAU * charge, 40, UIStyle.YELLOW, 7.0, true)
			if charge >= 1.0:
				var pulse := 0.5 + 0.5 * sin(_t * 8.0)
				b.draw_arc(c, r + 8.0 + pulse * 4.0, 0, TAU, 40, Color(UIStyle.YELLOW, 0.4 + pulse * 0.5), 5.0, true)
				UIStyle.draw_text(b, c + Vector2(0, r + 20), "TOQUE DUPLO!", 16, UIStyle.YELLOW, 5, true)
