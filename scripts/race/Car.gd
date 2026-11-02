class_name Car
extends CharacterBody2D
## CARRO com física ARCADE exagerada (vista de cima, aponta para +X).
##
## * Controlado por um "controller" (PlayerController ou AIController) que preenche
##   throttle / brake / steer a cada frame e aciona itens/especiais.
## * Derrapagem: a velocidade lateral só é "comida" aos poucos (grip). Freio + curva = drift longo.
## * Saltos: altura "z" falsa (top-down). No ar o carro passa por cima de itens e de outros carros.
## * Batidas fortes desmontam o carro (CarVisual.disassemble) e ele se remonta sozinho.
## * Volta/posição: progresso medido na curva da pista + 2 checkpoints anti-atalho.

signal item_changed(item: String)
signal lap_completed(lap: int, lap_time: float)

const KMH := 1.0 # px/s -> km/h exibidos (a física e o velocímetro usam a mesma escala)
const GRAVITY_Z := 1500.0
const BRAKE_DECEL := 1500.0
const REVERSE_MAX := 230.0
const ROLL_DRAG := 240.0
const SPIN_RATE := 13.0
const WALL_CRASH_SPEED := 430.0
const WALL_BOUNCE_SPEED := 140.0
const CAR_CRASH_SPEED := 540.0
const ABS_MAX_SPEED := 1450.0 # teto absoluto (turbos somados não passam disso)

var data: CharacterData
var race: RaceController
var controller: RefCounted # PlayerController ou AIController (precisa de update(delta))
var is_player := false
var active := false # só anda depois do "JÁ!"

# --- entradas (preenchidas pelo controller)
var throttle := 0.0
var brake := 0.0
var steer := 0.0
var speed_scale := 1.0 # ajuste fino da IA (rubber band)

# --- estado físico / efeitos
var z := 0.0
var vz := 0.0
var spin_timer := 0.0
var stun_timer := 0.0
var shock_timer := 0.0
var slow_timer := 0.0
var slow_mult := 1.0
var boost_timer := 0.0
var boost_mult := 1.0
var boost_floor := 0.0
var shield_timer := 0.0
var invuln_timer := 0.0
var magnet_timer := 0.0
var magnet_target := Vector2.INF
var bonk_timer := 0.0
var bump_cooldown := 0.0
var offroad := false
var drifting := false
var wrong_way_time := 0.0
var _spin_dir := 1.0
var _flip_jump := false

# --- corrida
var laps_done := -1 # -1 = ainda no grid (antes de cruzar a linha pela 1ª vez)
var progress := 0.0
var checkpoints := 3
var lap_start := 0.0
var best_lap := 0.0
var finished := false
var finish_time := 0.0
var position_rank := 1

# --- itens / especial
var item := ""
var special_charge := 0.0
var _pending_item := ""
var _item_roll := 0.0

# --- estatísticas (pontuação)
var top_speed := 0.0
var air_time_total := 0.0
var crashes := 0
var hits_given := 0
var flips := 0
var reached_mach := false

@onready var visual: CarVisual = $Visual
var _engine: AudioStreamPlayer
var _skid_left: Line2D
var _skid_right: Line2D
var _boing_cd := 0.0


func setup(p_data: CharacterData, p_race: RaceController, p_player: bool) -> void:
	data = p_data
	race = p_race
	is_player = p_player
	visual.setup(data, self)
	if is_player:
		_engine = AudioManager.make_engine_player()
		add_child(_engine)
		_engine.play()


## Posiciona no grid de largada (atrás da linha de chegada).
func place_on_grid(offset: float, lateral: float) -> void:
	global_position = race.track.sample(offset, lateral)
	rotation = race.track.direction_at(offset).angle()
	progress = fposmod(offset, race.track.length)
	laps_done = -1
	checkpoints = 3


func _physics_process(delta: float) -> void:
	if data == null or race == null:
		return
	if controller != null:
		controller.call("update", delta)
	if not active:
		velocity = Vector2.ZERO
		_update_audio()
		visual.update_visual(delta)
		return
	_tick_timers(delta)
	_drive(delta)
	var pre := velocity
	move_and_slide()
	_handle_collisions(pre)
	_update_air(delta)
	_update_track_state(delta)
	_update_stats(delta)
	_update_audio()
	_update_skids()
	visual.update_visual(delta)


# ================================================================ física

func _tick_timers(delta: float) -> void:
	spin_timer = maxf(spin_timer - delta, 0.0)
	stun_timer = maxf(stun_timer - delta, 0.0)
	shock_timer = maxf(shock_timer - delta, 0.0)
	shield_timer = maxf(shield_timer - delta, 0.0)
	invuln_timer = maxf(invuln_timer - delta, 0.0)
	bonk_timer = maxf(bonk_timer - delta, 0.0)
	bump_cooldown = maxf(bump_cooldown - delta, 0.0)
	_boing_cd = maxf(_boing_cd - delta, 0.0)
	if slow_timer > 0.0:
		slow_timer -= delta
		if slow_timer <= 0.0:
			slow_mult = 1.0
	if boost_timer > 0.0:
		boost_timer -= delta
		if boost_timer <= 0.0:
			boost_mult = 1.0
			boost_floor = 0.0
	if magnet_timer > 0.0:
		magnet_timer -= delta
		if magnet_timer <= 0.0:
			magnet_target = Vector2.INF


func can_drive() -> bool:
	return stun_timer <= 0.0 and spin_timer <= 0.0


func current_top_speed() -> float:
	var top := data.max_speed * speed_scale
	if offroad and z <= 0.0:
		top *= 0.55
	if shock_timer > 0.0:
		top *= 0.45
	if slow_timer > 0.0:
		top *= slow_mult
	if magnet_timer > 0.0:
		top *= 1.15
	if boost_timer > 0.0:
		top = maxf(top * boost_mult, boost_floor)
	return top


func _drive(delta: float) -> void:
	var grounded := z <= 0.0
	var top := current_top_speed()
	var accel := data.acceleration * (2.2 if boost_timer > 0.0 else 1.0)

	# --- giro / direção
	var fwd0 := Vector2.RIGHT.rotated(rotation)
	var fs0 := velocity.dot(fwd0)
	if spin_timer > 0.0:
		rotation += SPIN_RATE * _spin_dir * delta
	elif grounded:
		var low_speed := clampf(absf(fs0) / 220.0, 0.0, 1.0)
		var high_damp := lerpf(1.0, 0.7, clampf(absf(fs0) / 1100.0, 0.0, 1.0))
		var reverse := -1.0 if fs0 < -10.0 else 1.0
		rotation += steer * data.handling * low_speed * high_damp * reverse * delta
	else:
		rotation += steer * data.handling * 0.3 * delta

	# --- decomposição frente/lado
	var fwd := Vector2.RIGHT.rotated(rotation)
	var side := Vector2.DOWN.rotated(rotation)
	var fspeed := velocity.dot(fwd)
	var lspeed := velocity.dot(side)
	if grounded:
		var thr := throttle if can_drive() else 0.0
		var brk := brake if can_drive() else 0.0
		if thr > 0.0 and fspeed < top:
			var r := clampf(fspeed / maxf(top, 1.0), 0.0, 1.0)
			fspeed = minf(fspeed + accel * thr * (1.0 - r * r * 0.6) * delta, top)
		elif fspeed > top:
			fspeed = move_toward(fspeed, top, 650.0 * delta)
		if brk > 0.0:
			if fspeed > 20.0:
				fspeed = move_toward(fspeed, 0.0, BRAKE_DECEL * brk * delta)
			else:
				fspeed = maxf(fspeed - 520.0 * brk * delta, -REVERSE_MAX)
		elif thr <= 0.0:
			fspeed = move_toward(fspeed, 0.0, ROLL_DRAG * delta)
		var grip := data.grip
		if spin_timer > 0.0:
			grip *= 0.25
		if offroad:
			grip *= 0.7
		if brk > 0.3 and absf(steer) > 0.35 and fspeed > 260.0:
			grip *= 0.3 # freio + curva = drift cartoon!
		lspeed = lerpf(lspeed, 0.0, 1.0 - exp(-grip * delta))
		drifting = absf(lspeed) > 150.0
	else:
		drifting = false
	velocity = fwd * fspeed + side * lspeed
	if magnet_timer > 0.0:
		_apply_magnet(delta)
	velocity = velocity.limit_length(ABS_MAX_SPEED)


func _apply_magnet(delta: float) -> void:
	var target := race.car_ahead_of(self)
	if target == null:
		magnet_timer = 0.0
		magnet_target = Vector2.INF
		return
	magnet_target = target.global_position
	var to := target.global_position - global_position
	var d := to.length()
	if d < 130.0:
		magnet_timer = 0.0
		magnet_target = Vector2.INF
		apply_boost(1.3, 1.0)
		RaceFX.float_text(race, global_position, "ZUPT!", UIStyle.RED, 40)
	elif d < 2400.0:
		velocity += to / d * 950.0 * delta


func _handle_collisions(pre: Vector2) -> void:
	var wall_done := false
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var other := col.get_collider()
		var n := col.get_normal()
		if other is Car:
			_bump_car(other as Car, n, pre)
		elif not wall_done:
			wall_done = true
			var impact := -pre.dot(n)
			if impact > WALL_CRASH_SPEED and z <= 0.0:
				velocity = pre.bounce(n) * 0.4
				if crash(0.0):
					RaceFX.float_text(race, global_position, ["CRASH!", "POW!", "CABRUM!"].pick_random(), UIStyle.ORANGE, 46)
			elif impact > WALL_BOUNCE_SPEED:
				velocity += n * impact * 0.65
				_boing(impact)


func _bump_car(other: Car, n: Vector2, pre: Vector2) -> void:
	if bump_cooldown > 0.0 or other.bump_cooldown > 0.0:
		return
	var rel := (pre - other.velocity).dot(n)
	if rel >= 0.0:
		return
	var m1 := data.weight
	var m2 := other.data.weight
	var j := -(1.0 + 0.8) * rel / (1.0 / m1 + 1.0 / m2)
	velocity = pre + n * (j / m1)
	other.velocity -= n * (j / m2)
	bump_cooldown = 0.2
	other.bump_cooldown = 0.2
	var impact := -rel
	var lighter: Car = self if m1 <= m2 else other
	if impact > CAR_CRASH_SPEED:
		lighter.crash(0.0)
	elif impact > 300.0:
		lighter.spin_out(0.5)
	if impact > 200.0:
		var mid := (global_position + other.global_position) * 0.5
		RaceFX.float_text(race, mid, ["BOING!", "TOING!", "PLAFT!", "CATAPLOFT!"].pick_random(), UIStyle.YELLOW, 38)
		if is_player or other.is_player:
			AudioManager.play_sfx("boing", randf_range(0.9, 1.2))
			race.shake(0.25)
			GameManager.vibrate(40)


func _boing(impact: float) -> void:
	if _boing_cd > 0.0:
		return
	_boing_cd = 0.4
	visual.squash(Vector2(0.8, 1.2))
	if is_player:
		AudioManager.play_sfx("boing", clampf(impact / 300.0, 0.8, 1.4), -4.0)
		race.shake(0.15)


func _update_air(delta: float) -> void:
	if z <= 0.0 and vz <= 0.0:
		return
	vz -= GRAVITY_Z * delta
	z += vz * delta
	air_time_total += delta
	if z <= 0.0:
		z = 0.0
		vz = 0.0
		_set_airborne(false)
		visual.land()
		RaceFX.puff(race, global_position, Color(0.95, 0.88, 0.72, 0.9), 10, 0.6)
		if _flip_jump:
			_flip_jump = false
			flips += 1
			if is_player:
				RaceFX.float_text(race, global_position, "ACROBACIA! +200", UIStyle.TEAL, 40)
		if is_player:
			AudioManager.play_sfx("land")
			race.shake(0.2)


## Lança o carro para o ar (rampas, explosões).
func launch(power: float, flip: bool = false) -> void:
	if z > 0.0:
		vz = maxf(vz, power * 0.6)
		return
	vz = power
	z = 0.1
	_flip_jump = flip
	_set_airborne(true)
	visual.start_air(flip)
	if is_player:
		AudioManager.play_sfx("whoosh", 1.3)


func _set_airborne(on: bool) -> void:
	# no ar: camada "carros_no_ar" (4) e só colide com paredes
	collision_layer = 8 if on else 2
	collision_mask = 1 if on else 3
	z_index = 5 if on else 0


func _update_track_state(delta: float) -> void:
	var q := race.track.query(global_position)
	offroad = q.y > race.track.road_half_width + 8.0
	var length := race.track.length
	var f := q.x / length
	var prev := progress / length
	if f > 0.3 and f < 0.45:
		checkpoints |= 1
	if f > 0.62 and f < 0.78 and (checkpoints & 1) != 0:
		checkpoints |= 2
	if prev > 0.85 and f < 0.15:
		if checkpoints == 3:
			_complete_lap()
		checkpoints = 0
	progress = q.x
	# contramão?
	var dir := race.track.direction_at(progress)
	if velocity.length() > 120.0 and velocity.normalized().dot(dir) < -0.3:
		wrong_way_time += delta
	else:
		wrong_way_time = 0.0


func _complete_lap() -> void:
	if laps_done < 0:
		laps_done = 0
		lap_start = race.race_time
		return
	var lap_time := race.race_time - lap_start
	lap_start = race.race_time
	if best_lap <= 0.0 or lap_time < best_lap:
		best_lap = lap_time
	laps_done += 1
	lap_completed.emit(laps_done, lap_time)
	if laps_done >= race.total_laps and not finished:
		finished = true
		finish_time = race.race_time
		race.on_car_finished(self)
	else:
		race.on_lap(self, laps_done, lap_time)


## Distância total percorrida (para calcular posições).
func race_distance() -> float:
	var length := race.track.length
	var p := progress
	if checkpoints == 0 and p > length * 0.5:
		p -= length
	if laps_done < 0:
		return p - length if p > length * 0.5 else p
	return laps_done * length + p


func current_lap() -> int:
	return clampi(laps_done + 1, 1, race.total_laps)


func _update_stats(delta: float) -> void:
	var kmh := velocity.length() * KMH
	if kmh > top_speed:
		top_speed = kmh
	if kmh >= GameManager.MACH_1_KMH and not reached_mach:
		reached_mach = true
		if is_player:
			race.hud.show_message("MACH 1!", Color(0.6, 0.9, 1.0), 1.2, 72)
	if not finished:
		special_charge = minf(special_charge + delta / data.special_charge_time, 1.0)
	if _item_roll > 0.0:
		_item_roll -= delta
		if _item_roll <= 0.0:
			item = _pending_item
			item_changed.emit(item)


func _update_audio() -> void:
	if _engine == null:
		return
	var ratio := velocity.length() / maxf(data.max_speed, 1.0)
	_engine.pitch_scale = clampf(0.75 + ratio * 1.5 + (0.3 if boost_timer > 0.0 else 0.0) + (0.25 if z > 0.0 else 0.0), 0.5, 3.5)
	_engine.volume_db = lerpf(_engine.volume_db, -8.0 if throttle > 0.0 else -14.0, 0.1)


func _update_skids() -> void:
	var skidding := z <= 0.0 and (drifting or spin_timer > 0.0) and not offroad
	if not skidding:
		if _skid_left != null:
			_fade_skid(_skid_left)
			_fade_skid(_skid_right)
			_skid_left = null
			_skid_right = null
		return
	if _skid_left == null:
		_skid_left = _new_skid()
		_skid_right = _new_skid()
	var back := Vector2(-32, 0).rotated(rotation)
	var side := Vector2(0, 22).rotated(rotation)
	_add_skid_point(_skid_left, global_position + back - side)
	_add_skid_point(_skid_right, global_position + back + side)


func _new_skid() -> Line2D:
	var l := Line2D.new()
	l.width = 9.0
	l.default_color = Color(0.1, 0.1, 0.12, 0.4)
	l.z_index = -10
	race.skids_root.add_child(l)
	return l


func _add_skid_point(l: Line2D, p: Vector2) -> void:
	if l.get_point_count() == 0 or l.get_point_position(l.get_point_count() - 1).distance_to(p) > 10.0:
		l.add_point(p)
	if l.get_point_count() > 90:
		_fade_skid(l)
		if l == _skid_left:
			_skid_left = _new_skid()
		else:
			_skid_right = _new_skid()


func _fade_skid(l: Line2D) -> void:
	if l == null or not is_instance_valid(l):
		return
	var tw := l.create_tween()
	tw.tween_interval(2.5)
	tw.tween_property(l, "modulate:a", 0.0, 2.0)
	tw.tween_callback(l.queue_free)


# ================================================================ itens e especiais

func can_take_item() -> bool:
	return item == "" and _item_roll <= 0.0


func is_rolling_item() -> bool:
	return _item_roll > 0.0


func give_item(id: String) -> void:
	_pending_item = id
	_item_roll = 0.9 if is_player else 0.3
	item_changed.emit("?")


func use_item() -> void:
	if item == "" or not active:
		return
	var id := item
	item = ""
	item_changed.emit("")
	PowerUps.use_item(id, self)


func can_use_special() -> bool:
	return special_charge >= 1.0 and active and not finished


func use_special() -> void:
	if not can_use_special():
		return
	special_charge = 0.0
	PowerUps.use_special(self)


# ================================================================ efeitos recebidos

func is_protected() -> bool:
	return shield_timer > 0.0 or invuln_timer > 0.0


## Rodopio (óleo, banana, vapor...). Retorna true se pegou.
func spin_out(duration: float) -> bool:
	if is_protected() or z > 0.0:
		return false
	spin_timer = maxf(spin_timer, duration)
	_spin_dir = 1.0 if randf() < 0.5 else -1.0
	velocity *= 0.75
	special_charge = minf(special_charge + 0.06, 1.0)
	if is_player:
		AudioManager.play_sfx("spin")
		GameManager.vibrate(60)
	return true


## Batida forte: o carro se desmonta e se remonta. launch_power > 0 também o joga para o ar.
func crash(launch_power: float = 0.0) -> bool:
	if is_protected():
		return false
	crashes += 1
	stun_timer = 0.9
	invuln_timer = 2.0
	velocity *= 0.5
	special_charge = minf(special_charge + 0.12, 1.0)
	visual.disassemble()
	RaceFX.debris(race, global_position, data.body_color)
	if launch_power > 0.0:
		launch(launch_power, false)
	if is_player or race.is_near_player(global_position, 900.0):
		AudioManager.play_sfx("crash", randf_range(0.9, 1.1), 0.0 if is_player else -6.0)
	if is_player:
		race.shake(0.6)
		GameManager.vibrate(120)
	return true


## Choque elétrico (Comte Éclair): lento e tremendo.
func shock(duration: float) -> bool:
	if is_protected():
		return false
	shock_timer = maxf(shock_timer, duration)
	stun_timer = maxf(stun_timer, 0.3)
	if is_player:
		AudioManager.play_sfx("zap")
		GameManager.vibrate(80)
	return true


## Peça caindo na cabeça (chuva de peças).
func bonk() -> bool:
	if is_protected():
		return false
	velocity *= 0.45
	bonk_timer = 1.0
	stun_timer = maxf(stun_timer, 0.3)
	visual.squash(Vector2(1.2, 0.7))
	if is_player or race.is_near_player(global_position, 900.0):
		AudioManager.play_sfx("clank", randf_range(0.8, 1.2))
	return true


## Lentidão (nuvem de vapor).
func apply_slow(mult: float, duration: float) -> void:
	if is_protected():
		return
	slow_mult = minf(slow_mult, mult) if slow_timer > 0.0 else mult
	slow_timer = maxf(slow_timer, duration)


## Turbo. floor_speed força uma velocidade mínima (barreira do som).
func apply_boost(mult: float, duration: float, floor_speed: float = 0.0) -> void:
	boost_mult = maxf(boost_mult, mult) if boost_timer > 0.0 else mult
	boost_floor = maxf(boost_floor, floor_speed) if boost_timer > 0.0 else floor_speed
	boost_timer = maxf(boost_timer, duration)
	velocity += Vector2.RIGHT.rotated(rotation) * 160.0
	visual.squash(Vector2(1.25, 0.85))


func push(impulse: Vector2) -> void:
	velocity += impulse


func teleport_to(pos: Vector2, rot: float) -> void:
	var speed := maxf(velocity.length(), 300.0)
	global_position = pos
	rotation = rot
	velocity = Vector2.RIGHT.rotated(rot) * speed


func get_stats() -> Dictionary:
	return {
		"id": data.id,
		"position": position_rank,
		"time": finish_time,
		"best_lap": best_lap,
		"top_speed": top_speed,
		"air_time": air_time_total,
		"hits": hits_given,
		"flips": flips,
		"crashes": crashes,
		"mach": reached_mach,
	}
