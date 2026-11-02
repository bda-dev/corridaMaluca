class_name Obstacle
extends StaticBody2D
## Obstáculo sólido: 0 = pilha de pneus, 2 = barril. Bater forte desmonta o carro!
## TROCAR POR ASSET: AssetLib "obj_tires" / "obj_barrel" (Racing Pack).

var kind := 0
var _tex: Texture2D


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 34.0 if kind == 0 else 24.0
	cs.shape = shape
	add_child(cs)
	z_index = -6
	_tex = AssetLib.texture("obj_tires" if kind == 0 else "obj_barrel")


func _draw() -> void:
	if _tex != null:
		draw_texture(_tex, -_tex.get_size() * 0.5)
		return
	if kind == 0:
		draw_colored_polygon(CarArt.ellipse(Vector2(8, 10), Vector2(40, 34), 16), Color(0, 0, 0, 0.2))
		for p in [Vector2(-14, -12), Vector2(14, -12), Vector2(-14, 12), Vector2(14, 12), Vector2(0, 0)]:
			draw_circle(p, 17.0, UIStyle.INK)
			draw_circle(p, 14.0, Color(0.2, 0.2, 0.23))
			draw_circle(p, 6.0, Color(0.85, 0.2, 0.22))
	else:
		draw_colored_polygon(CarArt.ellipse(Vector2(6, 8), Vector2(28, 26), 14), Color(0, 0, 0, 0.2))
		draw_circle(Vector2.ZERO, 26.0, UIStyle.INK)
		draw_circle(Vector2.ZERO, 23.0, Color(0.2, 0.45, 0.8))
		draw_arc(Vector2.ZERO, 16.0, 0, TAU, 18, Color(0.12, 0.3, 0.6), 3.0, true)
		draw_circle(Vector2(-7, -7), 5.0, Color(0.7, 0.85, 1.0))
