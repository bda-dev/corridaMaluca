class_name FallingPart
extends Node2D
## Peça que despenca do céu (item "chuva de peças"). Mira à frente do carro-alvo,
## mostra a sombra crescendo e, ao cair, dá um "bonk" em quem estiver embaixo.

const GRAVITY := 1700.0
const HIT_RADIUS := 62.0

var owner_car: Car
var target: Car
var race: RaceController
var delay := 0.0
var height := 900.0
var _vy := 0.0
var _falling := false
var _landed := false
var _kind := 0
var _spin := 0.0


func setup(p_owner: Car, p_target: Car, p_delay: float) -> void:
	owner_car = p_owner
	target = p_target
	race = p_owner.race
	delay = p_delay
	_kind = randi() % 4
	visible = false


func _physics_process(delta: float) -> void:
	if _landed:
		return
	if not _falling:
		delay -= delta
		if is_instance_valid(target):
			global_position = target.global_position + target.velocity * 0.75 + Vector2(randf_range(-40, 40), randf_range(-40, 40))
		if delay <= 0.0:
			_falling = true
			visible = true
		return
	_vy += GRAVITY * delta
	height -= _vy * delta
	_spin += delta * 9.0
	queue_redraw()
	if height <= 0.0:
		height = 0.0
		_land()


func _land() -> void:
	_landed = true
	queue_redraw()
	for c in race.cars_near(global_position, HIT_RADIUS, owner_car):
		if c.z < 40.0 and c.bonk():
			owner_car.hits_given += 1
			RaceFX.float_text(race, c.global_position, "BONK!", UIStyle.CREAM, 36)
	var tw := create_tween()
	tw.tween_interval(0.8)
	tw.tween_property(self, "modulate:a", 0.0, 0.5)
	tw.tween_callback(queue_free)


func _draw() -> void:
	var s := 1.0 + height / 600.0
	var shadow_r := 22.0 * clampf(1.0 - height / 1200.0, 0.3, 1.0)
	draw_colored_polygon(CarArt.ellipse(Vector2.ZERO, Vector2(shadow_r, shadow_r * 0.7), 14), Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2(0, -height * 0.15), _spin, Vector2(s, s))
	match _kind:
		0: # engrenagem
			for i in 8:
				var a := TAU * i / 8.0
				draw_line(Vector2(cos(a), sin(a)) * 8.0, Vector2(cos(a), sin(a)) * 19.0, Color(0.6, 0.62, 0.68), 7.0)
			draw_circle(Vector2.ZERO, 14.0, Color(0.72, 0.74, 0.8))
			draw_circle(Vector2.ZERO, 5.0, UIStyle.INK)
		1: # roda
			draw_circle(Vector2.ZERO, 17.0, UIStyle.INK)
			draw_circle(Vector2.ZERO, 9.0, Color(0.8, 0.8, 0.85))
		2: # parafuso
			draw_rect(Rect2(-4, -16, 8, 26), Color(0.75, 0.75, 0.8))
			draw_rect(Rect2(-9, -20, 18, 7), Color(0.6, 0.6, 0.66))
		_: # chave inglesa
			draw_line(Vector2(-16, 0), Vector2(14, 0), Color(0.7, 0.72, 0.78), 7.0)
			draw_arc(Vector2(16, 0), 8.0, PI * 0.6, PI * 2.4, 10, Color(0.7, 0.72, 0.78), 6.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
