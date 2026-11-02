class_name Rocket
extends Node2D
## Foguete teleguiado: persegue o carro à frente de quem disparou (ou segue a pista).
## No impacto: explosão, o alvo se desmonta e é jogado para o ar.

const SPEED := 1250.0
const TURN_RATE := 4.5
const HIT_RADIUS := 52.0

var owner_car: Car
var target: Car
var race: RaceController
var life := 4.5
var dir := Vector2.RIGHT
var _trail: CPUParticles2D
var _t := 0.0


func setup(p_owner: Car, p_target: Car) -> void:
	owner_car = p_owner
	target = p_target
	race = p_owner.race
	dir = Vector2.RIGHT.rotated(p_owner.rotation)
	global_position = p_owner.global_position + dir * 70.0
	rotation = dir.angle()


func _ready() -> void:
	z_index = 6
	_trail = CPUParticles2D.new()
	_trail.texture = AssetLib.soft_circle()
	_trail.amount = 40
	_trail.lifetime = 0.6
	_trail.local_coords = false
	_trail.gravity = Vector2.ZERO
	_trail.position = Vector2(-26, 0)
	_trail.direction = Vector2(-1, 0)
	_trail.spread = 12.0
	_trail.initial_velocity_min = 40.0
	_trail.initial_velocity_max = 80.0
	_trail.scale_amount_min = 0.25
	_trail.scale_amount_max = 0.5
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	g.colors = PackedColorArray([Color(1, 0.9, 0.4, 1), Color(1, 0.5, 0.1, 0.8), Color(0.5, 0.5, 0.55, 0)])
	_trail.color_ramp = g
	add_child(_trail)


func _physics_process(delta: float) -> void:
	_t += delta
	life -= delta
	var desired := dir
	if target != null and is_instance_valid(target) and not target.finished:
		desired = (target.global_position - global_position).normalized()
	else:
		var off := race.track.get_offset(global_position)
		desired = (race.track.sample(off + 320.0) - global_position).normalized()
	var max_turn := TURN_RATE * delta
	dir = dir.rotated(clampf(dir.angle_to(desired), -max_turn, max_turn))
	global_position += dir * SPEED * delta
	rotation = dir.angle()
	queue_redraw()
	for c in race.cars:
		if c != owner_car and c.z < 60.0 and c.global_position.distance_to(global_position) < HIT_RADIUS:
			_explode(c)
			return
	if life <= 0.0:
		_explode(null)


func _explode(hit: Car) -> void:
	RaceFX.explosion(race, global_position)
	if hit != null and hit.crash(520.0):
		owner_car.hits_given += 1
		RaceFX.float_text(race, hit.global_position, "KABUM!", UIStyle.ORANGE, 52)
	for c in race.cars_near(global_position, 150.0, owner_car):
		if c != hit:
			c.spin_out(0.6)
	if race.is_near_player(global_position, 1000.0):
		AudioManager.play_sfx("explosion")
		race.shake(0.45)
	_trail.emitting = false
	_trail.reparent(race.fx_root)
	get_tree().create_timer(1.0).timeout.connect(_trail.queue_free)
	queue_free()


func _draw() -> void:
	var flame := 18.0 + 10.0 * absf(sin(_t * 50.0))
	draw_colored_polygon(PackedVector2Array([Vector2(-22, -7), Vector2(-22 - flame, 0), Vector2(-22, 7)]), Color(1, 0.6, 0.1))
	draw_colored_polygon(PackedVector2Array([Vector2(-16, -8), Vector2(-28, -18), Vector2(-24, -6)]), UIStyle.INK)
	draw_colored_polygon(PackedVector2Array([Vector2(-16, 8), Vector2(-28, 18), Vector2(-24, 6)]), UIStyle.INK)
	CarArt.outlined(self, CarArt.lens(-24, 30, 0, 9, 12, 0.5), Color(0.9, 0.22, 0.27), 3.0)
	draw_circle(Vector2(8, 0), 4.0, Color(0.7, 0.9, 1.0))
