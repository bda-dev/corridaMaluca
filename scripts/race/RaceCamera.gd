class_name RaceCamera
extends Camera2D
## Câmera da corrida: segue o carro olhando à frente, gira junto (opcional),
## afasta o zoom em alta velocidade e treme em impactos (trauma).

var target: Car
var trauma := 0.0


func _ready() -> void:
	ignore_rotation = false
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	position_smoothing_enabled = false
	zoom = Vector2(0.85, 0.85)


func snap() -> void:
	if target == null:
		return
	global_position = target.global_position
	rotation = _desired_rotation()


func _desired_rotation() -> float:
	if not bool(GameManager.settings["rotate_camera"]):
		return 0.0
	# rodopiando: segue a direção do movimento (evita enjoo), senão a frente do carro
	if target.spin_timer > 0.0 and target.velocity.length() > 60.0:
		return target.velocity.angle() + PI * 0.5
	return target.rotation + PI * 0.5


func add_trauma(amount: float) -> void:
	trauma = minf(trauma + amount, 1.0)


func _physics_process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var spd := target.velocity.length()
	var heading := Vector2.RIGHT.rotated(target.rotation)
	var desired := target.global_position + heading * clampf(spd * 0.3, 0.0, 260.0)
	global_position = global_position.lerp(desired, 1.0 - exp(-7.0 * delta))
	rotation = lerp_angle(rotation, _desired_rotation(), 1.0 - exp(-3.2 * delta))
	var z := lerpf(0.86, 0.6, clampf(spd / 1300.0, 0.0, 1.0))
	if target.z > 0.0:
		z -= 0.06
	zoom = zoom.lerp(Vector2(z, z), 1.0 - exp(-2.0 * delta))
	trauma = maxf(trauma - delta * 1.6, 0.0)
	var s := trauma * trauma
	offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 30.0 * s
