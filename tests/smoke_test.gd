extends Node
## TESTE DE FUMAÇA (sem interação): abre cada tela, depois roda uma corrida completa com
## o carro do jogador no piloto automático e imprime o resultado.
##
## Rodar:   godot --headless --path . res://tests/SmokeTest.tscn
## (ou abra tests/SmokeTest.tscn no editor e aperte F6)
## Sai com código 0 se a corrida terminar, 1 se der timeout.

const SCREENS: Array[String] = [
	"res://scenes/Intro.tscn",
	"res://scenes/MainMenu.tscn",
	"res://scenes/CharacterSelect.tscn",
	"res://scenes/Results.tscn",
]
const TIME_SCALE := 2.0
const TIMEOUT := 400.0

var _race: RaceController
var _elapsed := 0.0
var _failures := 0
var _item_signal := false
var _special_signal := false


func _ready() -> void:
	await _test_intro_skip()
	for path in SCREENS:
		var scene := load(path) as PackedScene
		assert(scene != null, "não carregou: " + path)
		var node := scene.instantiate()
		add_child(node)
		for i in 20:
			await get_tree().process_frame
		node.queue_free()
		await get_tree().process_frame
		print("[smoke] OK  ", path)
	for c in GameManager.roster:
		print("[smoke] piloto: %s (%s)" % [c.display_name, c.car_name])
	_race = (load("res://scenes/Race.tscn") as PackedScene).instantiate() as RaceController
	add_child(_race)
	await get_tree().process_frame
	await _test_race_touch()
	_race.player.controller = AIController.new(_race.player, 1.0)
	Engine.time_scale = TIME_SCALE
	print("[smoke] corrida iniciada: %s, %.0f px por volta" % [_race.track.track_name, _race.track.length])


func _process(delta: float) -> void:
	if _race == null:
		return
	_elapsed += delta
	if _race.state == RaceController.State.FINISHED:
		_report("CHEGADA")
		get_tree().quit(1 if _failures > 0 else 0)
	elif _elapsed > TIMEOUT:
		_report("TIMEOUT")
		get_tree().quit(1)


func _report(label: String) -> void:
	Engine.time_scale = 1.0
	print("[smoke] %s em %.1f s de corrida" % [label, _race.race_time])
	var sorted: Array[Car] = _race.cars.duplicate()
	sorted.sort_custom(func(a: Car, b: Car) -> bool: return a.position_rank < b.position_rank)
	for c in sorted:
		print("[smoke]  %dº %-16s voltas=%d  vmax=%4d km/h  batidas=%d  acertos=%d  no_ar=%.1fs%s" % [
			c.position_rank, c.data.display_name, maxi(c.laps_done, 0), int(c.top_speed), c.crashes,
			c.hits_given, c.air_time_total, "  <- jogador" if c.is_player else ""])


# ---------------------------------------------------------------- toques simulados

func _check(ok: bool, what: String) -> void:
	print("[smoke] %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		_failures += 1


## parse_input_event recebe coordenadas da JANELA; os testes pensam em coordenadas do viewport.
func _to_window(pos: Vector2) -> Vector2:
	return get_tree().root.get_final_transform() * pos


func _touch(index: int, pos: Vector2, pressed: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = index
	ev.position = _to_window(pos)
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _drag(index: int, pos: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = index
	ev.position = _to_window(pos)
	Input.parse_input_event(ev)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _test_intro_skip() -> void:
	var intro := (load("res://scenes/Intro.tscn") as PackedScene).instantiate()
	add_child(intro)
	await _frames(10)
	_touch(0, Vector2(640, 360), true)
	_touch(0, Vector2(640, 360), false)
	await _frames(3)
	_check(float(intro.get("t")) >= float(intro.get("T_PROMPT")), "toque pula a intro direto para o título")
	intro.queue_free()
	await get_tree().process_frame


func _test_race_touch() -> void:
	var touch := _race.touch
	var player := _race.player
	touch.item_pressed.connect(func() -> void: _item_signal = true)
	touch.special_pressed.connect(func() -> void: _special_signal = true)
	# segurar = acelerar
	_touch(0, Vector2(560, 300), true)
	await _frames(3)
	_check(touch.drive_active and player.throttle > 0.0, "segurar a tela acelera (throttle=%.1f)" % player.throttle)
	# arrastar para a direita = virar à direita
	_drag(0, Vector2(660, 300))
	await _frames(3)
	_check(touch.steer_value > 0.5 and player.steer > 0.5, "arrastar à direita vira (steer=%.2f)" % player.steer)
	_drag(0, Vector2(460, 300))
	await _frames(3)
	_check(player.steer < -0.5, "arrastar à esquerda vira (steer=%.2f)" % player.steer)
	_touch(0, Vector2(460, 300), false)
	await _frames(3)
	_check(not touch.drive_active and player.throttle == 0.0, "soltar o dedo para de acelerar")
	# botão de item (multi-toque: segurando a tela com outro dedo)
	_touch(0, Vector2(560, 300), true)
	var item_pos: Vector2 = _race.hud.get("_buttons")["item"].center_global()
	_touch(1, item_pos, true)
	_touch(1, item_pos, false)
	await _frames(2)
	_check(_item_signal and touch.drive_active, "botão ITEM com outro dedo segurando")
	_touch(0, Vector2(560, 300), false)
	# freio
	var brake_pos: Vector2 = _race.hud.get("_buttons")["brake"].center_global()
	_touch(2, brake_pos, true)
	await _frames(3)
	_check(player.brake > 0.0, "botão FREIO")
	_touch(2, brake_pos, false)
	await _frames(25)
	# toque duplo = especial
	_touch(0, Vector2(700, 250), true)
	_touch(0, Vector2(700, 250), false)
	await _frames(4)
	_touch(0, Vector2(705, 252), true)
	_touch(0, Vector2(705, 252), false)
	await _frames(2)
	_check(_special_signal, "toque duplo dispara o especial")
