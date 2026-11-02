class_name CarArt
extends RefCounted
## Arte PROCEDURAL (placeholder) dos carros e pilotos — desenhada só com formas convexas.
##
## * Vista de CIMA (corrida): o carro aponta para +X, ~100 px de comprimento.
## * Vista de LADO (intro, menu, seleção): ~300 px, rodas no chão em y = 0.
## * Retrato de frente (seleção, HUD, resultado).
##
## TROCAR POR ASSETS: se existir textura no AssetLib (car_top_<id>, car_side_<id>,
## portrait_<id>) ou no CharacterData, os scripts que chamam estas funções usam a textura.

const OUTLINE := Color(0.08, 0.06, 0.1)
const SIL := Color(0.03, 0.02, 0.04)
const TIRE := Color(0.13, 0.12, 0.15)
const RIM := Color(0.78, 0.78, 0.82)
const GLASS := Color(0.6, 0.88, 1.0)
const COPPER := Color(0.8, 0.47, 0.22)


# ================================================================ geometria básica

static func ellipse(c: Vector2, r: Vector2, n: int = 24) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / n
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	return pts


## Arco preenchido (setor de elipse) entre a0 e a1 — convexo se (a1 - a0) <= PI.
static func half_ellipse(c: Vector2, r: Vector2, a0: float, a1: float, n: int = 14) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n + 1:
		var a := lerpf(a0, a1, float(i) / n)
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	return pts


static func rrect(rect: Rect2, radius: float, n: int = 4) -> PackedVector2Array:
	var r := clampf(radius, 0.5, minf(rect.size.x, rect.size.y) * 0.5 - 0.01)
	var p := rect.position
	var s := rect.size
	var corners := [p + Vector2(s.x - r, r), p + Vector2(s.x - r, s.y - r), p + Vector2(r, s.y - r), p + Vector2(r, r)]
	var starts := [-PI * 0.5, 0.0, PI * 0.5, PI]
	var pts := PackedVector2Array()
	for k in 4:
		var corner: Vector2 = corners[k]
		var a0: float = starts[k]
		for i in n + 1:
			var a := a0 + PI * 0.5 * float(i) / n
			pts.append(corner + Vector2(cos(a), sin(a)) * r)
	return pts


## Forma de "lente/charuto" entre x0 e x1 (pontuda nas duas pontas, sempre convexa).
static func lens(x0: float, x1: float, cy: float, hh: float, n: int = 16, power: float = 0.55) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n + 1:
		var t := float(i) / n
		var u := t * 2.0 - 1.0
		pts.append(Vector2(lerpf(x0, x1, t), cy - hh * pow(maxf(1.0 - u * u, 0.0), power)))
	for i in range(n - 1, 0, -1):
		var t := float(i) / n
		var u := t * 2.0 - 1.0
		pts.append(Vector2(lerpf(x0, x1, t), cy + hh * pow(maxf(1.0 - u * u, 0.0), power)))
	return pts


static func mirror_y(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(pts.size() - 1, -1, -1):
		out.append(Vector2(pts[i].x, -pts[i].y))
	return out


## Desenha uma lista de [pontos, cor]: primeiro todos os contornos, depois os preenchimentos.
## Assim o contorno grosso fica só na silhueta externa (visual cartoon limpo).
static func layered(ci: CanvasItem, shapes: Array, outline_w: float = 5.0, outline: Color = OUTLINE) -> void:
	if outline_w > 0.0:
		for s in shapes:
			var pts: PackedVector2Array = s[0]
			var closed := pts.duplicate()
			closed.append(pts[0])
			ci.draw_polyline(closed, outline, outline_w, true)
	for s in shapes:
		ci.draw_colored_polygon(s[0], s[1])


static func outlined(ci: CanvasItem, pts: PackedVector2Array, fill: Color, w: float = 3.0, outline: Color = OUTLINE) -> void:
	ci.draw_colored_polygon(pts, fill)
	if w > 0.0:
		var closed := pts.duplicate()
		closed.append(pts[0])
		ci.draw_polyline(closed, outline, w, true)


# ================================================================ VISTA DE CIMA

## Posições das 4 rodas, tamanho da roda e posição do piloto para cada formato.
static func top_layout(shape: String) -> Dictionary:
	match shape:
		"jeantaud":
			return {"wheels": [Vector2(30, -25), Vector2(30, 25), Vector2(-30, -25), Vector2(-30, 25)], "wheel": Vector2(26, 9), "driver": Vector2(6, 0)}
		"jamais_contente":
			return {"wheels": [Vector2(30, -22), Vector2(30, 22), Vector2(-30, -22), Vector2(-30, 22)], "wheel": Vector2(20, 9), "driver": Vector2(6, 0)}
		"golden_arrow":
			return {"wheels": [Vector2(34, -21), Vector2(34, 21), Vector2(-34, -21), Vector2(-34, 21)], "wheel": Vector2(20, 8), "driver": Vector2(-14, 0)}
		"blue_bird":
			return {"wheels": [Vector2(34, -22), Vector2(34, 22), Vector2(-34, -22), Vector2(-34, 22)], "wheel": Vector2(22, 9), "driver": Vector2(-12, 0)}
		"spirit_of_america":
			return {"wheels": [Vector2(36, -12), Vector2(36, 12), Vector2(-32, -27), Vector2(-32, 27)], "wheel": Vector2(18, 7), "driver": Vector2(20, 0)}
		"thrust_ssc":
			return {"wheels": [Vector2(40, -11), Vector2(40, 11), Vector2(-30, -34), Vector2(-30, 34)], "wheel": Vector2(16, 7), "driver": Vector2(16, 0)}
	return {"wheels": [Vector2(30, -24), Vector2(30, 24), Vector2(-30, -24), Vector2(-30, 24)], "wheel": Vector2(22, 9), "driver": Vector2(0, 0)}


## Chassi visto de cima (sem rodas e sem piloto).
static func draw_top_body(ci: CanvasItem, shape: String, body: Color, accent: Color) -> void:
	var dark := body.darkened(0.25)
	match shape:
		"jeantaud":
			layered(ci, [
				[rrect(Rect2(-44, -20, 80, 40), 10), body],
				[rrect(Rect2(26, -16, 20, 32), 7), accent],
				[rrect(Rect2(-40, -18, 14, 36), 5), dark],
			])
			ci.draw_colored_polygon(rrect(Rect2(-20, -15, 22, 9), 2), Color(0.25, 0.25, 0.3))
			ci.draw_colored_polygon(rrect(Rect2(-20, 6, 22, 9), 2), Color(0.25, 0.25, 0.3))
			_bolt(ci, Vector2(-9, -10.5), 5.0, accent)
			_bolt(ci, Vector2(-9, 10.5), 5.0, accent)
			ci.draw_circle(Vector2(42, -17), 4.0, Color(1, 0.95, 0.6))
			ci.draw_circle(Vector2(42, 17), 4.0, Color(1, 0.95, 0.6))
		"jamais_contente":
			layered(ci, [
				[lens(-50, 52, 0, 17, 18, 0.6), body],
				[ellipse(Vector2(-30, 0), Vector2(13, 13), 20), COPPER],
			])
			ci.draw_colored_polygon(rrect(Rect2(-14, -3, 62, 6), 3), accent)
			ci.draw_circle(Vector2(-30, 0), 6.0, Color(0.15, 0.13, 0.12))
			ci.draw_arc(Vector2(-30, 0), 10.0, 0, TAU, 20, COPPER.lightened(0.3), 2.0, true)
		"golden_arrow":
			var fin := PackedVector2Array([Vector2(-40, -8), Vector2(-60, -24), Vector2(-50, -8)])
			layered(ci, [
				[lens(-56, 58, 0, 15, 18, 0.6), body],
				[ellipse(Vector2(12, -16), Vector2(26, 7), 18), body],
				[ellipse(Vector2(12, 16), Vector2(26, 7), 18), body],
				[fin, accent],
				[mirror_y(fin), accent],
			])
			ci.draw_colored_polygon(PackedVector2Array([Vector2(44, 0), Vector2(-24, -6), Vector2(-24, 6)]), accent)
			ci.draw_arc(Vector2(-4, 0), 9.0, -1.2, 1.2, 10, GLASS, 4.0, true)
		"blue_bird":
			layered(ci, [
				[rrect(Rect2(-52, -16, 96, 32), 14), body],
				[ellipse(Vector2(44, 0), Vector2(14, 15), 18), body],
			])
			ci.draw_colored_polygon(rrect(Rect2(-50, -3, 24, 6), 2), Color.WHITE)
			ci.draw_colored_polygon(rrect(Rect2(-20, -12, 70, 4), 2), Color.WHITE)
			ci.draw_colored_polygon(rrect(Rect2(-20, 8, 70, 4), 2), Color.WHITE)
			ci.draw_arc(Vector2(-2, 0), 9.0, -1.2, 1.2, 10, GLASS, 4.0, true)
		"spirit_of_america":
			var wing := PackedVector2Array([Vector2(-46, -27), Vector2(-36, -27), Vector2(-20, -8), Vector2(-46, -8)])
			layered(ci, [
				[lens(-58, 58, 0, 13, 18, 0.6), body],
				[wing, body],
				[mirror_y(wing), body],
			])
			ci.draw_colored_polygon(rrect(Rect2(-46, -3, 90, 6), 3), accent)
			ci.draw_colored_polygon(rrect(Rect2(-40, -8, 70, 3), 1), Color(0.15, 0.3, 0.75))
			ci.draw_colored_polygon(rrect(Rect2(-40, 5, 70, 3), 1), Color(0.15, 0.3, 0.75))
			ci.draw_circle(Vector2(-55, 0), 6.0, Color(0.2, 0.2, 0.22))
			ci.draw_colored_polygon(PackedVector2Array([Vector2(58, 0), Vector2(46, -5), Vector2(46, 5)]), accent)
		"thrust_ssc":
			var light := body.lightened(0.25)
			layered(ci, [
				[lens(-56, 60, 0, 10, 18, 0.6), body],
				[rrect(Rect2(-48, -32, 74, 20), 9), light],
				[rrect(Rect2(-48, 12, 74, 20), 9), light],
			])
			ci.draw_colored_polygon(ellipse(Vector2(24, -22), Vector2(4, 8), 12), Color(0.08, 0.08, 0.1))
			ci.draw_colored_polygon(ellipse(Vector2(24, 22), Vector2(4, 8), 12), Color(0.08, 0.08, 0.1))
			ci.draw_colored_polygon(ellipse(Vector2(-48, -22), Vector2(4, 8), 12), accent)
			ci.draw_colored_polygon(ellipse(Vector2(-48, 22), Vector2(4, 8), 12), accent)
			ci.draw_colored_polygon(rrect(Rect2(-40, -27, 50, 4), 2), accent)
			ci.draw_colored_polygon(rrect(Rect2(-40, 23, 50, 4), 2), accent)
		_:
			layered(ci, [[rrect(Rect2(-48, -20, 96, 40), 12), body]])


static func draw_top_wheel(ci: CanvasItem, size: Vector2) -> void:
	var r := Rect2(-size * 0.5, size)
	outlined(ci, rrect(r, minf(size.y * 0.45, 4.0)), TIRE, 2.0)
	ci.draw_line(Vector2(-size.x * 0.35, 0), Vector2(size.x * 0.35, 0), RIM, 2.0)


## Cabeça do piloto vista de cima (basicamente o chapéu/capacete).
static func draw_top_driver(ci: CanvasItem, hat: String, skin: Color, hair: Color, accent: Color) -> void:
	match hat:
		"top_hat":
			outlined(ci, ellipse(Vector2.ZERO, Vector2(12, 12), 18), Color(0.12, 0.1, 0.14), 2.5)
			ci.draw_circle(Vector2.ZERO, 7.5, Color(0.22, 0.2, 0.26))
			ci.draw_arc(Vector2.ZERO, 8.5, 0, TAU, 18, accent, 2.0, true)
		"elegant":
			outlined(ci, ellipse(Vector2(-1, 0), Vector2(15, 13), 18), accent, 2.5)
			ci.draw_circle(Vector2(-1, 0), 7.0, accent.darkened(0.25))
			ci.draw_colored_polygon(ellipse(Vector2(-8, -8), Vector2(9, 3), 10), Color(1, 0.92, 0.5))
		"aviator":
			outlined(ci, ellipse(Vector2.ZERO, Vector2(11, 10), 18), Color(0.55, 0.33, 0.18), 2.5)
			ci.draw_colored_polygon(rrect(Rect2(-9, -2, 18, 4), 1.5), Color(0.86, 0.15, 0.2))
			ci.draw_circle(Vector2(7, -4), 3.5, Color(1.0, 0.75, 0.2))
			ci.draw_circle(Vector2(7, 4), 3.5, Color(1.0, 0.75, 0.2))
		"mad_hair":
			for i in 8:
				var a := TAU * i / 8.0
				ci.draw_circle(Vector2(cos(a), sin(a)) * 9.0, 5.5, hair)
			outlined(ci, ellipse(Vector2.ZERO, Vector2(8, 8), 16), skin, 2.0)
			ci.draw_circle(Vector2(5, -3), 3.0, Color(0.4, 1.0, 0.5))
			ci.draw_circle(Vector2(5, 3), 3.0, Color(0.4, 1.0, 0.5))
		"straw_hat":
			outlined(ci, ellipse(Vector2.ZERO, Vector2(15, 15), 20), Color(0.95, 0.82, 0.45), 2.5)
			ci.draw_circle(Vector2.ZERO, 8.5, Color(0.85, 0.7, 0.35))
			ci.draw_arc(Vector2.ZERO, 9.0, 0, TAU, 20, Color(0.2, 0.15, 0.1), 2.5, true)
		_:
			outlined(ci, ellipse(Vector2.ZERO, Vector2(10, 10), 16), skin, 2.0)


static func draw_shadow(ci: CanvasItem, length: float, width: float, alpha: float = 0.3) -> void:
	ci.draw_colored_polygon(ellipse(Vector2.ZERO, Vector2(length * 0.55, width * 0.55), 20), Color(0, 0, 0, alpha))


static func _bolt(ci: CanvasItem, c: Vector2, s: float, color: Color) -> void:
	ci.draw_polyline(PackedVector2Array([c + Vector2(-s, -s * 0.3), c + Vector2(0, s * 0.3), c + Vector2(-s * 0.2, -s * 0.3), c + Vector2(s, s * 0.3)]), color, 1.6, true)


# ================================================================ VISTA DE LADO

## Carro de lado (aponta para a direita, rodas tocando y=0).
## silhouette = true desenha tudo preto (montagem histórica da intro).
## data (opcional) desenha o piloto com o chapéu do personagem.
static func draw_side(ci: CanvasItem, shape: String, body: Color, accent: Color, silhouette: bool = false,
		wheel_rot: float = 0.0, data: CharacterData = null) -> void:
	var b := SIL if silhouette else body
	var a := SIL if silhouette else accent
	var d := SIL if silhouette else body.darkened(0.3)
	var glass := SIL if silhouette else GLASS
	var ow := 0.0 if silhouette else 5.0
	var wheels := []
	var head := Vector2.ZERO
	var head_r := 16.0
	match shape:
		"jeantaud":
			layered(ci, [
				[rrect(Rect2(-112, -116, 22, 46), 6), d],
				[rrect(Rect2(-122, -80, 226, 44), 10), b],
				[rrect(Rect2(90, -76, 42, 38), 14), a],
				[rrect(Rect2(-64, -46, 96, 16), 4), SIL if silhouette else Color(0.3, 0.3, 0.35)],
			], ow)
			if not silhouette:
				ci.draw_line(Vector2(122, -78), Vector2(126, -96), OUTLINE, 3.0)
				ci.draw_circle(Vector2(127, -100), 7.0, Color(1, 0.95, 0.6))
				_bolt(ci, Vector2(-16, -38), 10.0, accent)
			wheels = [[Vector2(-76, -40), 40.0, true], [Vector2(76, -40), 40.0, true]]
			head = Vector2(-40, -112)
		"jamais_contente":
			var parts := [
				[lens(-142, 142, -64, 30, 22, 0.55), b],
				[rrect(Rect2(-112, -42, 224, 9), 3), d],
			]
			if not silhouette:
				# a caldeira é a "gambiarra" do Zé Vapor (a original de 1899 era elétrica)
				parts.append([rrect(Rect2(-124, -116, 38, 56), 9), SIL if silhouette else COPPER])
				parts.append([rrect(Rect2(-112, -146, 13, 34), 3), SIL if silhouette else Color(0.2, 0.18, 0.18)])
			layered(ci, parts, ow)
			if not silhouette:
				ci.draw_colored_polygon(rrect(Rect2(-96, -70, 200, 7), 3), accent)
			wheels = [[Vector2(-88, -32), 32.0, true], [Vector2(88, -32), 32.0, true]]
			head = Vector2(4, -110)
		"golden_arrow":
			layered(ci, [
				[PackedVector2Array([Vector2(-152, -46), Vector2(-112, -54), Vector2(-146, -100)]), a],
				[lens(-152, 156, -42, 27, 22, 0.5), b],
			], ow)
			if not silhouette:
				ci.draw_colored_polygon(rrect(Rect2(-118, -48, 236, 8), 4), accent)
				ci.draw_colored_polygon(PackedVector2Array([Vector2(-66, -66), Vector2(-54, -82), Vector2(-46, -66)]), glass)
			wheels = [[Vector2(-104, -24), 24.0, false], [Vector2(100, -24), 24.0, false]]
			head = Vector2(-82, -80)
			head_r = 14.0
		"blue_bird":
			layered(ci, [
				[PackedVector2Array([Vector2(-150, -68), Vector2(-104, -74), Vector2(-146, -120)]), b],
				[rrect(Rect2(-150, -76, 262, 50), 24), b],
				[ellipse(Vector2(116, -51), Vector2(34, 25), 20), b],
			], ow)
			if not silhouette:
				ci.draw_colored_polygon(rrect(Rect2(-132, -56, 250, 8), 4), Color.WHITE)
				ci.draw_colored_polygon(PackedVector2Array([Vector2(-48, -76), Vector2(-36, -92), Vector2(-26, -76)]), glass)
			wheels = [[Vector2(-100, -26), 26.0, false], [Vector2(96, -26), 26.0, false]]
			head = Vector2(-62, -90)
			head_r = 14.0
		"spirit_of_america":
			layered(ci, [
				[PackedVector2Array([Vector2(-150, -56), Vector2(-110, -60), Vector2(-138, -140), Vector2(-150, -140)]), b],
				[lens(-152, 156, -52, 22, 22, 0.55), b],
				[ellipse(Vector2(-24, -42), Vector2(44, 11), 18), SIL if silhouette else Color(0.3, 0.3, 0.34)],
				[ellipse(Vector2(70, -72), Vector2(24, 11), 16), glass],
			], ow)
			if not silhouette:
				ci.draw_colored_polygon(rrect(Rect2(-120, -60, 230, 6), 3), accent)
				ci.draw_colored_polygon(rrect(Rect2(-120, -53, 230, 4), 2), Color(0.15, 0.3, 0.75))
				ci.draw_colored_polygon(PackedVector2Array([Vector2(156, -52), Vector2(120, -62), Vector2(120, -42)]), accent)
			wheels = [[Vector2(-100, -22), 22.0, false], [Vector2(110, -22), 22.0, false]]
			head = Vector2(66, -76)
			head_r = 10.0
		"thrust_ssc":
			layered(ci, [
				[PackedVector2Array([Vector2(-150, -64), Vector2(-100, -70), Vector2(-130, -152), Vector2(-150, -152)]), b],
				[lens(-152, 160, -60, 19, 22, 0.55), b],
				[rrect(Rect2(-122, -80, 172, 42), 20), SIL if silhouette else body.lightened(0.25)],
				[ellipse(Vector2(92, -78), Vector2(20, 10), 16), glass],
			], ow)
			if not silhouette:
				ci.draw_colored_polygon(ellipse(Vector2(48, -59), Vector2(9, 18), 14), Color(0.08, 0.08, 0.1))
				ci.draw_colored_polygon(ellipse(Vector2(-122, -59), Vector2(8, 17), 14), accent)
				ci.draw_colored_polygon(rrect(Rect2(-100, -64, 130, 6), 3), accent)
			wheels = [[Vector2(-100, -24), 24.0, false], [Vector2(112, -24), 24.0, false]]
			head = Vector2(88, -80)
			head_r = 10.0
		_:
			layered(ci, [[rrect(Rect2(-140, -80, 280, 50), 18), b]], ow)
			wheels = [[Vector2(-90, -28), 28.0, false], [Vector2(90, -28), 28.0, false]]
			head = Vector2(0, -96)
	if data != null:
		draw_side_driver(ci, data, head, head_r, silhouette)
	elif silhouette:
		ci.draw_circle(head, head_r, SIL)
	for w in wheels:
		draw_side_wheel(ci, w[0], w[1], wheel_rot, w[2], silhouette)


## Carro de lado de um personagem em pos (meio do eixo, no chão) com escala.
## Usa a textura "car_side_<id>" (Pixel Vehicle Pack) se existir; senão o desenho procedural.
static func draw_side_for(ci: CanvasItem, data: CharacterData, pos: Vector2, scale: float,
		wheel_rot: float = 0.0, silhouette: bool = false) -> void:
	var tex := data.car_side_texture()
	if tex != null and not silhouette:
		var w := 300.0 * scale
		var h := w * float(tex.get_height()) / float(tex.get_width())
		ci.draw_texture_rect(tex, Rect2(pos.x - w * 0.5, pos.y - h, w, h), false)
		return
	ci.draw_set_transform(pos, 0.0, Vector2(scale, scale))
	draw_side(ci, data.car_shape, data.body_color, data.accent_color, silhouette, wheel_rot, data)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func draw_side_wheel(ci: CanvasItem, c: Vector2, r: float, rot: float, spoked: bool, silhouette: bool = false) -> void:
	if silhouette:
		ci.draw_circle(c, r, SIL)
		return
	ci.draw_circle(c, r + 2.5, OUTLINE)
	ci.draw_circle(c, r, TIRE)
	ci.draw_circle(c, r * (0.82 if spoked else 0.55), RIM)
	if spoked:
		ci.draw_circle(c, r * 0.68, TIRE.lightened(0.15))
	var n := 8 if spoked else 4
	for i in n:
		var ang := rot + TAU * i / float(n)
		ci.draw_line(c, c + Vector2(cos(ang), sin(ang)) * r * (0.8 if spoked else 0.5), OUTLINE if spoked else Color(0.5, 0.5, 0.55), 2.5 if spoked else 3.0)
	ci.draw_circle(c, r * 0.16, OUTLINE)


## Cabeça do piloto de perfil (olhando para a direita).
static func draw_side_driver(ci: CanvasItem, data: CharacterData, c: Vector2, r: float, silhouette: bool = false) -> void:
	var skin := SIL if silhouette else data.skin_color
	var hair := SIL if silhouette else data.hair_color
	var acc := SIL if silhouette else data.accent_color
	match data.hat_style:
		"elegant":
			ci.draw_circle(c + Vector2(-r * 0.5, r * 0.1), r * 0.9, hair)
		"mad_hair":
			for i in 6:
				var a := PI + PI * i / 5.0
				ci.draw_circle(c + Vector2(cos(a), sin(a)) * r * 0.95, r * 0.5, hair)
	ci.draw_circle(c, r + 2.0, OUTLINE)
	ci.draw_circle(c, r, skin)
	if not silhouette:
		ci.draw_circle(c + Vector2(r * 0.45, -r * 0.2), r * 0.16, OUTLINE)
		ci.draw_circle(c + Vector2(r * 0.95, r * 0.08), r * 0.22, data.skin_color.darkened(0.15))
	match data.hat_style:
		"top_hat":
			var hat := SIL if silhouette else Color(0.12, 0.1, 0.14)
			ci.draw_colored_polygon(rrect(Rect2(c.x - r * 1.1, c.y - r * 0.95, r * 2.2, r * 0.35), 3), hat)
			ci.draw_colored_polygon(rrect(Rect2(c.x - r * 0.65, c.y - r * 2.2, r * 1.3, r * 1.35), 3), hat)
			ci.draw_colored_polygon(rrect(Rect2(c.x - r * 0.65, c.y - r * 1.25, r * 1.3, r * 0.25), 1), acc)
			if not silhouette:
				ci.draw_arc(c + Vector2(r * 0.5, r * 0.35), r * 0.35, PI, TAU, 8, OUTLINE, 2.5, true)
		"elegant":
			ci.draw_colored_polygon(ellipse(c + Vector2(-r * 0.1, -r * 0.8), Vector2(r * 1.3, r * 0.32), 16), acc)
			ci.draw_colored_polygon(ellipse(c + Vector2(-r * 0.2, -r * 1.05), Vector2(r * 0.6, r * 0.38), 14), acc)
			ci.draw_colored_polygon(ellipse(c + Vector2(-r * 0.9, -r * 1.4), Vector2(r * 0.25, r * 0.7), 12), SIL if silhouette else Color(1, 0.92, 0.5))
		"aviator":
			ci.draw_colored_polygon(half_ellipse(c, Vector2(r * 1.08, r * 1.08), PI, TAU), SIL if silhouette else Color(0.55, 0.33, 0.18))
			if not silhouette:
				ci.draw_circle(c + Vector2(r * 0.55, -r * 0.55), r * 0.32, Color(1.0, 0.75, 0.2))
				ci.draw_arc(c + Vector2(r * 0.55, -r * 0.55), r * 0.32, 0, TAU, 12, OUTLINE, 2.0, true)
				var scarf := PackedVector2Array([c + Vector2(-r * 0.6, r * 0.8), c + Vector2(-r * 2.6, r * 0.4), c + Vector2(-r * 2.4, r * 1.0)])
				ci.draw_colored_polygon(scarf, Color(0.86, 0.15, 0.2))
		"mad_hair":
			if not silhouette:
				ci.draw_circle(c + Vector2(r * 0.5, -r * 0.6), r * 0.3, Color(0.4, 1.0, 0.5))
				ci.draw_arc(c + Vector2(r * 0.5, -r * 0.6), r * 0.3, 0, TAU, 12, OUTLINE, 2.0, true)
		"straw_hat":
			var straw := SIL if silhouette else Color(0.95, 0.82, 0.45)
			ci.draw_colored_polygon(ellipse(c + Vector2(0, -r * 0.75), Vector2(r * 1.6, r * 0.28), 18), straw)
			ci.draw_colored_polygon(rrect(Rect2(c.x - r * 0.75, c.y - r * 1.5, r * 1.5, r * 0.8), 5), straw)
			ci.draw_colored_polygon(rrect(Rect2(c.x - r * 0.75, c.y - r * 0.95, r * 1.5, r * 0.22), 1), SIL if silhouette else Color(0.2, 0.15, 0.1))
			if not silhouette:
				ci.draw_colored_polygon(ellipse(c + Vector2(r * 0.75, r * 0.35), Vector2(r * 0.42, r * 0.16), 10), data.hair_color)


# ================================================================ RETRATO (frente)

## Retrato do piloto em um círculo de raio R. Usa a textura (Toon Characters) se existir.
static func draw_portrait(ci: CanvasItem, data: CharacterData, c: Vector2, big_r: float, with_bg: bool = true) -> void:
	if data == null:
		return
	if with_bg:
		ci.draw_circle(c, big_r + 4.0, OUTLINE)
		ci.draw_circle(c, big_r, data.body_color.lerp(Color(0.15, 0.1, 0.25), 0.45))
		ci.draw_circle(c + Vector2(0, -big_r * 0.15), big_r * 0.8, data.body_color.lerp(Color.WHITE, 0.25))
	var tex := data.portrait()
	if tex != null:
		var s := big_r * 1.7
		ci.draw_texture_rect(tex, Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), false)
		return
	var r := big_r * 0.5
	var skin := data.skin_color
	var hair := data.hair_color
	var acc := data.accent_color
	var head := c + Vector2(0, -big_r * 0.02)
	# ombros / roupa
	ci.draw_colored_polygon(ellipse(c + Vector2(0, big_r * 0.8), Vector2(big_r * 0.68, big_r * 0.24), 18), data.body_color.darkened(0.1))
	# cabelo atrás da cabeça
	match data.hat_style:
		"elegant":
			ci.draw_colored_polygon(ellipse(head + Vector2(0, r * 0.35), Vector2(r * 1.3, r * 1.25), 20), hair)
		"mad_hair":
			for i in 11:
				var a := deg_to_rad(150.0 + 240.0 * i / 10.0)
				ci.draw_circle(head + Vector2(cos(a), sin(a)) * r * 1.08, r * 0.42, hair)
	# pescoço + cabeça + orelhas
	ci.draw_colored_polygon(rrect(Rect2(head.x - r * 0.35, head.y + r * 0.6, r * 0.7, r * 0.7), 3), skin.darkened(0.12))
	ci.draw_circle(head + Vector2(-r, r * 0.05), r * 0.24, skin.darkened(0.08))
	ci.draw_circle(head + Vector2(r, r * 0.05), r * 0.24, skin.darkened(0.08))
	ci.draw_circle(head, r + 3.0, OUTLINE)
	ci.draw_circle(head, r, skin)
	# olhos
	var eye_y := head.y - r * 0.08
	for sx in [-1.0, 1.0]:
		var e := Vector2(head.x + sx * r * 0.38, eye_y)
		ci.draw_circle(e, r * 0.22, Color.WHITE)
		ci.draw_circle(e + Vector2(r * 0.05, r * 0.03), r * 0.11, OUTLINE)
		ci.draw_circle(e + Vector2(r * 0.09, -r * 0.03), r * 0.04, Color.WHITE)
	# nariz e boca
	ci.draw_circle(head + Vector2(0, r * 0.22), r * 0.15, skin.darkened(0.18))
	ci.draw_arc(head + Vector2(0, r * 0.38), r * 0.32, 0.25, PI - 0.25, 10, OUTLINE, 3.0, true)
	# detalhes por personagem
	match data.hat_style:
		"top_hat":
			# bigode enrolado + monóculo + cartola
			ci.draw_arc(head + Vector2(-r * 0.25, r * 0.38), r * 0.25, PI * 1.1, PI * 2.0, 8, OUTLINE, 4.0, true)
			ci.draw_arc(head + Vector2(r * 0.25, r * 0.38), r * 0.25, PI, PI * 1.9, 8, OUTLINE, 4.0, true)
			ci.draw_arc(head + Vector2(r * 0.38, eye_y - head.y), r * 0.3, 0, TAU, 16, Color(0.95, 0.8, 0.3), 3.0, true)
			ci.draw_line(head + Vector2(r * 0.6, r * 0.05), head + Vector2(r * 0.85, r * 0.9), Color(0.95, 0.8, 0.3), 2.0)
			var hat := Color(0.12, 0.1, 0.14)
			outlined(ci, rrect(Rect2(head.x - r * 1.25, head.y - r * 0.95, r * 2.5, r * 0.32), 4), hat, 3.0)
			outlined(ci, rrect(Rect2(head.x - r * 0.75, head.y - r * 2.15, r * 1.5, r * 1.3), 4), hat, 3.0)
			ci.draw_colored_polygon(rrect(Rect2(head.x - r * 0.75, head.y - r * 1.15, r * 1.5, r * 0.22), 1), acc)
		"elegant":
			# batom, cílios, chapéu com pena e colar de pérolas
			ci.draw_colored_polygon(ellipse(head + Vector2(0, r * 0.52), Vector2(r * 0.2, r * 0.1), 10), Color(0.85, 0.1, 0.25))
			for sx in [-1.0, 1.0]:
				var e := Vector2(head.x + sx * r * 0.38, eye_y)
				ci.draw_line(e + Vector2(-r * 0.2 * sx, -r * 0.2), e + Vector2(-r * 0.32 * sx, -r * 0.34), OUTLINE, 2.0)
			outlined(ci, ellipse(head + Vector2(r * 0.2, -r * 0.85), Vector2(r * 1.05, r * 0.28), 18), acc, 3.0)
			outlined(ci, ellipse(head + Vector2(r * 0.25, -r * 1.05), Vector2(r * 0.55, r * 0.32), 14), acc, 3.0)
			outlined(ci, ellipse(head + Vector2(r * 0.95, -r * 1.35), Vector2(r * 0.18, r * 0.55), 12), Color(1, 0.92, 0.5), 2.0)
			for i in 7:
				var a := deg_to_rad(35.0 + 110.0 * i / 6.0)
				ci.draw_circle(head + Vector2(cos(a) * r * 0.62, r * 0.95 + sin(a) * r * 0.25), r * 0.09, Color(1, 1, 0.97))
		"aviator":
			# queixo de herói, sorriso com dentes, touca de aviador com óculos
			ci.draw_colored_polygon(rrect(Rect2(head.x - r * 0.3, head.y + r * 0.42, r * 0.6, r * 0.16), 2), Color.WHITE)
			ci.draw_colored_polygon(half_ellipse(head + Vector2(0, -r * 0.1), Vector2(r * 1.08, r * 1.0), PI, TAU), Color(0.55, 0.33, 0.18))
			ci.draw_colored_polygon(rrect(Rect2(head.x - r * 1.08, head.y - r * 0.18, r * 0.3, r * 0.75), 4), Color(0.55, 0.33, 0.18))
			ci.draw_colored_polygon(rrect(Rect2(head.x + r * 0.78, head.y - r * 0.18, r * 0.3, r * 0.75), 4), Color(0.55, 0.33, 0.18))
			for sx in [-1.0, 1.0]:
				var g := head + Vector2(sx * r * 0.36, -r * 0.62)
				ci.draw_circle(g, r * 0.26, Color(1.0, 0.75, 0.2))
				ci.draw_arc(g, r * 0.26, 0, TAU, 14, OUTLINE, 3.0, true)
			ci.draw_colored_polygon(PackedVector2Array([head + Vector2(-r * 0.4, r * 1.0), head + Vector2(r * 0.4, r * 1.0), head + Vector2(0, r * 1.35)]), Color(0.86, 0.15, 0.2))
		"mad_hair":
			# óculos de laboratório e sorriso maníaco
			ci.draw_arc(head + Vector2(0, r * 0.32), r * 0.45, 0.15, PI - 0.15, 12, OUTLINE, 4.0, true)
			for sx in [-1.0, 1.0]:
				var g := Vector2(head.x + sx * r * 0.38, eye_y)
				ci.draw_arc(g, r * 0.3, 0, TAU, 16, Color(0.35, 0.35, 0.4), 5.0, true)
				ci.draw_circle(g, r * 0.26, Color(0.4, 1.0, 0.5, 0.35))
			ci.draw_line(head + Vector2(-r * 0.08, eye_y - head.y), head + Vector2(r * 0.08, eye_y - head.y), Color(0.35, 0.35, 0.4), 4.0)
			ci.draw_colored_polygon(rrect(Rect2(head.x - r * 0.7, head.y + r * 1.0, r * 1.4, r * 0.4), 4), Color.WHITE)
		"straw_hat":
			# bigodão, chapéu de palha e lenço verde-amarelo
			ci.draw_colored_polygon(ellipse(head + Vector2(-r * 0.22, r * 0.36), Vector2(r * 0.3, r * 0.14), 12), hair)
			ci.draw_colored_polygon(ellipse(head + Vector2(r * 0.22, r * 0.36), Vector2(r * 0.3, r * 0.14), 12), hair)
			var straw := Color(0.95, 0.82, 0.45)
			outlined(ci, ellipse(head + Vector2(0, -r * 0.72), Vector2(r * 1.7, r * 0.34), 20), straw, 3.0)
			outlined(ci, rrect(Rect2(head.x - r * 0.8, head.y - r * 1.6, r * 1.6, r * 0.9), 8), straw, 3.0)
			ci.draw_colored_polygon(rrect(Rect2(head.x - r * 0.8, head.y - r * 0.98, r * 1.6, r * 0.2), 1), Color(0.2, 0.15, 0.1))
			ci.draw_colored_polygon(PackedVector2Array([head + Vector2(-r * 0.6, r * 0.95), head + Vector2(r * 0.6, r * 0.95), head + Vector2(0, r * 1.4)]), acc)
			ci.draw_colored_polygon(PackedVector2Array([head + Vector2(-r * 0.3, r * 1.0), head + Vector2(r * 0.3, r * 1.0), head + Vector2(0, r * 1.2)]), data.body_color)


## Carro bloqueado ("EM BREVE"): silhueta com "?".
static func draw_locked_portrait(ci: CanvasItem, c: Vector2, big_r: float) -> void:
	ci.draw_circle(c, big_r + 4.0, OUTLINE)
	ci.draw_circle(c, big_r, Color(0.2, 0.2, 0.28))
	UIStyle.draw_text(ci, c, "?", int(big_r * 1.1), Color(0.6, 0.6, 0.7), 6, true)
