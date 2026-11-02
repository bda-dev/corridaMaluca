extends Control
## MENU PRINCIPAL: Jogar, Personagens, Opções (+ Sair no PC).
## Fundo animado: salar ao entardecer com os pilotos passando em alta velocidade.

var _logo_1: Label
var _logo_2: Label
var _buttons: VBoxContainer
var _records: Label
var _t := 0.0
var _racers: Array = [] # [{data, x, speed, lane}]
var _spawn_timer := 0.5
var _options: OptionsPanel


func _ready() -> void:
	AudioManager.play_music("menu")
	_build_ui()
	_animate_in()


func _build_ui() -> void:
	var top := VBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_top = 18
	top.offset_bottom = 200
	top.add_theme_constant_override("separation", -10)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	_logo_1 = UIStyle.make_label("CORRIDA MALUCA", 82, UIStyle.YELLOW, 16, HORIZONTAL_ALIGNMENT_CENTER, true)
	_logo_2 = UIStyle.make_label("DOS RECORDES", 58, UIStyle.ORANGE, 14, HORIZONTAL_ALIGNMENT_CENTER, true)
	top.add_child(_logo_1)
	top.add_child(_logo_2)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_top = 190
	center.offset_bottom = -150
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 14)
	center.add_child(_buttons)

	var play := UIStyle.make_button("JOGAR", Vector2(360, 86), UIStyle.ORANGE)
	play.add_theme_font_size_override("font_size", 40)
	play.pressed.connect(_on_play)
	_buttons.add_child(play)
	var chars := UIStyle.make_button("PERSONAGENS", Vector2(360, 70))
	chars.pressed.connect(_on_characters)
	_buttons.add_child(chars)
	var opts := UIStyle.make_button("OPÇÕES", Vector2(360, 70), UIStyle.TEAL)
	opts.pressed.connect(_on_options)
	_buttons.add_child(opts)
	if not GameManager.is_mobile() and not OS.has_feature("web"):
		var quit := UIStyle.make_button("SAIR", Vector2(360, 60), Color(0.75, 0.72, 0.8))
		quit.add_theme_font_size_override("font_size", 24)
		quit.pressed.connect(func() -> void: get_tree().quit())
		_buttons.add_child(quit)

	_records = UIStyle.make_label("", 20, UIStyle.CREAM, 6)
	_records.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_records.offset_top = -40
	_records.offset_bottom = -8
	add_child(_records)
	_refresh_records()


func _refresh_records() -> void:
	var r := GameManager.get_record(GameManager.track_id)
	if int(r["races"]) == 0:
		_records.text = "%s  ·  Nenhum recorde ainda — vá quebrar algum!" % GameManager.track_name
		return
	_records.text = "%s  ·  Melhor tempo %s  ·  Vel. máx %d km/h  ·  Pontos %d  ·  Vitórias %d" % [
		GameManager.track_name, GameManager.format_time(float(r["best_time"])),
		int(r["top_speed"]), int(r["best_score"]), int(r["wins"])]


func _animate_in() -> void:
	for i in _buttons.get_child_count():
		var b := _buttons.get_child(i) as Control
		b.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_interval(0.1 + i * 0.08)
		tw.tween_property(b, "modulate:a", 1.0, 0.25)


func _process(delta: float) -> void:
	_t += delta
	_logo_1.pivot_offset = _logo_1.size * 0.5
	_logo_1.rotation = sin(_t * 2.0) * 0.02
	_logo_2.pivot_offset = _logo_2.size * 0.5
	_logo_2.scale = Vector2.ONE * (1.0 + sin(_t * 4.0) * 0.025)
	_spawn_timer -= delta
	if _spawn_timer <= 0.0 and GameManager.roster.size() > 0:
		_spawn_timer = randf_range(1.6, 3.2)
		_racers.append({"data": GameManager.roster.pick_random(), "x": -260.0,
			"speed": randf_range(650.0, 1100.0), "lane": randi() % 2})
	for r in _racers:
		r["x"] = float(r["x"]) + float(r["speed"]) * delta
	_racers = _racers.filter(func(r: Dictionary) -> bool: return float(r["x"]) < size.x + 400.0)
	queue_redraw()


func _draw() -> void:
	var s := size
	var horizon := s.y * 0.62
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(s.x, 0), Vector2(s.x, horizon), Vector2(0, horizon)]),
		PackedColorArray([Color(0.22, 0.12, 0.42), Color(0.22, 0.12, 0.42), Color(1.0, 0.55, 0.35), Color(1.0, 0.55, 0.35)]))
	var sun := Vector2(s.x * 0.5, horizon)
	for i in 16:
		var a0 := TAU * i / 16.0 + _t * 0.1
		var a1 := a0 + TAU / 32.0
		draw_colored_polygon(PackedVector2Array([sun, sun + Vector2(cos(a0), sin(a0)) * s.x, sun + Vector2(cos(a1), sin(a1)) * s.x]), Color(1, 0.85, 0.4, 0.08))
	draw_circle(sun, 150, Color(1, 0.8, 0.35))
	draw_circle(sun, 120, Color(1, 0.9, 0.5))
	for m in 9:
		var mx := fposmod(m * 230.0 - _t * 12.0, s.x + 460.0) - 230.0
		var h := 70.0 + (m * 37 % 5) * 22.0
		draw_colored_polygon(PackedVector2Array([Vector2(mx - 180, horizon), Vector2(mx, horizon - h), Vector2(mx + 180, horizon)]), Color(0.35, 0.18, 0.4))
	draw_rect(Rect2(0, horizon, s.x, s.y - horizon), Color(0.93, 0.86, 0.76))
	var road_y := s.y * 0.88
	draw_rect(Rect2(0, road_y - 58, s.x, 96), Color(0.3, 0.28, 0.35))
	var dx := fposmod(-_t * 500.0, 140.0) - 140.0
	while dx < s.x:
		draw_rect(Rect2(dx, road_y - 12, 70, 7), Color(1, 0.95, 0.8, 0.9))
		dx += 140.0
	for r in _racers:
		var data: CharacterData = r["data"]
		var x: float = r["x"]
		var y := road_y + (14.0 if int(r["lane"]) == 1 else -22.0)
		for j in 3:
			draw_line(Vector2(x - 120 - j * 20, y - 30 - j * 18), Vector2(x - 300 - j * 40, y - 30 - j * 18), Color(1, 1, 1, 0.5), 3.0)
		CarArt.draw_side_for(self, data, Vector2(x, y), 0.5, x / 14.0)


# ---------------------------------------------------------------- ações

func _on_play() -> void:
	GameManager.request_mobile_web_fullscreen()
	GameManager.select_mode = "play"
	GameManager.go_to("select")


func _on_characters() -> void:
	GameManager.select_mode = "gallery"
	GameManager.go_to("select")


func _on_options() -> void:
	if _options != null:
		return
	_options = OptionsPanel.new()
	_options.closed.connect(_on_options_closed)
	_options.replay_intro.connect(func() -> void: GameManager.go_to("intro"))
	add_child(_options)


func _on_options_closed() -> void:
	_options = null
	_refresh_records()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _options != null:
			_options.close()
		else:
			get_tree().quit()
