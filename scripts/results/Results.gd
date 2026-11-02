extends Control
## TELA DE RESULTADO: pódio, classificação, pontuação detalhada (com contagem animada)
## e carimbos de NOVO RECORDE. Lê GameManager.last_results (preenchido pela corrida).

const LINE_DELAY := 0.32

var _results := {}
var _t := 0.0
var _confetti: Array = []
var _score_lines: Array[HBoxContainer] = []
var _total_label: Label
var _total_value := 0
var _shown_total := 0.0
var _counting := false
var _player_pos := 5
var _record_box: VBoxContainer


func _ready() -> void:
	_results = GameManager.last_results
	if _results.is_empty():
		_results = _demo_results()
	var stats: Dictionary = _results["player"]
	_player_pos = int(stats["position"])
	AudioManager.play_music("menu")
	AudioManager.play_sfx("finish" if _player_pos == 1 else "lap")
	if _player_pos == 1:
		_spawn_confetti()
	_build_ui()
	_animate_score()


func _build_ui() -> void:
	var title := UIStyle.make_label("VITÓRIA!" if _player_pos == 1 else "RESULTADO", 54, UIStyle.YELLOW, 12, HORIZONTAL_ALIGNMENT_CENTER, true)
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 6
	title.offset_bottom = 70
	add_child(title)
	var sub := UIStyle.make_label("%s  ·  %d voltas" % [_results.get("track_name", ""), int(_results.get("laps", 3))], 20, UIStyle.CREAM, 5)
	sub.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	sub.offset_top = 64
	sub.offset_bottom = 92
	add_child(sub)

	# --- classificação (lado esquerdo, abaixo do pódio desenhado)
	var table := VBoxContainer.new()
	table.anchor_right = 0.5
	table.offset_left = 40
	table.offset_right = -10
	table.offset_top = 395
	table.add_theme_constant_override("separation", 0)
	add_child(table)
	var standings: Array = _results["standings"]
	for i in standings.size():
		var s: Dictionary = standings[i]
		var row := HBoxContainer.new()
		var is_player := bool(s["is_player"])
		var col := UIStyle.YELLOW if is_player else UIStyle.CREAM
		var pos_l := UIStyle.make_label("%dº" % (i + 1), 22, col, 5, HORIZONTAL_ALIGNMENT_LEFT, true)
		pos_l.custom_minimum_size = Vector2(52, 30)
		row.add_child(pos_l)
		var name_l := UIStyle.make_label("%s%s" % [s["name"], "  (você)" if is_player else ""], 20, col, 5, HORIZONTAL_ALIGNMENT_LEFT)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_l)
		var t_txt := GameManager.format_time(float(s["time"]))
		if not bool(s["finished"]):
			t_txt = "≈ " + t_txt
		var time_l := UIStyle.make_label(t_txt, 20, col, 5, HORIZONTAL_ALIGNMENT_RIGHT)
		time_l.custom_minimum_size = Vector2(130, 30)
		row.add_child(time_l)
		table.add_child(row)

	# --- painel de pontuação (lado direito)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 1.0
	panel.offset_left = 10
	panel.offset_right = -30
	panel.offset_top = 100
	panel.offset_bottom = -118
	panel.anchor_bottom = 1.0
	add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	panel.add_child(vb)
	var stats: Dictionary = _results["player"]
	vb.add_child(UIStyle.make_label("SUA CORRIDA", 30, UIStyle.ORANGE, 8, HORIZONTAL_ALIGNMENT_LEFT, true))
	var info := "Tempo %s  ·  Melhor volta %s  ·  Vel. máx %d km/h" % [
		GameManager.format_time(float(stats["time"])), GameManager.format_time(float(stats["best_lap"])), int(stats["top_speed"])]
	var info_l := UIStyle.make_label(info, 18, UIStyle.TEAL, 5, HORIZONTAL_ALIGNMENT_LEFT)
	info_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(info_l)
	var score: Dictionary = _results.get("score", {"lines": [], "total": 0})
	for line in score["lines"]:
		var row := HBoxContainer.new()
		var l := UIStyle.make_label(str(line[0]), 21, UIStyle.CREAM, 5, HORIZONTAL_ALIGNMENT_LEFT)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		row.add_child(UIStyle.make_label("+%d" % int(line[1]), 21, UIStyle.YELLOW, 5, HORIZONTAL_ALIGNMENT_RIGHT))
		row.modulate.a = 0.0
		vb.add_child(row)
		_score_lines.append(row)
	var total_row := HBoxContainer.new()
	total_row.add_child(UIStyle.make_label("TOTAL", 30, UIStyle.ORANGE, 8, HORIZONTAL_ALIGNMENT_LEFT, true))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	total_row.add_child(spacer)
	_total_label = UIStyle.make_label("0", 36, UIStyle.YELLOW, 10, HORIZONTAL_ALIGNMENT_RIGHT, true)
	total_row.add_child(_total_label)
	vb.add_child(total_row)
	_total_value = int(score["total"])
	_record_box = VBoxContainer.new()
	vb.add_child(_record_box)

	# --- botões
	var buttons := HBoxContainer.new()
	buttons.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	buttons.offset_top = -104
	buttons.offset_bottom = -22
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 18)
	add_child(buttons)
	var again := UIStyle.make_button("CORRER DE NOVO", Vector2(300, 76), UIStyle.ORANGE)
	again.pressed.connect(func() -> void: GameManager.go_to("race"))
	buttons.add_child(again)
	var change := UIStyle.make_button("TROCAR PILOTO", Vector2(270, 76))
	change.pressed.connect(_on_change_driver)
	buttons.add_child(change)
	var menu := UIStyle.make_button("MENU", Vector2(170, 76), Color(0.75, 0.72, 0.8))
	menu.pressed.connect(func() -> void: GameManager.go_to("menu"))
	buttons.add_child(menu)


func _on_change_driver() -> void:
	GameManager.select_mode = "play"
	GameManager.go_to("select")


func _animate_score() -> void:
	var tw := create_tween()
	tw.tween_interval(0.6)
	for row in _score_lines:
		tw.tween_callback(_reveal_line.bind(row))
		tw.tween_interval(LINE_DELAY)
	tw.tween_callback(func() -> void: _counting = true)
	tw.tween_interval(1.1)
	tw.tween_callback(_show_records)


func _reveal_line(row: HBoxContainer) -> void:
	row.modulate.a = 1.0
	row.pivot_offset = row.size * 0.5
	row.scale = Vector2(1.15, 1.15)
	var tw := create_tween()
	tw.tween_property(row, "scale", Vector2.ONE, 0.2)
	AudioManager.play_sfx("click", 1.2)


func _show_records() -> void:
	_counting = false
	_shown_total = _total_value
	_total_label.text = str(_total_value)
	var names := {"best_time": "MELHOR TEMPO", "best_lap": "MELHOR VOLTA", "top_speed": "VELOCIDADE MÁXIMA", "best_score": "PONTUAÇÃO"}
	var recs: Array = _results.get("new_records", [])
	if recs.is_empty():
		return
	AudioManager.play_sfx("record")
	var parts := []
	for r in recs:
		parts.append(names.get(r, str(r)))
	var stamp := UIStyle.make_label("NOVO RECORDE: " + ", ".join(PackedStringArray(parts)) + "!", 22, UIStyle.RED, 7, HORIZONTAL_ALIGNMENT_LEFT, true)
	stamp.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_record_box.add_child(stamp)
	stamp.pivot_offset = Vector2(120, 16)
	stamp.scale = Vector2(2.2, 2.2)
	stamp.rotation = -0.05
	var tw := create_tween()
	tw.tween_property(stamp, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_t += delta
	if _counting:
		_shown_total = move_toward(_shown_total, _total_value, maxf(_total_value, 1) * delta)
		_total_label.text = str(int(_shown_total))
	for c in _confetti:
		c["p"] = c["p"] + c["v"] * delta
		c["a"] = float(c["a"]) + float(c["w"]) * delta
		if c["p"].y > size.y + 20.0:
			c["p"] = Vector2(randf() * size.x, -20.0)
	queue_redraw()


func _spawn_confetti() -> void:
	for i in 70:
		_confetti.append({
			"p": Vector2(randf() * 1280.0, randf() * -720.0),
			"v": Vector2(randf_range(-40, 40), randf_range(120, 260)),
			"a": randf() * TAU,
			"w": randf_range(-6, 6),
			"c": Color.from_hsv(randf(), 0.75, 1.0),
		})


func _draw() -> void:
	var s := size
	draw_rect(Rect2(Vector2.ZERO, s), UIStyle.BG)
	var c := Vector2(s.x * 0.25, 300)
	for i in 14:
		var a0 := TAU * i / 14.0 + _t * 0.2
		var a1 := a0 + TAU / 28.0
		draw_colored_polygon(PackedVector2Array([c, c + Vector2(cos(a0), sin(a0)) * 900.0, c + Vector2(cos(a1), sin(a1)) * 900.0]), Color(1, 0.8, 0.3, 0.07))
	_draw_podium(s)
	for cf in _confetti:
		draw_set_transform(cf["p"], cf["a"], Vector2.ONE)
		draw_rect(Rect2(-6, -3, 12, 6), cf["c"])
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_podium(s: Vector2) -> void:
	var standings: Array = _results["standings"]
	var cx := s.x * 0.25
	var base := 385.0
	var spots := [[1, Vector2(cx - 165, base), 90.0], [0, Vector2(cx, base), 130.0], [2, Vector2(cx + 165, base), 65.0]]
	for sp in spots:
		var idx: int = sp[0]
		if idx >= standings.size():
			continue
		var p: Vector2 = sp[1]
		var h: float = sp[2]
		var w := 150.0
		var colors := [UIStyle.YELLOW, Color(0.8, 0.82, 0.88), Color(0.85, 0.55, 0.3)]
		CarArt.outlined(self, CarArt.rrect(Rect2(p.x - w * 0.5, p.y - h, w, h), 8), colors[idx], 5.0)
		UIStyle.draw_text(self, p + Vector2(0, -h * 0.5), "%dº" % (idx + 1), 40, UIStyle.INK, 0, true)
		var st: Dictionary = standings[idx]
		var data := GameManager.get_character(str(st["id"]))
		var bob := absf(sin(_t * 4.0 + idx)) * (8.0 if idx == 0 else 3.0)
		CarArt.draw_portrait(self, data, p + Vector2(0, -h - 52 - bob), 46)
		UIStyle.draw_text(self, p + Vector2(0, -h - 112 - bob), str(st["name"]), 18, UIStyle.YELLOW if bool(st["is_player"]) else UIStyle.CREAM, 5)


func _demo_results() -> Dictionary:
	# Dados de exemplo para abrir a cena direto no editor (F6).
	var standings := []
	var t := 95.0
	for c in GameManager.roster:
		standings.append({"id": c.id, "name": c.display_name, "car": c.car_name, "time": t, "best_lap": t / 3.2,
			"is_player": c.id == GameManager.selected_id, "finished": true})
		t += 2.5
	var player_stats := {"id": GameManager.selected_id, "position": 1, "time": 95.0, "best_lap": 30.1, "top_speed": 1288.0,
		"air_time": 4.2, "hits": 3, "flips": 2, "crashes": 4, "mach": true}
	return {"track_name": "Salar do Vento Maluco", "laps": 3, "standings": standings, "player": player_stats,
		"score": GameManager.compute_score(player_stats), "new_records": ["top_speed", "best_score"]}


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		GameManager.go_to("menu")
