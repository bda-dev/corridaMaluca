class_name RaceController
extends Node2D
## CONTROLADOR DA CORRIDA (Race.tscn): monta o grid, faz a contagem regressiva,
## calcula posições, distribui itens, cria projéteis/armadilhas e encerra a corrida.
##
## Árvore esperada (Race.tscn):
##   Race
##    ├─ World
##    │   ├─ Track (instância de uma pista, ex.: tracks/SalarDoVento.tscn)
##    │   ├─ Skids, Hazards, Cars, FX   (Node2D vazios)
##    ├─ RaceCamera
##    ├─ HUD (CanvasLayer + RaceHUD.gd)
##    ├─ TouchInput
##    └─ PauseMenu (CanvasLayer + PauseMenu.gd)

enum State { COUNTDOWN, RACING, FINISHED }

const CAR_SCENE := preload("res://scenes/race/Car.tscn")
const COUNTDOWN_TIME := 3.6
const PLAYER_GRID_SLOT := 3
const END_DELAY := 4.5

@export var total_laps := 3

@onready var track: Track = $World/Track
@onready var skids_root: Node2D = $World/Skids
@onready var hazards_root: Node2D = $World/Hazards
@onready var cars_root: Node2D = $World/Cars
@onready var fx_root: Node2D = $World/FX
@onready var camera: RaceCamera = $RaceCamera
@onready var hud: RaceHUD = $HUD
@onready var touch: TouchInput = $TouchInput
@onready var pause_menu: PauseMenu = $PauseMenu

var state := State.COUNTDOWN
var race_time := 0.0
var cars: Array[Car] = []
var player: Car
var finish_order: Array[Car] = []

var _countdown := COUNTDOWN_TIME
var _last_count := 99
var _throttle_since := -1.0
var _end_timer := 0.0
var _final_lap_announced := false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	total_laps = GameManager.TOTAL_LAPS
	GameManager.track_id = track.track_id
	GameManager.track_name = track.track_name
	_spawn_cars()
	camera.target = player
	camera.snap()
	touch.hud = hud
	touch.item_pressed.connect(func() -> void: player.use_item())
	touch.special_pressed.connect(func() -> void: player.use_special())
	touch.pause_pressed.connect(toggle_pause)
	hud.setup(self)
	hud.show_tutorial(true)
	pause_menu.race = self
	AudioManager.play_music("race")


func _spawn_cars() -> void:
	var chosen := GameManager.selected_character()
	var others: Array[CharacterData] = []
	for c in GameManager.roster:
		if c != chosen:
			others.append(c)
	others.shuffle()
	var lineup: Array[CharacterData] = []
	lineup.append_array(others)
	lineup.insert(mini(PLAYER_GRID_SLOT, lineup.size()), chosen)
	for i in lineup.size():
		var row := int(i / 2.0)
		var lat := -75.0 if i % 2 == 0 else 75.0
		if i == lineup.size() - 1 and i % 2 == 0:
			lat = 0.0
		var off := track.length - 120.0 - row * 150.0
		var car := CAR_SCENE.instantiate() as Car
		cars_root.add_child(car)
		var is_player := lineup[i] == chosen
		car.setup(lineup[i], self, is_player)
		car.place_on_grid(off, lat)
		if is_player:
			player = car
			car.controller = PlayerController.new(car, touch)
		else:
			car.controller = AIController.new(car, _rng.randf_range(0.9, 1.02))
		cars.append(car)
	_update_positions()


func _physics_process(delta: float) -> void:
	match state:
		State.COUNTDOWN:
			_tick_countdown(delta)
		State.RACING, State.FINISHED:
			race_time += delta
			_update_positions()
			if state == State.FINISHED:
				_end_timer -= delta
				if _end_timer <= 0.0:
					_go_to_results()


func _tick_countdown(delta: float) -> void:
	_countdown -= delta
	var n := ceili(_countdown)
	if n != _last_count and n <= 3:
		_last_count = n
		if n > 0:
			hud.show_countdown(n)
			AudioManager.play_sfx("count")
	# "largada turbo": acelere só depois que aparecer o "1"
	if player.throttle > 0.0 and _throttle_since < 0.0:
		_throttle_since = _countdown
	elif player.throttle <= 0.0:
		_throttle_since = -1.0
	if _countdown <= 0.0:
		_start_race()


func _start_race() -> void:
	state = State.RACING
	hud.show_countdown(0)
	AudioManager.play_sfx("go")
	for c in cars:
		c.active = true
		if not c.is_player and _rng.randf() < 0.3:
			c.apply_boost(1.3, 0.9)
	if player.throttle > 0.0:
		if _throttle_since >= 0.0 and _throttle_since <= 1.0:
			player.apply_boost(1.45, 1.3)
			RaceFX.float_text(self, player.global_position, "LARGADA TURBO!", UIStyle.TEAL, 40)
			AudioManager.play_sfx("boost")
		elif _throttle_since > 2.0:
			player.stun_timer = 0.8
			RaceFX.puff(self, player.global_position, Color(0.3, 0.3, 0.35, 0.9), 16, 0.8)
			RaceFX.float_text(self, player.global_position, "ENGASGOU!", UIStyle.RED, 40)
			AudioManager.play_sfx("ops")
	get_tree().create_timer(2.5, false).timeout.connect(hud.show_tutorial.bind(false))


func is_racing() -> bool:
	return state != State.COUNTDOWN


# ---------------------------------------------------------------- posições

func _update_positions() -> void:
	var sorted: Array[Car] = cars.duplicate()
	sorted.sort_custom(_compare_cars)
	for i in sorted.size():
		sorted[i].position_rank = i + 1


func _compare_cars(a: Car, b: Car) -> bool:
	if a.finished and b.finished:
		return a.finish_time < b.finish_time
	if a.finished != b.finished:
		return a.finished
	return a.race_distance() > b.race_distance()


func car_ahead_of(car: Car) -> Car:
	for c in cars:
		if c.position_rank == car.position_rank - 1:
			return c
	return null


func cars_near(pos: Vector2, radius: float, exclude: Car = null) -> Array[Car]:
	var out: Array[Car] = []
	for c in cars:
		if c != exclude and c.global_position.distance_to(pos) <= radius:
			out.append(c)
	return out


func is_near_player(pos: Vector2, radius: float) -> bool:
	return player != null and player.global_position.distance_to(pos) <= radius


# ---------------------------------------------------------------- itens

## Sorteio do item da caixa: quem está mais atrás ganha itens mais fortes.
func roll_item(car: Car) -> String:
	var ratio := float(car.position_rank - 1) / maxf(float(cars.size() - 1), 1.0)
	return PowerUps.roll(ratio, _rng)


func spawn_hazard(kind: String, pos: Vector2, owner_car: Car) -> void:
	var h := Hazard.new()
	h.setup(kind, owner_car)
	h.position = pos
	h.rotation = randf() * TAU
	hazards_root.add_child(h)


func spawn_rocket(owner_car: Car) -> void:
	var r := Rocket.new()
	r.setup(owner_car, car_ahead_of(owner_car))
	fx_root.add_child(r)


func spawn_parts_rain(owner_car: Car) -> void:
	for c in cars:
		if c == owner_car or c.finished:
			continue
		for k in 5:
			var p := FallingPart.new()
			p.setup(owner_car, c, 0.15 + k * 0.35 + _rng.randf() * 0.2)
			fx_root.add_child(p)
	if owner_car.is_player:
		RaceFX.float_text(self, owner_car.global_position, "OLHA PRO CÉU!", UIStyle.CREAM, 36)


## Barreira do som: BOOM empurra e faz rodar quem estiver perto.
func sonic_boom(car: Car) -> void:
	RaceFX.ring(self, car.global_position, 380.0, Color.WHITE, 0.6, 30.0)
	RaceFX.ring(self, car.global_position, 260.0, Color(0.6, 0.9, 1.0), 0.45, 18.0)
	RaceFX.float_text(self, car.global_position, "BOOM!", Color(0.6, 0.9, 1.0), 64)
	for c in cars_near(car.global_position, 340.0, car):
		var away := (c.global_position - car.global_position).normalized()
		c.push(away * 520.0)
		if c.spin_out(0.8):
			car.hits_given += 1
	if is_near_player(car.global_position, 1200.0):
		AudioManager.play_sfx("boom", 1.0, -2.0)
		shake(0.7 if car.is_player else 0.35)
	if car.is_player:
		GameManager.vibrate(150)


func shake(amount: float) -> void:
	camera.add_trauma(amount)


# ---------------------------------------------------------------- voltas e chegada

func on_lap(car: Car, lap: int, _lap_time: float) -> void:
	if car != player:
		return
	AudioManager.play_sfx("lap")
	if lap == total_laps - 1 and not _final_lap_announced:
		_final_lap_announced = true
		hud.show_message("VOLTA FINAL!", UIStyle.ORANGE, 1.4, 70)
	else:
		hud.show_message("VOLTA %d/%d" % [lap + 1, total_laps], UIStyle.CREAM, 0.9, 54)


func on_car_finished(car: Car) -> void:
	finish_order.append(car)
	_update_positions()
	if car == player:
		state = State.FINISHED
		_end_timer = END_DELAY
		var pos := player.position_rank
		var msg := "VITÓRIA!" if pos == 1 else "%dº LUGAR!" % pos
		hud.show_message(msg, UIStyle.YELLOW if pos == 1 else UIStyle.CREAM, 2.5, 84)
		AudioManager.play_sfx("finish")
		# piloto automático na volta da vitória
		player.controller = AIController.new(player, 0.9)
	elif state == State.RACING:
		hud.show_message("%s cruzou a chegada!" % car.data.display_name, UIStyle.CREAM, 0.8, 30)


func _go_to_results() -> void:
	set_physics_process(false)
	_update_positions()
	var sorted: Array[Car] = cars.duplicate()
	sorted.sort_custom(func(a: Car, b: Car) -> bool: return a.position_rank < b.position_rank)
	var standings := []
	var last_time := 0.0
	for c in sorted:
		var t := c.finish_time if c.finished else _estimate_finish(c)
		t = maxf(t, last_time + 0.4)
		last_time = t
		standings.append({
			"id": c.data.id,
			"name": c.data.display_name,
			"car": c.data.car_name,
			"time": t,
			"best_lap": c.best_lap,
			"is_player": c == player,
			"finished": c.finished,
		})
	var result := {
		"track_id": track.track_id,
		"track_name": track.track_name,
		"laps": total_laps,
		"standings": standings,
		"player": player.get_stats(),
	}
	GameManager.finalize_race(result)
	GameManager.go_to("results")


## Tempo estimado para quem ainda não terminou (velocidade média até agora).
func _estimate_finish(c: Car) -> float:
	var total := total_laps * track.length
	var done := maxf(c.race_distance(), 1.0)
	var avg := maxf(done / maxf(race_time, 1.0), 250.0)
	return race_time + maxf(total - done, 0.0) / avg


# ---------------------------------------------------------------- pausa

func toggle_pause() -> void:
	if get_tree().paused:
		pause_menu.close()
	else:
		get_tree().paused = true
		touch.reset()
		pause_menu.open()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		toggle_pause()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		toggle_pause()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT and state == State.RACING and not get_tree().paused:
		toggle_pause()
