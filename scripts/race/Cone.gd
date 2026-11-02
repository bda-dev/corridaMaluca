class_name Cone
extends Area2D
## Cone de trânsito: voa longe quando atropelado (e volta depois). Freia um pouquinho.
## TROCAR POR ASSET: AssetLib "obj_cone" (Racing Pack).

const RESPAWN_TIME := 7.0

var _home := Vector2.ZERO
var _home_rot := 0.0
var _hit := false
var _tex: Texture2D


func _ready() -> void:
	collision_layer = 4
	collision_mask = 2
	monitorable = false
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 18.0
	cs.shape = shape
	add_child(cs)
	_home = position
	_home_rot = rotation
	_tex = AssetLib.texture("obj_cone")
	body_entered.connect(_on_body_entered)


func _draw() -> void:
	if _tex != null:
		draw_texture(_tex, -_tex.get_size() * 0.5)
		return
	draw_colored_polygon(CarArt.ellipse(Vector2(5, 6), Vector2(20, 20), 12), Color(0, 0, 0, 0.2))
	CarArt.outlined(self, CarArt.rrect(Rect2(-18, -18, 36, 36), 6), Color(1.0, 0.5, 0.1), 3.0)
	draw_circle(Vector2.ZERO, 11.0, Color(1.0, 0.6, 0.2))
	draw_arc(Vector2.ZERO, 8.0, 0, TAU, 14, Color.WHITE, 3.0, true)
	draw_circle(Vector2.ZERO, 4.0, Color(1.0, 0.45, 0.1))


func _on_body_entered(body: Node2D) -> void:
	if _hit or not (body is Car):
		return
	var car := body as Car
	if car.z > 30.0:
		return
	_hit = true
	set_deferred("monitoring", false)
	car.velocity *= 0.9
	var dir := car.velocity.normalized() if car.velocity.length() > 10.0 else Vector2.RIGHT.rotated(car.rotation)
	dir = dir.rotated(randf_range(-0.6, 0.6))
	var target := position + dir * randf_range(180.0, 300.0)
	if car.is_player:
		AudioManager.play_sfx("clank", randf_range(1.1, 1.4))
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "position", target, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "rotation", rotation + randf_range(8.0, 14.0), 0.7)
	tw.tween_property(self, "scale", Vector2(1.8, 1.8), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(self, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(self, "modulate:a", 0.0, 0.6).set_delay(1.5)
	tw.chain().tween_callback(_respawn).set_delay(RESPAWN_TIME)


func _respawn() -> void:
	position = _home
	rotation = _home_rot
	scale = Vector2.ONE
	_hit = false
	monitoring = true
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.5)
