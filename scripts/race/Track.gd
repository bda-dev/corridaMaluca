class_name Track
extends Node2D
## PISTA gerada a partir de UMA curva fechada (o Path2D filho "Path").
## Edite a curva no editor do Godot e tudo se reconstrói: asfalto, zebras, acostamento,
## barreira de pneus (com colisão), linha de chegada, decoração e objetos.
##
## Objetos são posicionados por FRAÇÃO DA VOLTA (0..1) + deslocamento lateral em px
## (positivo = lado direito no sentido da corrida). Assim continuam na pista se a curva mudar.
##
## TROCAR POR ASSETS: cones/pneus/barris usam AssetLib (obj_cone, obj_tires, obj_barrel).

@export var track_id := "salar_do_vento"
@export var track_name := "Salar do Vento Maluco"
@export var road_half_width := 175.0
@export var wall_distance := 330.0

@export_group("Objetos (fração da volta)")
@export var item_rows := PackedFloat32Array([0.06, 0.34, 0.555, 0.8])
@export var ramps := PackedFloat32Array([0.11, 0.865])
## x = fração da volta, y = deslocamento lateral
@export var boost_pads := PackedVector2Array([Vector2(0.03, 0), Vector2(0.455, 70), Vector2(0.69, -60), Vector2(0.95, 0)])
## x = fração, y = lateral, z = tipo (0 = pilha de pneus, 1 = cone, 2 = barril)
@export var obstacles := PackedVector3Array([
	Vector3(0.16, 130, 1), Vector3(0.168, 95, 1), Vector3(0.21, 150, 0), Vector3(0.29, -140, 2),
	Vector3(0.38, 0, 1), Vector3(0.42, -150, 0), Vector3(0.48, -125, 1), Vector3(0.5, 140, 2),
	Vector3(0.6, 0, 0), Vector3(0.62, 120, 1), Vector3(0.64, -120, 1), Vector3(0.73, 150, 0),
	Vector3(0.76, -60, 2), Vector3(0.91, 140, 1), Vector3(0.915, -140, 1),
])

@export_group("Cores")
@export var ground_color := Color(0.93, 0.89, 0.8)
@export var sand_color := Color(0.86, 0.75, 0.56)
@export var road_color := Color(0.3, 0.29, 0.35)

@onready var path: Path2D = $Path

var curve: Curve2D
var length := 0.0
var baked := PackedVector2Array()
var objects_root: Node2D


func _ready() -> void:
	curve = path.curve
	curve.bake_interval = 16.0
	length = curve.get_baked_length()
	baked = curve.get_baked_points()
	if baked.size() > 2 and baked[0].distance_to(baked[baked.size() - 1]) < 1.0:
		baked.remove_at(baked.size() - 1)
	_build_ground()
	_build_road()
	_build_walls()
	_build_start_line()
	_build_decor()
	objects_root = Node2D.new()
	objects_root.name = "Objects"
	add_child(objects_root)
	_build_objects()


# ================================================================ consultas (usadas por carros/IA)

## Retorna Vector2(offset na curva, distância ao eixo da pista). Uma só busca por frame.
func query(global_pos: Vector2) -> Vector2:
	var lp := path.to_local(global_pos)
	var off := curve.get_closest_offset(lp)
	return Vector2(off, lp.distance_to(curve.sample_baked(off)))


func get_offset(global_pos: Vector2) -> float:
	return curve.get_closest_offset(path.to_local(global_pos))


func is_offroad(global_pos: Vector2) -> bool:
	return query(global_pos).y > road_half_width + 8.0


## Ponto da pista no offset (com deslocamento lateral; + = direita).
func sample(offset: float, lateral: float = 0.0) -> Vector2:
	var o := fposmod(offset, length)
	var p := curve.sample_baked(o)
	return path.to_global(p + direction_at(o).rotated(PI * 0.5) * lateral)


## Direção (unitária) da pista no offset.
func direction_at(offset: float) -> Vector2:
	var a := curve.sample_baked(fposmod(offset - 10.0, length))
	var b := curve.sample_baked(fposmod(offset + 10.0, length))
	var d := b - a
	return d.normalized() if d.length() > 0.001 else Vector2.RIGHT


## Deslocamento lateral com sinal (+ = direita) de um ponto em relação ao eixo.
func lateral_of(global_pos: Vector2) -> float:
	var lp := path.to_local(global_pos)
	var off := curve.get_closest_offset(lp)
	var n := direction_at(off).rotated(PI * 0.5)
	return (lp - curve.sample_baked(off)).dot(n)


## Quanto a pista curva entre dois offsets (radianos, com sinal).
func turn_between(off_a: float, off_b: float) -> float:
	return direction_at(off_a).angle_to(direction_at(off_b))


func bounds() -> Rect2:
	var r := Rect2(baked[0], Vector2.ZERO)
	for p in baked:
		r = r.expand(p)
	return r.grow(wall_distance)


# ================================================================ construção visual

func _build_ground() -> void:
	var rect := bounds().grow(2600.0)
	var spr := Sprite2D.new()
	spr.texture = _ground_texture()
	spr.centered = false
	spr.region_enabled = true
	spr.scale = Vector2(4, 4)
	spr.region_rect = Rect2(Vector2.ZERO, rect.size / 4.0)
	spr.position = rect.position
	spr.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	spr.z_index = -20
	add_child(spr)


## Textura do chão de sal: base clara + rachaduras poligonais (repete sem emenda).
func _ground_texture() -> Texture2D:
	var size := 128
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	img.fill(ground_color)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 900:
		var c := ground_color.darkened(rng.randf_range(0.0, 0.06)) if rng.randf() < 0.6 else ground_color.lightened(rng.randf_range(0.0, 0.08))
		img.set_pixel(rng.randi_range(0, size - 1), rng.randi_range(0, size - 1), c)
	var cell := 32
	var n := size / cell
	var jit := []
	for gy in n:
		var row := []
		for gx in n:
			row.append(Vector2(gx * cell + rng.randi_range(-8, 8), gy * cell + rng.randi_range(-8, 8)))
		jit.append(row)
	var crack := ground_color.darkened(0.12)
	for gy in n:
		for gx in n:
			var p: Vector2 = jit[gy][gx]
			var right: Vector2 = jit[gy][(gx + 1) % n]
			if gx + 1 >= n:
				right.x += size
			var down: Vector2 = jit[(gy + 1) % n][gx]
			if gy + 1 >= n:
				down.y += size
			_img_line(img, p, right, crack)
			_img_line(img, p, down, crack)
	return ImageTexture.create_from_image(img)


func _img_line(img: Image, a: Vector2, b: Vector2, c: Color) -> void:
	var steps := int(a.distance_to(b))
	var w := img.get_width()
	var h := img.get_height()
	for i in steps + 1:
		var p := a.lerp(b, float(i) / maxf(steps, 1))
		img.set_pixel(posmod(int(p.x), w), posmod(int(p.y), h), c)


func _line(pts: PackedVector2Array, width: float, color: Color, z: int, tex: Texture2D = null) -> Line2D:
	var l := Line2D.new()
	l.points = pts
	l.closed = true
	l.width = width
	l.default_color = color
	l.joint_mode = Line2D.LINE_JOINT_ROUND
	l.z_index = z
	if tex != null:
		l.texture = tex
		l.texture_mode = Line2D.LINE_TEXTURE_TILE
		l.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	add_child(l)
	return l


func _build_road() -> void:
	_line(baked, wall_distance * 2.0 + 30.0, sand_color, -16)
	_line(baked, road_half_width * 2.0 + 32.0, Color.WHITE, -13, _stripe_texture(Color(0.88, 0.16, 0.2), Color.WHITE, 32, 8))
	_line(baked, road_half_width * 2.0, road_color, -12, _asphalt_texture())
	var dash := Image.create_empty(32, 2, false, Image.FORMAT_RGBA8)
	dash.fill(Color(0, 0, 0, 0))
	dash.fill_rect(Rect2i(0, 0, 16, 2), Color(1, 0.97, 0.85, 0.85))
	_line(baked, 8.0, Color.WHITE, -11, ImageTexture.create_from_image(dash))


func _stripe_texture(a: Color, b: Color, w: int, h: int) -> Texture2D:
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill_rect(Rect2i(0, 0, w / 2, h), a)
	img.fill_rect(Rect2i(w / 2, 0, w - w / 2, h), b)
	return ImageTexture.create_from_image(img)


func _asphalt_texture() -> Texture2D:
	var img := Image.create_empty(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 500:
		var v := rng.randf_range(0.82, 1.0)
		img.set_pixel(rng.randi_range(0, 63), rng.randi_range(0, 63), Color(v, v, v))
	return ImageTexture.create_from_image(img)


## Barreira de pneus (colisão + visual) nas bordas externas e internas.
func _build_walls() -> void:
	var polys := Geometry2D.offset_polyline(baked, wall_distance, Geometry2D.JOIN_ROUND, Geometry2D.END_JOINED)
	var body := StaticBody2D.new()
	body.name = "Walls"
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	var tire_tex := _tire_texture()
	for poly in polys:
		var segs := PackedVector2Array()
		for i in poly.size():
			segs.append(poly[i])
			segs.append(poly[(i + 1) % poly.size()])
		var shape := ConcavePolygonShape2D.new()
		shape.segments = segs
		var cs := CollisionShape2D.new()
		cs.shape = shape
		body.add_child(cs)
		_line(poly, 26.0, Color.WHITE, -9, tire_tex)


func _tire_texture() -> Texture2D:
	var img := Image.create_empty(32, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for k in 2:
		var cx := 8 + k * 16
		var band := Color(0.9, 0.2, 0.22) if k == 0 else Color(0.95, 0.95, 0.95)
		for y in 16:
			for x in 16:
				var d := Vector2(x + k * 16 + 0.5, y + 0.5).distance_to(Vector2(cx, 8))
				if d < 7.5:
					img.set_pixel(x + k * 16, y, Color(0.12, 0.12, 0.14) if d > 4.5 or d < 2.0 else band)
	return ImageTexture.create_from_image(img)


func _build_start_line() -> void:
	var line := Node2D.new()
	line.name = "StartLine"
	line.position = path.to_global(curve.sample_baked(0.0))
	line.rotation = direction_at(0.0).angle()
	line.z_index = -10
	line.draw.connect(_draw_start_line.bind(line))
	add_child(line)


func _draw_start_line(n: Node2D) -> void:
	var cells := 12
	var cs := road_half_width * 2.0 / cells
	for i in cells:
		for j in 2:
			var c := Color.WHITE if (i + j) % 2 == 0 else Color(0.1, 0.1, 0.12)
			n.draw_rect(Rect2(-cs + j * cs, -road_half_width + i * cs, cs, cs), c)
	# marcações do grid de largada (atrás da linha)
	for row in 3:
		for side in [-1.0, 1.0]:
			if row == 2 and side > 0.0:
				continue
			var lat: float = 0.0 if row == 2 else side * 75.0
			var x := -120.0 - row * 150.0 + 40.0
			n.draw_polyline(PackedVector2Array([Vector2(x - 60, lat - 34), Vector2(x, lat - 34), Vector2(x, lat + 34), Vector2(x - 60, lat + 34)]), Color(1, 1, 1, 0.75), 4.0)
	# pórtico de chegada
	n.draw_rect(Rect2(-50, -road_half_width - 40, 22, road_half_width * 2.0 + 80), Color(0.85, 0.15, 0.2))
	n.draw_rect(Rect2(-50, -road_half_width - 40, 22, road_half_width * 2.0 + 80), UIStyle.INK, false, 4.0)
	n.draw_set_transform(Vector2(-39, 0), PI * 0.5, Vector2.ONE)
	UIStyle.draw_text(n, Vector2.ZERO, "LARGADA  ·  CHEGADA", 18, UIStyle.CREAM, 4, true)
	n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ================================================================ decoração (só visual, desenhada uma vez)

func _build_decor() -> void:
	var decor := Node2D.new()
	decor.name = "Decor"
	decor.z_index = -8
	decor.draw.connect(_draw_decor.bind(decor))
	add_child(decor)


func _far_enough(p: Vector2, margin: float) -> bool:
	return p.distance_to(curve.get_closest_point(path.to_local(p))) > wall_distance + margin


func _draw_decor(n: Node2D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	var r := bounds().grow(900.0)
	# lagoa de sal no miolo da pista
	var lake := Vector2(1300, 1250)
	if _far_enough(lake, 280.0):
		n.draw_colored_polygon(CarArt.ellipse(lake, Vector2(420, 230), 32), Color(0.75, 0.9, 0.98))
		n.draw_colored_polygon(CarArt.ellipse(lake + Vector2(-40, -20), Vector2(330, 160), 32), Color(0.88, 0.96, 1.0))
	# arquibancada ao lado da reta de largada (lado de fora = esquerda)
	for k in 3:
		var off := length - 520.0 + k * 360.0
		var p := sample(off, -(wall_distance + 150.0))
		var ang := direction_at(off).angle()
		n.draw_set_transform(p, ang, Vector2.ONE)
		n.draw_rect(Rect2(-160, -90, 320, 150), Color(0.55, 0.5, 0.62))
		n.draw_rect(Rect2(-160, -90, 320, 150), UIStyle.INK, false, 5.0)
		for row in 5:
			for col in 16:
				var cc := Color.from_hsv(rng.randf(), 0.7, 0.95)
				n.draw_circle(Vector2(-145 + col * 19, -75 + row * 28), 7.0, cc)
		n.draw_rect(Rect2(-170, -110, 340, 22), UIStyle.RED)
		n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# placas de patrocínio malucas
	var boards := [[0.2, "RECORDE!"], [0.4, "THRUST LABS"], [0.52, "CAFÉ DO ZÉ"], [0.66, "CHÁ LADY NITRO"], [0.78, "MACH 1"], [0.97, "ÉCLAIR & CIA"]]
	for b in boards:
		var off: float = float(b[0]) * length
		var p := sample(off, -(wall_distance + 90.0))
		if not _far_enough(p, 40.0):
			p = sample(off, wall_distance + 90.0)
			if not _far_enough(p, 40.0):
				continue
		n.draw_set_transform(p, direction_at(off).angle(), Vector2.ONE)
		n.draw_rect(Rect2(-130, -34, 260, 68), UIStyle.YELLOW)
		n.draw_rect(Rect2(-130, -34, 260, 68), UIStyle.INK, false, 5.0)
		UIStyle.draw_text(n, Vector2.ZERO, b[1], 28, UIStyle.INK, 0, true)
		n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# cactos, pedras e moitas espalhados fora da pista
	for i in 320:
		var p := Vector2(rng.randf_range(r.position.x, r.end.x), rng.randf_range(r.position.y, r.end.y))
		if not _far_enough(p, 70.0):
			continue
		var kind := rng.randi() % 3
		if kind == 0:
			_draw_cactus(n, p, rng.randf_range(0.7, 1.3))
		elif kind == 1:
			n.draw_colored_polygon(CarArt.ellipse(p + Vector2(8, 10), Vector2(42, 26), 14), Color(0, 0, 0, 0.15))
			CarArt.outlined(n, CarArt.ellipse(p, Vector2(40, 28), 14), Color(0.62, 0.58, 0.55), 4.0)
			n.draw_circle(p + Vector2(-10, -8), 8, Color(0.72, 0.68, 0.65))
		else:
			for k in 4:
				n.draw_circle(p + Vector2(rng.randf_range(-20, 20), rng.randf_range(-14, 14)), rng.randf_range(10, 18), Color(0.6, 0.62, 0.3))


func _draw_cactus(n: Node2D, p: Vector2, s: float) -> void:
	n.draw_colored_polygon(CarArt.ellipse(p + Vector2(10, 12) * s, Vector2(30, 18) * s, 12), Color(0, 0, 0, 0.15))
	var green := Color(0.3, 0.62, 0.32)
	CarArt.outlined(n, CarArt.ellipse(p, Vector2(22, 22) * s, 16), green, 4.0)
	CarArt.outlined(n, CarArt.ellipse(p + Vector2(-24, -6) * s, Vector2(11, 11) * s, 12), green, 3.0)
	CarArt.outlined(n, CarArt.ellipse(p + Vector2(22, 8) * s, Vector2(10, 10) * s, 12), green, 3.0)
	n.draw_circle(p + Vector2(-4, -6) * s, 5.0 * s, Color(1, 0.5, 0.7))


# ================================================================ objetos de jogo

func _build_objects() -> void:
	for f in item_rows:
		for lat in [-105.0, -35.0, 35.0, 105.0]:
			var box := ItemBox.new()
			_place(box, f, lat)
	for f in ramps:
		var ramp := Ramp.new()
		ramp.half_width = road_half_width
		_place(ramp, f, 0.0)
	for b in boost_pads:
		_place(BoostPad.new(), b.x, b.y)
	for o in obstacles:
		var kind := int(o.z)
		if kind == 1:
			_place(Cone.new(), o.x, o.y)
		else:
			var ob := Obstacle.new()
			ob.kind = kind
			_place(ob, o.x, o.y)


func _place(node: Node2D, frac: float, lateral: float) -> void:
	var off := frac * length
	node.position = sample(off, lateral)
	node.rotation = direction_at(off).angle()
	objects_root.add_child(node)
