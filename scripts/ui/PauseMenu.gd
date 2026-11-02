class_name PauseMenu
extends CanvasLayer
## Menu de PAUSA da corrida (funciona com a árvore pausada).

var race: RaceController
var _panel: Control
var _options: OptionsPanel


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_panel = Control.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_panel)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.03, 0.1, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(center)
	var box := PanelContainer.new()
	center.add_child(box)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	box.add_child(vb)
	vb.add_child(UIStyle.make_label("PAUSA", 56, UIStyle.YELLOW, 12, HORIZONTAL_ALIGNMENT_CENTER, true))
	var cont := UIStyle.make_button("CONTINUAR", Vector2(340, 74), UIStyle.ORANGE)
	cont.pressed.connect(close)
	vb.add_child(cont)
	var opts := UIStyle.make_button("OPÇÕES", Vector2(340, 66), UIStyle.TEAL)
	opts.pressed.connect(_on_options)
	vb.add_child(opts)
	var restart := UIStyle.make_button("REINICIAR", Vector2(340, 66))
	restart.pressed.connect(func() -> void: GameManager.go_to("race"))
	vb.add_child(restart)
	var quit := UIStyle.make_button("SAIR PARA O MENU", Vector2(340, 66), Color(0.75, 0.72, 0.8))
	quit.pressed.connect(func() -> void: GameManager.go_to("menu"))
	vb.add_child(quit)


func open() -> void:
	visible = true
	AudioManager.play_sfx("click")


func close() -> void:
	if _options != null:
		_options.close()
		return
	visible = false
	get_tree().paused = false
	if race != null:
		race.touch.reset()


func _on_options() -> void:
	_options = OptionsPanel.new()
	_options.show_intro_button = false
	_options.closed.connect(func() -> void: _options = null)
	add_child(_options)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()
