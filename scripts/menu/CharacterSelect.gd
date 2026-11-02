extends Control
## SELEÇÃO DE PERSONAGEM (modo "play") e GALERIA de personagens (modo "gallery").
## Toque num retrato da faixa inferior, use as setas ou deslize no palco para trocar.

## Barra de atributo (1..5) desenhada.
class StatBar extends Control:
	var label := ""
	var value := 3.0
	var color := Color.WHITE

	func _init(p_label: String, p_color: Color) -> void:
		label = p_label
		color = p_color
		custom_minimum_size = Vector2(240, 30)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var font := AssetLib.font_or_default("body")
		draw_string_outline(font, Vector2(0, 21), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 5, UIStyle.INK)
		draw_string(font, Vector2(0, 21), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UIStyle.CREAM)
		var x0 := 112.0
		var w := (size.x - x0) / 5.0
		for i in 5:
			var r := Rect2(x0 + i * w + 2, 6, w - 6, 18)
			draw_rect(r, UIStyle.INK)
			var fill := clampf(value - i, 0.0, 1.0)
			if fill > 0.0:
				draw_rect(Rect2(r.position + Vector2(2, 2), Vector2((r.size.x - 4) * fill, r.size.y - 4)), color)


var _index := 0
var _entries: Array = [] # CharacterData ou Dictionary (carro bloqueado)
var _t := 0.0
var _car_offset := 0.0
var _press_pos := Vector2.ZERO
var _pressing := false

var _title: Label
var _name: Label
var _sub: Label
var _bio: Label
var _quote: Label
var _special_title: Label
var _special_desc: Label
var _bars: Array[StatBar] = []
var _go_button: Button


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	AudioManager.play_music("menu")
	for c in GameManager.roster:
		_entries.append(c)
	for locked in GameManager.LOCKED_CARS:
		_entries.append(locked)
	for i in GameManager.roster.size():
		if GameManager.roster[i].id == GameManager.selected_id:
			_index = i
	_build_ui()
	_refresh(false)


func _is_play() -> bool:
	return GameManager.select_mode == "play"


func _build_ui() -> void:
	_title = UIStyle.make_label("ESCOLHA SEU PILOTO" if _is_play() else "PERSONAGENS", 46, UIStyle.YELLOW, 12, HORIZONTAL_ALIGNMENT_CENTER, true)
	_title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_title.offset_top = 10
	_title.offset_bottom = 80
	add_child(_title)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 20
	panel.offset_right = -28
	panel.offset_top = 86
	panel.offset_bottom = -146
	add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	panel.add_child(vb)
	_name = UIStyle.make_label("", 40, UIStyle.YELLOW, 10, HORIZONTAL_ALIGNMENT_LEFT, true)
	vb.add_child(_name)
	_sub = UIStyle.make_label("", 18, UIStyle.TEAL, 5, HORIZONTAL_ALIGNMENT_LEFT)
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_sub)
	_bio = UIStyle.make_label("", 19, UIStyle.CREAM, 4, HORIZONTAL_ALIGNMENT_LEFT)
	_bio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bio.custom_minimum_size = Vector2(300, 0)
	vb.add_child(_bio)
	_quote = UIStyle.make_label("", 19, UIStyle.ORANGE, 5, HORIZONTAL_ALIGNMENT_LEFT)
	_quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_quote)
	_special_title = UIStyle.make_label("", 20, UIStyle.YELLOW, 6, HORIZONTAL_ALIGNMENT_LEFT)
	vb.add_child(_special_title)
	_special_desc = UIStyle.make_label("", 18, UIStyle.CREAM, 4, HORIZONTAL_ALIGNMENT_LEFT)
	_special_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_special_desc)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(spacer)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	vb.add_child(grid)
	var specs := [["Velocidade", UIStyle.RED], ["Aceleração", UIStyle.ORANGE], ["Controle", UIStyle.TEAL], ["Peso", UIStyle.BLUE]]
	for sp in specs:
		var bar := StatBar.new(sp[0], sp[1])
		grid.add_child(bar)
		_bars.append(bar)

	var back := UIStyle.make_button("VOLTAR", Vector2(220, 72), Color(0.75, 0.72, 0.8))
	back.anchor_top = 1.0
	back.anchor_bottom = 1.0
	back.offset_left = 26
	back.offset_top = -96
	back.offset_right = 246
	back.offset_bottom = -22
	back.pressed.connect(_on_back)
	add_child(back)

	_go_button = UIStyle.make_button("CORRER!", Vector2(240, 80), UIStyle.ORANGE)
	_go_button.add_theme_font_size_override("font_size", 36)
	_go_button.anchor_left = 1.0
	_go_button.anchor_right = 1.0
	_go_button.anchor_top = 1.0
	_go_button.anchor_bottom = 1.0
	_go_button.offset_left = -270
	_go_button.offset_top = -102
	_go_button.offset_right = -26
	_go_button.offset_bottom = -22
	_go_button.pressed.connect(_on_go)
	_go_button.visible = _is_play()
	add_child(_go_button)

	var prev := UIStyle.make_button("<", Vector2(64, 72), UIStyle.TEAL)
	prev.offset_left = 18
	prev.offset_top = 330
	prev.offset_right = 82
	prev.offset_bottom = 402
	prev.pressed.connect(_change.bind(-1))
	add_child(prev)
	var next := UIStyle.make_button(">", Vector2(64, 72), UIStyle.TEAL)
	next.anchor_left = 0.5
	next.anchor_right = 0.5
	next.offset_left = -76
	next.offset_top = 330
	next.offset_right = -12
	next.offset_bottom = 402
	next.pressed.connect(_change.bind(1))
	add_child(next)


func _change(dir: int) -> void:
	_index = wrapi(_index + dir, 0, _entries.size())
	_car_offset = 260.0 * dir
	_refresh(true)


func _refresh(play_sound: bool) -> void:
	var e = _entries[_index]
	if e is CharacterData:
		var c := e as CharacterData
		_name.text = c.display_name
		_sub.text = "%s  ·  %s (%d)  ·  recorde real: %s km/h" % [c.nationality, c.car_name, c.car_year, _fmt_kmh(c.car_record_kmh)]
		_bio.text = c.bio
		_quote.text = "“%s”" % c.catchphrase
		_special_title.text = "ESPECIAL (toque duplo): %s" % c.special_name
		_special_desc.text = c.special_desc
		var vals := [c.stat_speed(), c.stat_accel(), c.stat_handling(), c.stat_weight()]
		for i in _bars.size():
			_bars[i].value = vals[i]
			_bars[i].queue_redraw()
			_bars[i].visible = true
		_go_button.disabled = false
		if play_sound:
			AudioManager.play_sfx("honk", 0.8 + 0.1 * _index)
	else:
		var d: Dictionary = e
		_name.text = "???"
		_sub.text = "%s (%d)  ·  recorde real: %s km/h" % [d["car_name"], d["car_year"], _fmt_kmh(float(d["car_record_kmh"]))]
		_bio.text = "Um novo piloto maluco está a caminho... Este carro histórico chega numa próxima atualização!"
		_quote.text = ""
		_special_title.text = "EM BREVE"
		_special_desc.text = "Crie um CharacterData (.tres) com car_shape = \"%s\" para liberar." % d["car_shape"]
		for b in _bars:
			b.visible = false
		_go_button.disabled = true
		if play_sound:
			AudioManager.play_sfx("ops")


static func _fmt_kmh(v: float) -> String:
	var s := "%.0f" % v
	if s.length() > 3:
		s = s.substr(0, s.length() - 3) + "." + s.substr(s.length() - 3)
	return s


func _process(delta: float) -> void:
	_t += delta
	_car_offset = lerpf(_car_offset, 0.0, 1.0 - exp(-10.0 * delta))
	queue_redraw()


func _draw() -> void:
	var s := size
	# fundo: listras diagonais em movimento
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.16, 0.1, 0.28))
	var stripe := 90.0
	var off := fposmod(_t * 40.0, stripe * 2.0)
	var x := -s.y - stripe * 2.0 + off
	while x < s.x:
		draw_colored_polygon(PackedVector2Array([Vector2(x, s.y), Vector2(x + stripe, s.y), Vector2(x + stripe + s.y, 0), Vector2(x + s.y, 0)]), Color(0.2, 0.13, 0.34))
		x += stripe * 2.0
	var lc := s.x * 0.25 + 10.0
	# holofote e pedestal
	draw_colored_polygon(PackedVector2Array([Vector2(lc - 40, 70), Vector2(lc + 40, 70), Vector2(lc + 230, 470), Vector2(lc - 210, 470)]), Color(1, 0.95, 0.7, 0.08))
	draw_colored_polygon(CarArt.ellipse(Vector2(lc + 10, 468), Vector2(200, 34), 32), UIStyle.INK)
	draw_colored_polygon(CarArt.ellipse(Vector2(lc + 10, 460), Vector2(194, 30), 32), Color(0.35, 0.25, 0.55))
	var rim := CarArt.ellipse(Vector2(lc + 10, 460), Vector2(194, 30), 40)
	rim.append(rim[0])
	draw_polyline(rim, UIStyle.YELLOW, 3.0, true)
	var e = _entries[_index]
	var bounce := absf(sin(_t * 6.0)) * 3.0
	if e is CharacterData:
		var c := e as CharacterData
		CarArt.draw_portrait(self, c, Vector2(lc - 120, 200), 76)
		# fumaça do escapamento
		for p in 4:
			var pt := fmod(_t * 1.2 + p * 0.25, 1.0)
			draw_circle(Vector2(lc + 10 - 150 - pt * 120 + _car_offset, 440 - pt * 40), 8 + pt * 22, Color(1, 1, 1, 0.35 * (1.0 - pt)))
		CarArt.draw_side_for(self, c, Vector2(lc + 10 + _car_offset, 462 - bounce), 0.95, _t * 3.0)
	else:
		var d: Dictionary = e
		CarArt.draw_locked_portrait(self, Vector2(lc - 120, 200), 76)
		draw_set_transform(Vector2(lc + 10 + _car_offset, 462), 0.0, Vector2(0.95, 0.95))
		CarArt.draw_side(self, d["car_shape"], Color.BLACK, Color.BLACK, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		UIStyle.draw_text(self, Vector2(lc + 10, 300), "EM BREVE", 40, UIStyle.ORANGE, 10, true)
	_draw_roster_strip(s)


func _card_centers(s: Vector2) -> Array[Vector2]:
	var n := _entries.size()
	var gap := 96.0
	var out: Array[Vector2] = []
	var start := s.x * 0.5 - gap * (n - 1) * 0.5
	for i in n:
		out.append(Vector2(start + gap * i, s.y - 66))
	return out


func _draw_roster_strip(s: Vector2) -> void:
	var centers := _card_centers(s)
	for i in centers.size():
		var c := centers[i]
		var sel := i == _index
		var r := 40.0 if sel else 34.0
		if sel:
			c.y -= 6.0 + absf(sin(_t * 5.0)) * 4.0
			draw_circle(c, r + 9.0, UIStyle.YELLOW)
		var e = _entries[i]
		if e is CharacterData:
			CarArt.draw_portrait(self, e as CharacterData, c, r)
		else:
			CarArt.draw_locked_portrait(self, c, r)


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			_pressing = true
			_press_pos = mb.position
		elif _pressing:
			_pressing = false
			var delta := mb.position - _press_pos
			if absf(delta.x) > 70.0 and absf(delta.x) > absf(delta.y):
				_change(-1 if delta.x > 0.0 else 1)
				return
			var centers := _card_centers(size)
			for i in centers.size():
				if mb.position.distance_to(centers[i]) < 46.0 and i != _index:
					_car_offset = 260.0 * signf(i - _index)
					_index = i
					_refresh(true)
					return


func _on_go() -> void:
	var e = _entries[_index]
	if not (e is CharacterData):
		return
	GameManager.selected_id = (e as CharacterData).id
	GameManager.save_game()
	AudioManager.play_sfx("go")
	GameManager.go_to("race")


func _on_back() -> void:
	GameManager.go_to("menu")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back()
