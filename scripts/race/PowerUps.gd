class_name PowerUps
extends RefCounted
## Definição dos ITENS (caixas "?") e dos ESPECIAIS de cada piloto (toque duplo).
## Para criar um item novo: adicione o id em ALL/INFO/_weights, implemente em use_item()
## e desenhe o ícone em draw_icon(). Para um especial novo: um "case" em use_special().

const OIL := "oil"
const BANANA := "banana"
const ROCKET := "rocket"
const MAGNET := "magnet"
const PARTS := "parts"
const BARRIER := "barrier"
const ALL: Array[String] = [OIL, BANANA, ROCKET, MAGNET, PARTS, BARRIER]

const INFO := {
	"oil": {"name": "ÓLEO", "desc": "Poça escorregadia para trás", "color": Color(0.25, 0.2, 0.3)},
	"banana": {"name": "BANANA", "desc": "Clássica e infalível", "color": Color(1.0, 0.86, 0.2)},
	"rocket": {"name": "FOGUETE", "desc": "Persegue quem está à frente", "color": Color(0.9, 0.22, 0.27)},
	"magnet": {"name": "ÍMÃ", "desc": "Puxa você até o rival da frente", "color": Color(0.85, 0.15, 0.2)},
	"parts": {"name": "CHUVA DE PEÇAS", "desc": "Parafusos caem do céu nos rivais", "color": Color(0.7, 0.72, 0.78)},
	"barrier": {"name": "BARREIRA DO SOM", "desc": "Turbo supersônico com BOOM", "color": Color(0.6, 0.9, 1.0)},
}


static func item_name(id: String) -> String:
	if INFO.has(id):
		return INFO[id]["name"]
	return id.to_upper()


## Pesos de sorteio. pos_ratio 0 = 1º lugar, 1 = último (quem está atrás ganha itens melhores).
static func _weights(pos_ratio: float) -> Dictionary:
	var t := clampf(pos_ratio, 0.0, 1.0)
	return {
		OIL: lerpf(30.0, 10.0, t),
		BANANA: lerpf(35.0, 5.0, t),
		ROCKET: lerpf(6.0, 25.0, t),
		MAGNET: lerpf(12.0, 20.0, t),
		PARTS: lerpf(15.0, 15.0, t),
		BARRIER: lerpf(2.0, 25.0, t),
	}


static func roll(pos_ratio: float, rng: RandomNumberGenerator) -> String:
	var w := _weights(pos_ratio)
	var total := 0.0
	for k in w:
		total += float(w[k])
	var r := rng.randf() * total
	for k in w:
		r -= float(w[k])
		if r <= 0.0:
			return k
	return BANANA


# ================================================================ ITENS

static func use_item(id: String, car: Car) -> void:
	var race := car.race
	var fwd := Vector2.RIGHT.rotated(car.rotation)
	match id:
		OIL:
			race.spawn_hazard("oil", car.global_position - fwd * 90.0, car)
			_sfx(car, "splat")
		BANANA:
			race.spawn_hazard("banana", car.global_position - fwd * 80.0, car)
			_sfx(car, "banana")
		ROCKET:
			race.spawn_rocket(car)
			_sfx(car, "rocket")
		MAGNET:
			car.magnet_timer = 4.0
			_sfx(car, "magnet")
		PARTS:
			race.spawn_parts_rain(car)
			_sfx(car, "clank")
		BARRIER:
			car.apply_boost(1.9, 2.6, 1320.0)
			race.sonic_boom(car)
	if car.is_player:
		race.hud.show_message(item_name(id) + "!", INFO[id]["color"], 0.9, 52)


# ================================================================ ESPECIAIS DOS PILOTOS

static func use_special(car: Car) -> void:
	var race := car.race
	var pos := car.global_position
	var fwd := Vector2.RIGHT.rotated(car.rotation)
	match car.data.special_id:
		"faisca":
			# Comte Éclair: descarga elétrica em quem estiver perto
			RaceFX.ring(race, pos, 420.0, Color(0.5, 0.85, 1.0), 0.45, 18.0)
			for c in race.cars_near(pos, 420.0, car):
				RaceFX.lightning(race, pos, c.global_position, Color(0.6, 0.9, 1.0))
				if c.shock(1.6):
					car.hits_given += 1
			_sfx(car, "zap", true)
		"nitro_real":
			# Lady Nitro: turbo + escudo
			car.apply_boost(1.45, 3.0)
			car.shield_timer = 3.0
			_sfx(car, "boost", true)
		"pos_combustao":
			# Capitão Foguete: dispara e arremessa quem vem atrás
			car.apply_boost(1.4, 2.2)
			RaceFX.flame_blast(race, pos - fwd * 60.0, (-fwd).angle())
			for c in race.cars_near(pos, 480.0, car):
				var to := (c.global_position - pos).normalized()
				if to.dot(-fwd) > 0.35:
					c.push(-fwd * 520.0)
					if c.spin_out(1.0):
						car.hits_given += 1
			_sfx(car, "explosion", true)
		"teleporte":
			# Doutor Thrust: portal pela pista (20% de chance de dar errado)
			var ok := randf() < 0.8
			var dist := 760.0 if ok else -300.0
			var lat := clampf(race.track.lateral_of(pos), -110.0, 110.0)
			var new_off := car.progress + dist
			RaceFX.portal(race, pos)
			car.teleport_to(race.track.sample(new_off, lat), race.track.direction_at(new_off).angle())
			RaceFX.portal(race, car.global_position)
			if not ok:
				RaceFX.float_text(race, car.global_position, "OPS!", UIStyle.RED, 48)
			_sfx(car, "teleport" if ok else "ops", true)
		"nuvem_vapor":
			# Zé Vapor: nuvem que atola quem vem atrás + empurrãozinho
			race.spawn_hazard("steam", pos - fwd * 150.0, car)
			car.apply_boost(1.25, 1.6)
			_sfx(car, "steam", true)
		_:
			car.apply_boost(1.3, 1.5)
	if car.is_player:
		race.hud.show_message(car.data.special_name.to_upper() + "!", car.data.accent_color, 1.0, 46)
		race.shake(0.25)


static func _sfx(car: Car, sfx: String, always: bool = false) -> void:
	if car.is_player or always or car.race.is_near_player(car.global_position, 900.0):
		AudioManager.play_sfx(sfx, randf_range(0.95, 1.05), 0.0 if car.is_player else -6.0)


# ================================================================ ÍCONES (HUD)

## Desenha o ícone do item num círculo de raio ~size/2 centrado em c.
static func draw_icon(ci: CanvasItem, id: String, c: Vector2, size: float) -> void:
	var s := size * 0.5
	var ink := UIStyle.INK
	match id:
		OIL:
			CarArt.outlined(ci, CarArt.ellipse(c + Vector2(0, s * 0.25), Vector2(s * 0.62, s * 0.5), 20), Color(0.18, 0.14, 0.24), 3.0)
			CarArt.outlined(ci, PackedVector2Array([c + Vector2(-s * 0.35, s * 0.05), c + Vector2(0, -s * 0.7), c + Vector2(s * 0.35, s * 0.05)]), Color(0.18, 0.14, 0.24), 0.0)
			ci.draw_circle(c + Vector2(-s * 0.2, s * 0.1), s * 0.12, Color(0.6, 0.55, 0.9))
		BANANA:
			ci.draw_arc(c + Vector2(s * 0.15, -s * 0.15), s * 0.6, PI * 0.45, PI * 1.25, 16, ink, s * 0.42, true)
			ci.draw_arc(c + Vector2(s * 0.15, -s * 0.15), s * 0.6, PI * 0.48, PI * 1.22, 16, Color(1.0, 0.86, 0.2), s * 0.3, true)
			ci.draw_circle(c + Vector2(-s * 0.5, -s * 0.3), s * 0.1, Color(0.4, 0.25, 0.1))
		ROCKET:
			var body := CarArt.lens(-s * 0.7, s * 0.8, 0, s * 0.28, 12, 0.5)
			for i in body.size():
				body[i] = c + body[i].rotated(-PI * 0.25)
			CarArt.outlined(ci, PackedVector2Array([c + Vector2(-s * 0.6, s * 0.2).rotated(-PI * 0.25), c + Vector2(-s * 0.2, 0).rotated(-PI * 0.25), c + Vector2(-s * 0.7, s * 0.55).rotated(-PI * 0.25)]), ink, 0.0)
			CarArt.outlined(ci, body, Color(0.9, 0.22, 0.27), 3.0)
			ci.draw_circle(c + Vector2(s * 0.25, 0).rotated(-PI * 0.25), s * 0.13, Color(0.7, 0.9, 1.0))
			ci.draw_circle(c + Vector2(-s * 0.78, 0).rotated(-PI * 0.25), s * 0.18, Color(1.0, 0.7, 0.2))
		MAGNET:
			ci.draw_arc(c + Vector2(0, -s * 0.05), s * 0.45, 0.0, PI, 16, ink, s * 0.42, true)
			ci.draw_arc(c + Vector2(0, -s * 0.05), s * 0.45, 0.05, PI - 0.05, 16, Color(0.85, 0.15, 0.2), s * 0.3, true)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.6, -s * 0.55), Vector2(s * 0.3, s * 0.4)), Color(0.85, 0.85, 0.9))
			ci.draw_rect(Rect2(c + Vector2(s * 0.3, -s * 0.55), Vector2(s * 0.3, s * 0.4)), Color(0.85, 0.85, 0.9))
		PARTS:
			for i in 8:
				var a := TAU * i / 8.0
				ci.draw_line(c + Vector2(cos(a), sin(a)) * s * 0.3, c + Vector2(cos(a), sin(a)) * s * 0.62, Color(0.6, 0.62, 0.68), s * 0.22)
			ci.draw_circle(c, s * 0.42, Color(0.72, 0.74, 0.8))
			ci.draw_circle(c, s * 0.16, ink)
			ci.draw_line(c + Vector2(s * 0.3, -s * 0.75), c + Vector2(s * 0.75, -s * 0.3), Color(0.9, 0.75, 0.3), s * 0.16)
		BARRIER:
			for i in 3:
				ci.draw_arc(c + Vector2(-s * 0.35, 0), s * (0.35 + i * 0.22), -0.9, 0.9, 12, Color(0.6, 0.9, 1.0, 1.0 - i * 0.25), s * 0.12, true)
			CarArt.outlined(ci, PackedVector2Array([c + Vector2(-s * 0.75, -s * 0.18), c + Vector2(-s * 0.1, 0), c + Vector2(-s * 0.75, s * 0.18)]), Color.WHITE, 2.0)
			UIStyle.draw_text(ci, c + Vector2(0, s * 0.62), "MACH", int(s * 0.42), UIStyle.CREAM, 3)
		_:
			UIStyle.draw_text(ci, c, "?", int(size * 0.6), UIStyle.CREAM, 5, true)
