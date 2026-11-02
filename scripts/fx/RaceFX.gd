class_name RaceFX
extends RefCounted
## Efeitos visuais descartáveis da corrida (onomatopeias, explosões, ondas de choque, raios...).
## Tudo é criado por funções estáticas e se autodestrói. Os nós vão para race.fx_root.
## TROCAR POR ASSET: as partículas usam AssetLib.soft_circle()/hard_circle() (Particle Pack).


## Onomatopeia em quadrinho ("BOING!", "KABUM!") que sobe e some — sempre de pé na tela.
class FxText extends Node2D:
	var text := ""
	var color := Color.WHITE
	var font_size := 40
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta
		var cam := get_viewport().get_camera_2d()
		global_rotation = cam.global_rotation if cam != null else 0.0
		position += Vector2(0, -60.0 * delta).rotated(global_rotation)
		var k := clampf(t / 0.15, 0.0, 1.0)
		scale = Vector2.ONE * (0.4 + 0.75 * k - 0.15 * clampf((t - 0.15) / 0.2, 0.0, 1.0))
		modulate.a = clampf((1.1 - t) / 0.3, 0.0, 1.0)
		if t > 1.1:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var pts := PackedVector2Array()
		var w := font_size * 0.32 * text.length() + 30.0
		for i in 16:
			var a := TAU * i / 16.0
			var r := 1.0 if i % 2 == 0 else 0.78
			pts.append(Vector2(cos(a) * w * 0.6 * r, sin(a) * font_size * 0.95 * r))
		draw_colored_polygon(pts, Color(1, 1, 1, 0.92))
		var closed := pts.duplicate()
		closed.append(pts[0])
		draw_polyline(closed, UIStyle.INK, 4.0, true)
		UIStyle.draw_text(self, Vector2.ZERO, text, font_size, color, 8, true)


## Anel de onda de choque.
class FxRing extends Node2D:
	var radius := 300.0
	var color := Color.WHITE
	var duration := 0.5
	var width := 16.0
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta
		if t >= duration:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var k := clampf(t / duration, 0.0, 1.0)
		var r := radius * (1.0 - pow(1.0 - k, 3.0))
		draw_arc(Vector2.ZERO, maxf(r, 1.0), 0, TAU, 48, Color(color, 1.0 - k), maxf(width * (1.0 - k), 1.0), true)


## Raio elétrico em zigue-zague.
class FxBolt extends Node2D:
	var from := Vector2.ZERO
	var to := Vector2.ZERO
	var color := Color.WHITE
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta
		if t > 0.45:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var pts := PackedVector2Array([from])
		var n := (to - from).orthogonal().normalized()
		for i in range(1, 8):
			pts.append(from.lerp(to, i / 8.0) + n * randf_range(-22.0, 22.0))
		pts.append(to)
		var a := 1.0 - t / 0.45
		draw_polyline(pts, Color(color, a * 0.5), 12.0, true)
		draw_polyline(pts, Color(1, 1, 1, a), 4.0, true)


static func _add(race: RaceController, node: Node2D, pos: Vector2) -> void:
	if race == null or race.fx_root == null:
		node.queue_free()
		return
	race.fx_root.add_child(node)
	node.global_position = pos


static func float_text(race: RaceController, pos: Vector2, text: String, color: Color = Color.WHITE, size: int = 40) -> void:
	if race == null or not race.is_near_player(pos, 1400.0):
		return
	var f := FxText.new()
	f.text = text
	f.color = color
	f.font_size = size
	f.z_index = 20
	_add(race, f, pos + Vector2(randf_range(-20, 20), -30))


static func ring(race: RaceController, pos: Vector2, radius: float, color: Color, duration: float = 0.5, width: float = 16.0) -> void:
	var r := FxRing.new()
	r.radius = radius
	r.color = color
	r.duration = duration
	r.width = width
	r.z_index = 10
	_add(race, r, pos)


static func lightning(race: RaceController, from: Vector2, to: Vector2, color: Color) -> void:
	var b := FxBolt.new()
	b.from = Vector2.ZERO
	b.to = to - from
	b.color = color
	b.z_index = 12
	_add(race, b, from)


static func _burst(race: RaceController, pos: Vector2, tex: Texture2D, amount: int, lifetime: float,
		v_min: float, v_max: float, s_min: float, s_max: float, colors: PackedColorArray) -> void:
	var p := CPUParticles2D.new()
	p.texture = tex
	p.amount = amount
	p.lifetime = lifetime
	p.one_shot = true
	p.explosiveness = 1.0
	p.local_coords = false
	p.gravity = Vector2.ZERO
	p.spread = 180.0
	p.initial_velocity_min = v_min
	p.initial_velocity_max = v_max
	p.damping_min = v_max * 0.8
	p.damping_max = v_max * 1.2
	p.scale_amount_min = s_min
	p.scale_amount_max = s_max
	p.angular_velocity_min = -360.0
	p.angular_velocity_max = 360.0
	var g := Gradient.new()
	var offsets := PackedFloat32Array()
	for i in colors.size():
		offsets.append(float(i) / maxf(colors.size() - 1, 1))
	g.offsets = offsets
	g.colors = colors
	p.color_ramp = g
	p.z_index = 8
	_add(race, p, pos)
	if not p.is_inside_tree():
		return
	p.emitting = true
	p.get_tree().create_timer(lifetime + 0.3, false).timeout.connect(p.queue_free)


static func puff(race: RaceController, pos: Vector2, color: Color, amount: int = 12, lifetime: float = 0.6) -> void:
	_burst(race, pos, AssetLib.soft_circle(), amount, lifetime, 40.0, 140.0, 0.4, 0.9,
		PackedColorArray([color, Color(color, 0.0)]))


static func debris(race: RaceController, pos: Vector2, color: Color) -> void:
	_burst(race, pos, AssetLib.hard_circle(), 18, 0.8, 200.0, 420.0, 0.12, 0.3,
		PackedColorArray([color, Color(0.3, 0.3, 0.35), Color(0.3, 0.3, 0.35, 0.0)]))
	puff(race, pos, Color(0.9, 0.9, 0.9, 0.8), 10, 0.7)


static func explosion(race: RaceController, pos: Vector2) -> void:
	_burst(race, pos, AssetLib.soft_circle(), 26, 0.7, 120.0, 380.0, 0.6, 1.4,
		PackedColorArray([Color(1, 0.95, 0.6), Color(1, 0.55, 0.1), Color(0.35, 0.3, 0.3, 0.0)]))
	_burst(race, pos, AssetLib.hard_circle(), 16, 0.6, 300.0, 600.0, 0.1, 0.25,
		PackedColorArray([Color(1, 0.9, 0.4), Color(1, 0.4, 0.1, 0.0)]))
	ring(race, pos, 200.0, Color(1, 0.8, 0.4), 0.35, 20.0)


static func flame_blast(race: RaceController, pos: Vector2, angle: float) -> void:
	var p := CPUParticles2D.new()
	p.texture = AssetLib.soft_circle()
	p.amount = 40
	p.lifetime = 0.6
	p.one_shot = true
	p.explosiveness = 0.9
	p.local_coords = false
	p.gravity = Vector2.ZERO
	p.direction = Vector2.RIGHT.rotated(angle)
	p.spread = 22.0
	p.initial_velocity_min = 500.0
	p.initial_velocity_max = 900.0
	p.damping_min = 600.0
	p.damping_max = 900.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	g.colors = PackedColorArray([Color(1, 0.95, 0.5), Color(1, 0.45, 0.1, 0.9), Color(0.3, 0.3, 0.3, 0.0)])
	p.color_ramp = g
	p.z_index = 8
	_add(race, p, pos)
	if not p.is_inside_tree():
		return
	p.emitting = true
	p.get_tree().create_timer(1.0, false).timeout.connect(p.queue_free)


static func portal(race: RaceController, pos: Vector2) -> void:
	ring(race, pos, 140.0, Color(0.75, 0.4, 1.0), 0.5, 22.0)
	ring(race, pos, 90.0, Color(0.4, 1.0, 0.6), 0.4, 14.0)
	puff(race, pos, Color(0.75, 0.45, 1.0, 0.9), 16, 0.6)
