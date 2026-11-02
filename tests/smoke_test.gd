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


func _ready() -> void:
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
	_race.player.controller = AIController.new(_race.player, 1.0)
	Engine.time_scale = TIME_SCALE
	print("[smoke] corrida iniciada: %s, %.0f px por volta" % [_race.track.track_name, _race.track.length])


func _process(delta: float) -> void:
	if _race == null:
		return
	_elapsed += delta
	if _race.state == RaceController.State.FINISHED:
		_report("CHEGADA")
		get_tree().quit(0)
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
