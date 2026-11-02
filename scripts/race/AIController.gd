class_name AIController
extends RefCounted
## PILOTO DA IA: segue a curva da pista olhando à frente, escolhe uma "faixa" que muda
## de tempos em tempos, freia em curvas fechadas, se desatola sozinho e usa itens/especiais.
## "skill" (0.85..1.05) e o rubber band deixam a corrida disputada.

var car: Car
var skill := 1.0
var lane := 0.0
var _lane_timer := 0.0
var _stuck_time := 0.0
var _reverse_time := 0.0
var _item_delay := 0.0
var _special_delay := 0.0
var _rng := RandomNumberGenerator.new()


func _init(p_car: Car, p_skill: float = 1.0) -> void:
	car = p_car
	skill = p_skill
	_rng.randomize()
	lane = _rng.randf_range(-90.0, 90.0)
	_special_delay = _rng.randf_range(1.0, 4.0)


func update(delta: float) -> void:
	if not car.active:
		car.throttle = 0.0
		return
	var track := car.race.track
	var speed := car.velocity.length()

	# troca de faixa ocasional (deixa a corrida mais orgânica)
	_lane_timer -= delta
	if _lane_timer <= 0.0:
		_lane_timer = _rng.randf_range(2.0, 4.5)
		lane = clampf(lane + _rng.randf_range(-80.0, 80.0), -110.0, 110.0)

	var look := 230.0 + speed * 0.35
	var target := track.sample(car.progress + look, lane)
	var to := target - car.global_position
	var ang := wrapf(to.angle() - car.rotation, -PI, PI)
	car.steer = clampf(ang * 2.4, -1.0, 1.0)

	# curva fechada à frente? alivia / freia
	var turn := absf(track.turn_between(car.progress + 100.0, car.progress + 100.0 + look * 1.6))
	car.throttle = 1.0
	car.brake = 0.0
	if turn > 1.0 and speed > car.data.max_speed * 0.72:
		car.throttle = 0.0
		car.brake = 0.5
	elif turn > 0.6 and speed > car.data.max_speed * 0.85:
		car.throttle = 0.4
	if absf(ang) > 1.2 and speed > 300.0:
		car.throttle = 0.0
		car.brake = 0.6

	_unstick(delta, speed)
	_rubber_band()
	_use_items(delta)


func _unstick(delta: float, speed: float) -> void:
	if _reverse_time > 0.0:
		_reverse_time -= delta
		car.throttle = 0.0
		car.brake = 1.0
		car.steer = -car.steer
		return
	if speed < 60.0 and car.can_drive() and car.z <= 0.0:
		_stuck_time += delta
		if _stuck_time > 1.3:
			_stuck_time = 0.0
			_reverse_time = 0.8
	else:
		_stuck_time = 0.0


## Mantém a disputa: quem está muito na frente do jogador alivia, quem está atrás aperta.
func _rubber_band() -> void:
	var player := car.race.player
	if player == null or player == car:
		car.speed_scale = skill
		return
	var diff := player.race_distance() - car.race_distance()
	var k := clampf(diff / 1500.0, -1.0, 1.0)
	car.speed_scale = skill * (1.0 + k * (0.1 if k > 0.0 else 0.08))


func _use_items(delta: float) -> void:
	if car.item != "":
		_item_delay -= delta
		if _item_delay <= 0.0:
			var use := true
			if car.item == "oil" or car.item == "banana":
				use = car.position_rank > 1 or _rng.randf() < 0.5
			elif car.item == "barrier":
				use = absf(car.steer) < 0.25
			if use:
				car.use_item()
			_item_delay = _rng.randf_range(1.0, 3.0)
	else:
		_item_delay = _rng.randf_range(0.8, 2.5)
	if car.can_use_special():
		_special_delay -= delta
		if _special_delay <= 0.0:
			_special_delay = _rng.randf_range(2.0, 6.0)
			car.use_special()
