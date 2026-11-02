class_name CarVisual
extends Node2D
## Visual do carro (vista de cima) montado em PEÇAS independentes:
## chassi, 4 rodas, piloto e extras. Em batidas fortes as peças voam e se remontam (cartoon!).
##
## Hierarquia criada em setup():
##   Visual
##    ├─ Shadow          sombra (se afasta quando o carro pula)
##    ├─ Lift            escala com a altura do salto + giro "barrel roll" no ar
##    │   └─ Squash      squash & stretch (pouso, largada)
##    │       ├─ rodas, chassi, piloto (peças)
##    ├─ Fx              escudo, estrelas de tontura, faíscas, chamas de turbo, cone de vapor
##    ├─ Exhaust         fumaça/vapor/chama do escapamento (CPUParticles2D)
##    └─ DriftSmoke      fumaça de derrapagem / poeira fora da pista
##
## TROCAR POR ASSET: se existir "car_top_<id>" (AssetLib) ou CharacterData.car_texture,
## o chassi vira um Sprite2D com essa textura (arte apontando para CIMA).

const CAR_LENGTH := 100.0

var data: CharacterData
var car: Car
var parts: Array[Node2D] = []
var wheels: Array[Node2D] = []

var _shadow: Node2D
var _lift: Node2D
var _squash: Node2D
var _fx: Node2D
var _exhaust: CPUParticles2D
var _drift: CPUParticles2D
var _layout := {}
var _disassembled := false
var _flip_t := -1.0
var _t := 0.0
var _sparks_seed := 0


func setup(p_data: CharacterData, p_car: Car) -> void:
	data = p_data
	car = p_car
	_layout = CarArt.top_layout(data.car_shape)

	_shadow = Node2D.new()
	_shadow.z_index = -1
	_shadow.draw.connect(func() -> void: CarArt.draw_shadow(_shadow, CAR_LENGTH, 56.0, 0.32))
	add_child(_shadow)

	_lift = Node2D.new()
	add_child(_lift)
	_squash = Node2D.new()
	_lift.add_child(_squash)

	var tex := data.car_top_texture()
	if tex == null:
		# rodas procedurais (o sprite do Kenney já tem rodas desenhadas)
		var wsize: Vector2 = _layout["wheel"]
		for wp in _layout["wheels"]:
			var w := _make_part(wp)
			w.draw.connect(func() -> void: CarArt.draw_top_wheel(w, wsize))
			wheels.append(w)

	if tex != null:
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.rotation = PI * 0.5 # arte do Racing Pack aponta para cima; o carro aponta para +X
		var k := CAR_LENGTH / maxf(float(tex.get_height()), 1.0)
		spr.scale = Vector2(k, k)
		_squash.add_child(spr)
		spr.set_meta("home", Vector2.ZERO)
		parts.append(spr)
	else:
		var chassis := _make_part(Vector2.ZERO)
		chassis.draw.connect(func() -> void: CarArt.draw_top_body(chassis, data.car_shape, data.body_color, data.accent_color))

	var driver := _make_part(_layout["driver"])
	driver.draw.connect(func() -> void: CarArt.draw_top_driver(driver, data.hat_style, data.skin_color, data.hair_color, data.accent_color))

	_fx = Node2D.new()
	_fx.z_index = 2
	_fx.draw.connect(_draw_fx)
	add_child(_fx)

	_exhaust = _make_exhaust()
	_exhaust.position = Vector2(-CAR_LENGTH * 0.55, 0)
	add_child(_exhaust)
	_drift = _make_particles(AssetLib.soft_circle(), 24, 0.7)
	_drift.position = Vector2(-CAR_LENGTH * 0.35, 0)
	_drift.direction = Vector2(-1, 0)
	_drift.spread = 50.0
	_drift.initial_velocity_min = 20.0
	_drift.initial_velocity_max = 60.0
	_drift.scale_amount_min = 0.5
	_drift.scale_amount_max = 0.9
	_drift.emitting = false
	add_child(_drift)


func _make_part(pos: Vector2) -> Node2D:
	var n := Node2D.new()
	n.position = pos
	n.set_meta("home", pos)
	_squash.add_child(n)
	parts.append(n)
	return n


func _make_particles(tex: Texture2D, amount: int, lifetime: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = tex
	p.amount = amount
	p.lifetime = lifetime
	p.local_coords = false
	p.gravity = Vector2.ZERO
	p.damping_min = 20.0
	p.damping_max = 40.0
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.35))
	curve.add_point(Vector2(1.0, 1.0))
	p.scale_amount_curve = curve
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.0)])
	p.color_ramp = g
	return p


## Escapamento com a "personalidade" de cada carro.
func _make_exhaust() -> CPUParticles2D:
	var p := _make_particles(AssetLib.soft_circle(), 18, 0.6)
	p.direction = Vector2(-1, 0)
	p.spread = 14.0
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 120.0
	p.scale_amount_min = 0.25
	p.scale_amount_max = 0.45
	match data.car_shape:
		"jamais_contente":
			# vapor do Zé: nuvens brancas grandes
			p.amount = 22
			p.lifetime = 0.9
			p.scale_amount_min = 0.5
			p.scale_amount_max = 0.9
		"spirit_of_america", "thrust_ssc":
			# jato: chama laranja que vira fumaça
			var g := Gradient.new()
			g.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
			g.colors = PackedColorArray([Color(1, 0.9, 0.4, 0.95), Color(1, 0.45, 0.1, 0.7), Color(0.4, 0.4, 0.45, 0.0)])
			p.color_ramp = g
			p.initial_velocity_min = 160.0
			p.initial_velocity_max = 260.0
		"jeantaud":
			# elétrico: faísquinhas azuis
			var g := Gradient.new()
			g.offsets = PackedFloat32Array([0.0, 1.0])
			g.colors = PackedColorArray([Color(0.6, 0.9, 1.0, 0.9), Color(0.6, 0.9, 1.0, 0.0)])
			p.color_ramp = g
			p.texture = AssetLib.hard_circle()
			p.scale_amount_min = 0.08
			p.scale_amount_max = 0.16
			p.spread = 60.0
	return p


# ---------------------------------------------------------------- atualização por frame

func update_visual(delta: float) -> void:
	_t += delta
	var speed := car.velocity.length()
	var ratio := clampf(speed / maxf(data.max_speed, 1.0), 0.0, 1.5)
	var h := car.z

	# altura: carro cresce (mais perto da câmera) e a sombra se afasta
	var lift_scale := 1.0 + h / 260.0
	_lift.scale = Vector2(lift_scale, lift_scale)
	if h > 0.0 and _flip_t >= 0.0:
		_flip_t += delta
		_lift.scale.y *= cos(clampf(_flip_t / 0.75, 0.0, 1.0) * TAU)
	var light := Vector2(10, 14) + Vector2(0.45, 0.65) * h
	_shadow.position = light.rotated(-global_rotation)
	_shadow.scale = Vector2.ONE * clampf(1.0 - h / 500.0, 0.5, 1.0)
	_shadow.modulate.a = clampf(1.0 - h / 600.0, 0.4, 1.0)

	# motor tremendo
	_squash.position = Vector2(0, sin(_t * 47.0) * 0.8 * clampf(ratio + 0.2, 0.0, 1.0))
	if not _disassembled and wheels.size() >= 2:
		wheels[0].rotation = car.steer * 0.45
		wheels[1].rotation = car.steer * 0.45

	# piscando quando invulnerável após batida
	modulate.a = 0.45 + 0.55 * absf(sin(_t * 18.0)) if car.invuln_timer > 0.0 else 1.0

	_exhaust.emitting = car.active and h <= 0.0 and (car.throttle > 0.05 or car.boost_timer > 0.0)
	_exhaust.speed_scale = 1.6 if car.boost_timer > 0.0 else 1.0
	var dusty := car.offroad and speed > 140.0
	_drift.emitting = h <= 0.0 and (car.drifting or car.spin_timer > 0.0 or dusty)
	_drift.color = Color(0.9, 0.8, 0.6) if dusty else Color(0.92, 0.92, 0.95)
	_fx.queue_redraw()


func start_air(flip: bool) -> void:
	_flip_t = 0.0 if flip else -1.0


func land() -> void:
	_flip_t = -1.0
	squash(Vector2(1.3, 0.75))


## Squash & stretch rápido (pouso, largada turbo, trombada).
func squash(amount: Vector2) -> void:
	_squash.scale = amount
	var tw := create_tween()
	tw.tween_property(_squash, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## As peças voam para longe... e se remontam sozinhas!
func disassemble() -> void:
	if _disassembled:
		return
	_disassembled = true
	for p in parts:
		var home: Vector2 = p.get_meta("home")
		var dir := home.normalized() if home.length() > 1.0 else Vector2.RIGHT.rotated(randf() * TAU)
		dir = dir.rotated(randf_range(-0.5, 0.5))
		var out := home + dir * randf_range(55.0, 115.0)
		var tw := create_tween()
		tw.tween_property(p, "position", out, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(p, "rotation", randf_range(-7.0, 7.0), 0.22)
		tw.tween_interval(0.4)
		tw.tween_property(p, "position", home, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(p, "rotation", 0.0, 0.45)
	var t := get_tree().create_timer(1.15, false)
	t.timeout.connect(_on_reassembled)


func _on_reassembled() -> void:
	_disassembled = false
	squash(Vector2(1.25, 0.8))


# ---------------------------------------------------------------- efeitos sobrepostos

func _draw_fx() -> void:
	if car == null:
		return
	var head: Vector2 = _layout.get("driver", Vector2.ZERO)
	# cone de vapor da barreira do som (Prandtl–Glauert)
	if car.boost_timer > 0.0 and car.boost_floor > 1000.0:
		var a := 0.25 + 0.1 * sin(_t * 30.0)
		_fx.draw_colored_polygon(PackedVector2Array([Vector2(70, 0), Vector2(-30, -62), Vector2(-75, -52), Vector2(-75, 52), Vector2(-30, 62)]), Color(1, 1, 1, a))
		_fx.draw_arc(Vector2(40, 0), 60.0, PI * 0.6, PI * 1.4, 16, Color(1, 1, 1, a + 0.2), 5.0, true)
	# chamas de turbo
	if car.boost_timer > 0.0 and car.z <= 60.0:
		var flame := 40.0 + 25.0 * absf(sin(_t * 40.0))
		_fx.draw_colored_polygon(PackedVector2Array([Vector2(-48, -12), Vector2(-48 - flame, 0), Vector2(-48, 12)]), Color(1, 0.55, 0.1, 0.9))
		_fx.draw_colored_polygon(PackedVector2Array([Vector2(-48, -6), Vector2(-48 - flame * 0.6, 0), Vector2(-48, 6)]), Color(1, 0.95, 0.5, 0.95))
	# escudo da Lady Nitro
	if car.shield_timer > 0.0:
		var r := 64.0 + sin(_t * 8.0) * 3.0
		_fx.draw_circle(Vector2.ZERO, r, Color(1, 0.5, 0.8, 0.18))
		_fx.draw_arc(Vector2.ZERO, r, 0, TAU, 32, Color(1, 0.7, 0.9, 0.8), 4.0, true)
	# choque elétrico
	if car.shock_timer > 0.0:
		_sparks_seed += 1
		var rng := RandomNumberGenerator.new()
		rng.seed = _sparks_seed
		for k in 4:
			var pts := PackedVector2Array()
			var a0 := rng.randf() * TAU
			for j in 5:
				pts.append(Vector2(cos(a0 + j * 0.35), sin(a0 + j * 0.35)) * rng.randf_range(30, 62))
			_fx.draw_polyline(pts, Color(0.6, 0.9, 1.0), 3.0, true)
	# estrelinhas de tontura
	if car.spin_timer > 0.0 or car.bonk_timer > 0.0 or car.stun_timer > 0.0:
		for k in 3:
			var a := _t * 7.0 + TAU * k / 3.0
			var p := head + Vector2(cos(a) * 26.0, sin(a) * 16.0)
			_draw_star(p, 8.0, Color(1, 0.92, 0.3))
	# ímã: linhas de campo até o rival da frente
	if car.magnet_timer > 0.0 and car.magnet_target != Vector2.INF:
		var to := to_local(car.magnet_target)
		var n := to.normalized().orthogonal()
		for k in 3:
			var pts := PackedVector2Array()
			for j in 9:
				var f := j / 8.0
				pts.append(to * f + n * sin(f * PI) * (18.0 + k * 14.0) * sin(_t * 9.0 + k))
			_fx.draw_polyline(pts, Color(0.95, 0.25, 0.3, 0.7), 3.0, true)


func _draw_star(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI * 0.5 + TAU * i / 10.0
		var rr := r if i % 2 == 0 else r * 0.45
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	_fx.draw_colored_polygon(pts, col)
	var closed := pts.duplicate()
	closed.append(pts[0])
	_fx.draw_polyline(closed, UIStyle.INK, 1.5, true)
