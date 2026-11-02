extends Node
## Gera screenshots de todas as telas (útil para revisar visual / README).
## Rodar (precisa de vídeo; no Linux sem tela use xvfb-run):
##   godot --path . res://tests/Screenshots.tscn -- --out=/caminho/da/pasta
## Sem --out, salva em user://screenshots.

var out_dir := "user://screenshots"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)
	await _scene("res://scenes/Intro.tscn", [[2.6, "01_intro_texto"], [5.3, "02_intro_montagem"], [9.9, "03_intro_cartoon"], [12.0, "04_intro_boom"], [15.4, "05_intro_titulo"]])
	await _scene("res://scenes/MainMenu.tscn", [[1.2, "06_menu"], [1.5, "07_opcoes", "_on_options"]])
	GameManager.select_mode = "play"
	await _scene("res://scenes/CharacterSelect.tscn", [[1.0, "08_selecao"]])
	await _race()
	GameManager.last_results = {}
	await _scene("res://scenes/Results.tscn", [[3.5, "13_resultado"]])
	print("[shots] pronto: ", ProjectSettings.globalize_path(out_dir))
	get_tree().quit()


func _scene(path: String, shots: Array) -> void:
	# s[0] = segundos desde que a cena abriu (tempo absoluto)
	var node := (load(path) as PackedScene).instantiate()
	add_child(node)
	var elapsed := 0.0
	for s in shots:
		if s.size() > 2:
			node.call(s[2])
		var wait := maxf(float(s[0]) - elapsed, 0.05)
		await get_tree().create_timer(wait).timeout
		elapsed += wait
		await _save(s[1])
	node.queue_free()
	await get_tree().process_frame


func _race() -> void:
	var race := (load("res://scenes/Race.tscn") as PackedScene).instantiate() as RaceController
	add_child(race)
	await get_tree().process_frame
	race.player.controller = AIController.new(race.player, 1.0)
	await get_tree().create_timer(1.6).timeout
	await _save("09_corrida_largada")
	await get_tree().create_timer(7.0).timeout
	await _save("10_corrida")
	race.player.give_item("barrier")
	await get_tree().create_timer(1.2).timeout
	race.player.use_item()
	await get_tree().create_timer(0.35).timeout
	await _save("11_corrida_barreira_do_som")
	race.toggle_pause()
	await get_tree().create_timer(0.3).timeout
	await _save("12_pausa")
	get_tree().paused = false
	race.set_physics_process(false)
	race.queue_free()
	await get_tree().process_frame


func _save(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(file_name + ".png"))
	print("[shots] ", file_name)
