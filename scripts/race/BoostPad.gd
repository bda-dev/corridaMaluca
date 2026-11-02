class_name BoostPad
extends Area2D
## Faixa de turbo no asfalto (setas animadas).

const SIZE := Vector2(110, 96)

var _t := 0.0


func _ready() -> void:
	collision_layer = 4
	collision_mask = 2
	monitorable = false
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = SIZE
	cs.shape = shape
	add_child(cs)
	z_index = -7
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var r := Rect2(-SIZE * 0.5, SIZE)
	draw_rect(r.grow(5), UIStyle.INK)
	draw_rect(r, Color(0.15, 0.55, 0.85))
	for k in 3:
		var phase := fmod(_t * 2.5 + k / 3.0, 1.0)
		var x := lerpf(-SIZE.x * 0.4, SIZE.x * 0.3, phase)
		var col := Color(1, 0.9, 0.3, 1.0 - phase * 0.6)
		draw_polyline(PackedVector2Array([Vector2(x, -SIZE.y * 0.35), Vector2(x + 26, 0), Vector2(x, SIZE.y * 0.35)]), col, 9.0)


func _on_body_entered(body: Node2D) -> void:
	if not (body is Car):
		return
	var car := body as Car
	if car.z > 0.0:
		return
	car.apply_boost(1.35, 1.1)
	if car.is_player:
		AudioManager.play_sfx("boost", 1.1)
