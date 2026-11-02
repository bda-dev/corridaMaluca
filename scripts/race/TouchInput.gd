class_name TouchInput
extends Node
## CONTROLES DE TOQUE (multi-touch):
##   * Segurar a tela (fora dos botões) = acelerar
##   * Arrastar esquerda/direita (a partir de onde o dedo encostou) = virar
##   * Toque duplo = especial do piloto
##   * Botões da HUD: FREIO (segurar), ITEM, ESPECIAL, PAUSA
## No PC o mouse emula toque (project.godot: emulate_touch_from_mouse) e o teclado também
## funciona (ver PlayerController / GameManager._register_input_actions).

signal item_pressed
signal special_pressed
signal pause_pressed

const DOUBLE_TAP_TIME := 0.32
const DOUBLE_TAP_DIST := 90.0
const STEER_RANGE := 110.0
const DEADZONE := 0.08

var hud: RaceHUD
var drive_active := false
var steer_value := 0.0
var brake_held := false
var anchor := Vector2.ZERO
var current := Vector2.ZERO

var _drive_index := -1
var _button_touches := {}
var _last_tap_time := -10.0
var _last_tap_pos := Vector2.ZERO


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_on_press(st.index, st.position)
		else:
			_on_release(st.index)
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if sd.index == _drive_index:
			_on_drag(sd.position)


func _on_press(index: int, pos: Vector2) -> void:
	var b := hud.get_button_at(pos) if hud != null else ""
	if b != "":
		_button_touches[index] = b
		_button_down(b)
		return
	if _drive_index != -1:
		return
	_drive_index = index
	drive_active = true
	anchor = pos
	current = pos
	steer_value = 0.0
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_tap_time < DOUBLE_TAP_TIME and pos.distance_to(_last_tap_pos) < DOUBLE_TAP_DIST:
		_last_tap_time = -10.0
		special_pressed.emit()
	else:
		_last_tap_time = now
		_last_tap_pos = pos


func _on_release(index: int) -> void:
	if _button_touches.has(index):
		_button_up(_button_touches[index])
		_button_touches.erase(index)
	elif index == _drive_index:
		_drive_index = -1
		drive_active = false
		steer_value = 0.0


func _on_drag(pos: Vector2) -> void:
	current = pos
	var dx := current.x - anchor.x
	# âncora "flutuante": se o dedo passar do limite, a âncora acompanha
	if absf(dx) > STEER_RANGE:
		anchor.x = current.x - signf(dx) * STEER_RANGE
		dx = signf(dx) * STEER_RANGE
	var v := dx / STEER_RANGE
	steer_value = 0.0 if absf(v) < DEADZONE else v


func _button_down(b: String) -> void:
	if hud != null:
		hud.set_button_pressed(b, true)
	match b:
		"brake":
			brake_held = true
		"item":
			item_pressed.emit()
		"special":
			special_pressed.emit()
		"pause":
			pause_pressed.emit()


func _button_up(b: String) -> void:
	if hud != null:
		hud.set_button_pressed(b, false)
	if b == "brake":
		brake_held = false


## Limpa toques presos (ex.: ao voltar da pausa ou perder o foco do app).
func reset() -> void:
	for idx in _button_touches:
		_button_up(_button_touches[idx])
	_button_touches.clear()
	_drive_index = -1
	drive_active = false
	steer_value = 0.0
	brake_held = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		reset()
