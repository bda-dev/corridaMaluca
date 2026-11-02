class_name PlayerController
extends RefCounted
## Junta toque + giroscópio + teclado/controle e alimenta o Car do jogador.

var car: Car
var touch: TouchInput


func _init(p_car: Car, p_touch: TouchInput) -> void:
	car = p_car
	touch = p_touch


func update(_delta: float) -> void:
	# teclado / controle (útil para testar no PC)
	var steer := Input.get_axis("steer_left", "steer_right")
	var thr := Input.get_action_strength("accelerate")
	var brk := Input.get_action_strength("brake")

	# toque: segurar = acelerar, arrastar = virar
	if touch != null:
		if touch.drive_active:
			thr = 1.0
			if absf(touch.steer_value) > absf(steer):
				steer = touch.steer_value
		if touch.brake_held:
			brk = 1.0

	# giroscópio (opcional): inclinar o celular como um volante
	if bool(GameManager.settings["gyro_enabled"]):
		var g := Input.get_gravity()
		if g.length() > 1.0:
			var sens := float(GameManager.settings["gyro_sensitivity"])
			var tilt := -g.x / 9.8 * 2.6 * sens
			if bool(GameManager.settings["gyro_invert"]):
				tilt = -tilt
			if absf(tilt) > 0.06 and absf(tilt) > absf(steer):
				steer = clampf(tilt, -1.0, 1.0)

	car.steer = clampf(steer, -1.0, 1.0)
	car.throttle = thr
	car.brake = brk
	if Input.is_action_just_pressed("use_item"):
		car.use_item()
	if Input.is_action_just_pressed("use_special"):
		car.use_special()
