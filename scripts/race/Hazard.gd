class_name Hazard
extends Area2D
## Armadilhas deixadas na pista: "oil" (poça de óleo), "banana" e "steam" (nuvem do Zé Vapor).
## TROCAR POR ASSET: AssetLib "obj_oil" (Racing Pack) para a poça de óleo.

var kind := "oil"
var owner_car: Car
var life := 14.0
var radius := 46.0
var _uses := 3
var _grace := 0.7
var _t := 0.0
var _tex: Texture2D


func setup(p_kind: String, p_owner: Car) -> void:
	kind = p_kind
	owner_car = p_owner
	match kind:
		"banana":
			radius = 24.0
			life = 30.0
			_uses = 1
		"steam":
			radius = 170.0
			life = 5.0
			_uses = 999
		_:
			radius = 48.0
			life = 14.0
			_uses = 3
			_tex = AssetLib.texture("obj_oil")


func _ready() -> void:
	collision_layer = 4
	collision_mask = 2
	monitorable = false
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = radius
	cs.shape = shape
	add_child(cs)
	z_index = -5 if kind != "steam" else 4
	body_entered.connect(_on_body_entered)
	scale = Vector2(0.2, 0.2)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _physics_process(delta: float) -> void:
	_t += delta
	_grace -= delta
	life -= delta
	if kind == "steam":
		for b in get_overlapping_bodies():
			if b is Car and b != owner_car:
				(b as Car).apply_slow(0.5, 0.35)
		queue_redraw()
	if life <= 0.0:
		_vanish()


func _on_body_entered(body: Node2D) -> void:
	if kind == "steam" or _uses <= 0 or not (body is Car):
		return
	var car := body as Car
	if car == owner_car and _grace > 0.0:
		return
	if car.spin_out(1.1 if kind == "oil" else 0.85):
		_uses -= 1
		if owner_car != null and car != owner_car:
			owner_car.hits_given += 1
		RaceFX.float_text(car.race, car.global_position, "ESCORREGOU!" if kind == "oil" else "SPLASH!", UIStyle.YELLOW, 34)
		if _uses <= 0:
			_vanish()


func _vanish() -> void:
	_uses = 0
	set_physics_process(false)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.4)
	tw.tween_callback(queue_free)


func _draw() -> void:
	match kind:
		"banana":
			draw_colored_polygon(CarArt.ellipse(Vector2(4, 6), Vector2(20, 12), 12), Color(0, 0, 0, 0.2))
			draw_arc(Vector2(4, -6), 18.0, PI * 0.35, PI * 1.15, 14, UIStyle.INK, 15.0, true)
			draw_arc(Vector2(4, -6), 18.0, PI * 0.38, PI * 1.12, 14, Color(1.0, 0.86, 0.2), 10.0, true)
			draw_circle(Vector2(-14, -2), 3.5, Color(0.4, 0.25, 0.1))
		"steam":
			for k in 9:
				var a := TAU * k / 9.0 + _t * 0.6
				var r := radius * (0.45 + 0.15 * sin(_t * 2.0 + k))
				draw_circle(Vector2(cos(a), sin(a)) * r, radius * 0.45, Color(1, 1, 1, 0.22 * clampf(life, 0.0, 1.0)))
			draw_circle(Vector2.ZERO, radius * 0.6, Color(1, 1, 1, 0.25 * clampf(life, 0.0, 1.0)))
		_:
			if _tex != null:
				draw_texture(_tex, -_tex.get_size() * 0.5)
				return
			draw_colored_polygon(CarArt.ellipse(Vector2.ZERO, Vector2(radius, radius * 0.8), 20), Color(0.12, 0.08, 0.16, 0.92))
			draw_colored_polygon(CarArt.ellipse(Vector2(radius * 0.5, radius * 0.4), Vector2(radius * 0.45, radius * 0.35), 14), Color(0.12, 0.08, 0.16, 0.92))
			draw_colored_polygon(CarArt.ellipse(Vector2(-radius * 0.25, -radius * 0.25), Vector2(radius * 0.35, radius * 0.18), 12), Color(0.55, 0.45, 0.9, 0.5))
			draw_colored_polygon(CarArt.ellipse(Vector2(radius * 0.1, -radius * 0.05), Vector2(radius * 0.15, radius * 0.08), 10), Color(0.4, 0.9, 0.7, 0.4))
