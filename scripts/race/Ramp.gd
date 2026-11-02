class_name Ramp
extends Area2D
## Rampa de salto: lança o carro para o ar (salto alto e cômico).
## Em alta velocidade o carro ainda dá um giro no ar (acrobacia = pontos).

const DEPTH := 80.0
const MIN_SPEED := 180.0
const FLIP_SPEED := 560.0

var half_width := 175.0


func _ready() -> void:
	collision_layer = 4
	collision_mask = 2
	monitorable = false
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(DEPTH, half_width * 2.0)
	cs.shape = shape
	add_child(cs)
	z_index = -7
	body_entered.connect(_on_body_entered)


func _draw() -> void:
	var h := half_width
	var d := DEPTH * 0.5
	draw_rect(Rect2(-d - 6, -h - 6, DEPTH + 12, h * 2.0 + 12), UIStyle.INK)
	draw_rect(Rect2(-d, -h, DEPTH, h * 2.0), Color(0.72, 0.48, 0.26))
	for i in 9:
		var y := -h + i * (h * 2.0 / 9.0)
		draw_line(Vector2(-d, y), Vector2(d, y), Color(0.5, 0.32, 0.16), 3.0)
	draw_rect(Rect2(d - 14, -h, 14, h * 2.0), Color(0.95, 0.8, 0.2))
	var stripes := 8
	for i in stripes:
		var y := -h + i * (h * 2.0 / stripes)
		draw_colored_polygon(PackedVector2Array([Vector2(d - 14, y), Vector2(d, y), Vector2(d, y + h / stripes), Vector2(d - 14, y + h / stripes)]), UIStyle.INK)
	for k in 3:
		var cy := -h * 0.6 + k * h * 0.6
		draw_polyline(PackedVector2Array([Vector2(-d + 12, cy - 18), Vector2(-d + 34, cy), Vector2(-d + 12, cy + 18)]), Color.WHITE, 6.0)


func _on_body_entered(body: Node2D) -> void:
	if not (body is Car):
		return
	var car := body as Car
	if car.z > 0.0:
		return
	var fwd := Vector2.RIGHT.rotated(global_rotation)
	var speed := car.velocity.dot(fwd)
	if speed < MIN_SPEED:
		return
	car.launch(240.0 + speed * 0.55, speed > FLIP_SPEED)
