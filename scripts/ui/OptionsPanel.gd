class_name OptionsPanel
extends Control
## Painel de OPÇÕES (sobreposição). Usado no menu principal e na pausa da corrida.
## Toda alteração é salva na hora via GameManager.set_setting().

signal closed
signal replay_intro

var show_intro_button := true
var _reset_armed := false
var _reset_button: Button
var _sens_row: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)

	vb.add_child(UIStyle.make_label("OPÇÕES", 44, UIStyle.YELLOW, 10, HORIZONTAL_ALIGNMENT_CENTER, true))

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(640, 430)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	list.add_child(_slider_row("Música", "music_volume"))
	list.add_child(_slider_row("Efeitos", "sfx_volume"))
	list.add_child(_toggle_row("Botões na tela (freio / item / especial)", "show_buttons"))
	list.add_child(_toggle_row("Câmera gira com o carro", "rotate_camera"))
	list.add_child(_toggle_row("Giroscópio para virar (inclinar o celular)", "gyro_enabled"))
	list.add_child(_toggle_row("Inverter giroscópio", "gyro_invert"))
	_sens_row = _slider_row("Sensib. giroscópio", "gyro_sensitivity", 0.4, 2.0)
	list.add_child(_sens_row)
	list.add_child(_toggle_row("Vibração", "vibration"))
	list.add_child(_toggle_row("Dicas de controle na largada", "show_tutorial"))

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 14)
	vb.add_child(buttons)
	_reset_button = UIStyle.make_button("Apagar recordes", Vector2(230, 64), UIStyle.RED)
	_reset_button.add_theme_font_size_override("font_size", 22)
	_reset_button.pressed.connect(_on_reset)
	buttons.add_child(_reset_button)
	if show_intro_button:
		var intro_b := UIStyle.make_button("Rever intro", Vector2(190, 64), UIStyle.TEAL)
		intro_b.add_theme_font_size_override("font_size", 22)
		intro_b.pressed.connect(func() -> void: replay_intro.emit())
		buttons.add_child(intro_b)
	var back := UIStyle.make_button("Voltar", Vector2(170, 64))
	back.pressed.connect(close)
	buttons.add_child(back)
	_refresh_sens()


func close() -> void:
	closed.emit()
	queue_free()


func _slider_row(text: String, key: String, min_v: float = 0.0, max_v: float = 1.0) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var l := UIStyle.make_label(text, 24, UIStyle.CREAM, 6, HORIZONTAL_ALIGNMENT_LEFT)
	l.custom_minimum_size = Vector2(250, 48)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = 0.05
	s.value = float(GameManager.settings[key])
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.custom_minimum_size = Vector2(300, 36)
	s.value_changed.connect(_on_slider.bind(key))
	row.add_child(s)
	return row


func _toggle_row(text: String, key: String) -> Control:
	var cb := CheckButton.new()
	cb.text = text
	cb.button_pressed = bool(GameManager.settings[key])
	cb.focus_mode = Control.FOCUS_NONE
	cb.custom_minimum_size = Vector2(0, 50)
	cb.toggled.connect(_on_toggle.bind(key))
	return cb


func _on_slider(value: float, key: String) -> void:
	GameManager.set_setting(key, value)
	if key == "sfx_volume":
		AudioManager.play_sfx("click")


func _on_toggle(on: bool, key: String) -> void:
	AudioManager.play_sfx("click")
	GameManager.set_setting(key, on)
	_refresh_sens()


func _refresh_sens() -> void:
	if _sens_row != null:
		_sens_row.modulate.a = 1.0 if bool(GameManager.settings["gyro_enabled"]) else 0.4


func _on_reset() -> void:
	if not _reset_armed:
		_reset_armed = true
		_reset_button.text = "Confirmar?"
		return
	GameManager.reset_records()
	AudioManager.play_sfx("crash")
	_reset_button.text = "Apagados!"
	_reset_button.disabled = true
