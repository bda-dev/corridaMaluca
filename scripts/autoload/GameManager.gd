extends Node
## GameManager (autoload) — estado global do jogo.
##  * elenco de personagens e piloto escolhido
##  * configurações (volume, giroscópio, botões na tela...) e recordes, salvos em user://
##  * troca de cenas com transição (fade)
##  * cálculo de pontuação e registro de recordes ao fim de cada corrida

signal settings_changed

const SAVE_PATH := "user://corrida_maluca_save.cfg"

const SCENES := {
	"intro": "res://scenes/Intro.tscn",
	"menu": "res://scenes/MainMenu.tscn",
	"select": "res://scenes/CharacterSelect.tscn",
	"race": "res://scenes/Race.tscn",
	"results": "res://scenes/Results.tscn",
}

## Elenco jogável. Para adicionar um piloto, crie o .tres e coloque o caminho aqui.
const ROSTER_PATHS: Array[String] = [
	"res://data/characters/comte_eclair.tres",
	"res://data/characters/lady_nitro.tres",
	"res://data/characters/capitao_foguete.tres",
	"res://data/characters/doutor_thrust.tres",
	"res://data/characters/ze_vapor.tres",
]

## Carros históricos ainda sem piloto: aparecem como "EM BREVE" na seleção (expansão futura).
const LOCKED_CARS := [
	{"car_name": "Blue Bird", "car_year": 1935, "car_record_kmh": 484.62, "car_shape": "blue_bird"},
]

## Montagem da intro: os 6 carros históricos de recorde em ordem cronológica.
const HISTORIC_CARS := [
	{"name": "Jeantaud Duc", "year": "1898", "kmh": "63 km/h", "shape": "jeantaud"},
	{"name": "La Jamais Contente", "year": "1899", "kmh": "105 km/h", "shape": "jamais_contente"},
	{"name": "Golden Arrow", "year": "1929", "kmh": "372 km/h", "shape": "golden_arrow"},
	{"name": "Blue Bird", "year": "1935", "kmh": "484 km/h", "shape": "blue_bird"},
	{"name": "Spirit of America", "year": "1965", "kmh": "966 km/h", "shape": "spirit_of_america"},
	{"name": "ThrustSSC", "year": "1997", "kmh": "1.228 km/h", "shape": "thrust_ssc"},
]

const TOTAL_LAPS := 3
const POSITION_POINTS: Array[int] = [1500, 1000, 700, 450, 250]
const MACH_1_KMH := 1235.0

var roster: Array[CharacterData] = []
var selected_id := "comte_eclair"
## "play" = escolher e correr | "gallery" = só ver os personagens (menu Personagens)
var select_mode := "play"
var track_id := "salar_do_vento"
var track_name := "Salar do Vento Maluco"

var settings := {
	"music_volume": 0.55,
	"sfx_volume": 0.9,
	"gyro_enabled": false,
	"gyro_invert": false,
	"gyro_sensitivity": 1.0,
	"show_buttons": true,
	"rotate_camera": true,
	"vibration": true,
	"show_tutorial": true,
}

## records[track_id] = {best_time, best_lap, top_speed, best_score, wins, races}
var records := {}
## Preenchido pela corrida e lido pela tela de resultado.
var last_results := {}
var intro_seen := false

var _fade_rect: ColorRect
var _rotate_hint: Control
var _changing := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_roster()
	_register_input_actions()
	load_game()
	apply_settings()
	var theme := UIStyle.build_theme()
	get_tree().root.theme = theme
	# mescla no tema padrão: vale também para cenas instanciadas sob nós que não são Control
	ThemeDB.get_default_theme().merge_with(theme)
	_build_fade_layer()


# ---------------------------------------------------------------- personagens

func _load_roster() -> void:
	roster.clear()
	for path in ROSTER_PATHS:
		var res := load(path) as CharacterData
		if res != null:
			roster.append(res)
		else:
			push_warning("Personagem não encontrado: %s" % path)


func get_character(char_id: String) -> CharacterData:
	for c in roster:
		if c.id == char_id:
			return c
	return roster[0] if roster.size() > 0 else null


func selected_character() -> CharacterData:
	return get_character(selected_id)


# ---------------------------------------------------------------- cenas

## Troca de cena com fade. scene_key: "intro", "menu", "select", "race", "results".
func go_to(scene_key: String) -> void:
	if _changing:
		return
	_changing = true
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(_fade_rect, "color:a", 1.0, 0.22)
	await tw.finished
	get_tree().paused = false
	get_tree().change_scene_to_file(SCENES[scene_key])
	await get_tree().process_frame
	await get_tree().process_frame
	var tw2 := create_tween()
	tw2.tween_property(_fade_rect, "color:a", 0.0, 0.3)
	await tw2.finished
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_changing = false


func _build_fade_layer() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(UIStyle.BG, 0.0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_fade_rect)
	_build_rotate_hint()


## Aviso "gire o celular" quando a tela está em pé (acontece no navegador; o APK é travado
## em paisagem). Bloqueia toques até girar.
func _build_rotate_hint() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 99
	add_child(layer)
	_rotate_hint = ColorRect.new()
	(_rotate_hint as ColorRect).color = Color(UIStyle.BG, 0.96)
	_rotate_hint.mouse_filter = Control.MOUSE_FILTER_STOP
	_rotate_hint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_rotate_hint)
	var msg := UIStyle.make_label("GIRE O CELULAR\npara jogar deitado", 64, UIStyle.YELLOW, 14, HORIZONTAL_ALIGNMENT_CENTER, true)
	msg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rotate_hint.add_child(msg)
	get_viewport().size_changed.connect(_update_rotate_hint)
	_update_rotate_hint()


func _update_rotate_hint() -> void:
	var s := get_viewport().get_visible_rect().size
	_rotate_hint.visible = s.y > s.x * 1.05


## Navegador do celular: tela cheia + trava em paisagem (precisa de um toque do jogador;
## falhas são ignoradas — ex.: iPhone não deixa o Safari travar a orientação).
func request_mobile_web_fullscreen() -> void:
	if not (OS.has_feature("web") and is_mobile()):
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	JavaScriptBridge.eval("try { screen.orientation.lock('landscape').catch(function(){}); } catch (e) {}", true)


# ---------------------------------------------------------------- configurações

func set_setting(key: String, value: Variant) -> void:
	settings[key] = value
	apply_settings()
	save_game()
	settings_changed.emit()


func apply_settings() -> void:
	AudioManager.set_bus_volume("Music", float(settings["music_volume"]))
	AudioManager.set_bus_volume("SFX", float(settings["sfx_volume"]))


func is_mobile() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")


## Vibração curta (respeita a opção do jogador; só tem efeito em celular).
func vibrate(ms: int) -> void:
	if bool(settings["vibration"]) and is_mobile():
		Input.vibrate_handheld(ms)


## Teclado / controle para testar no PC (no celular usa-se o toque — ver TouchInput.gd).
func _register_input_actions() -> void:
	_add_keys("accelerate", [KEY_W, KEY_UP])
	_add_keys("brake", [KEY_S, KEY_DOWN])
	_add_keys("steer_left", [KEY_A, KEY_LEFT])
	_add_keys("steer_right", [KEY_D, KEY_RIGHT])
	_add_keys("use_item", [KEY_SPACE, KEY_E])
	_add_keys("use_special", [KEY_SHIFT, KEY_Q])
	_add_keys("pause", [KEY_ESCAPE, KEY_P])
	_add_joy_button("use_item", JOY_BUTTON_A)
	_add_joy_button("use_special", JOY_BUTTON_Y)
	_add_joy_button("brake", JOY_BUTTON_B)
	_add_joy_button("pause", JOY_BUTTON_START)
	_add_joy_axis("accelerate", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_add_joy_axis("brake", JOY_AXIS_TRIGGER_LEFT, 1.0)
	_add_joy_axis("steer_left", JOY_AXIS_LEFT_X, -1.0)
	_add_joy_axis("steer_right", JOY_AXIS_LEFT_X, 1.0)


func _ensure_action(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.25)


func _add_keys(action: String, keys: Array) -> void:
	_ensure_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)


func _add_joy_button(action: String, button: JoyButton) -> void:
	_ensure_action(action)
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


func _add_joy_axis(action: String, axis: JoyAxis, value: float) -> void:
	_ensure_action(action)
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	InputMap.action_add_event(action, ev)


# ---------------------------------------------------------------- recordes e pontuação

func get_record(for_track: String) -> Dictionary:
	if not records.has(for_track):
		records[for_track] = {"best_time": 0.0, "best_lap": 0.0, "top_speed": 0.0, "best_score": 0, "wins": 0, "races": 0}
	return records[for_track]


## Linhas da pontuação: [[rótulo, pontos], ...] + total. stats vem de Car.get_stats().
func compute_score(stats: Dictionary) -> Dictionary:
	var pos: int = stats["position"]
	var lines := []
	lines.append(["Posição final (%dº)" % pos, POSITION_POINTS[clampi(pos - 1, 0, POSITION_POINTS.size() - 1)]])
	lines.append(["Velocidade máxima", int(stats["top_speed"])])
	lines.append(["Tempo no ar", int(float(stats["air_time"]) * 120.0)])
	lines.append(["Itens certeiros", int(stats["hits"]) * 150])
	lines.append(["Acrobacias", int(stats["flips"]) * 200])
	lines.append(["Bônus Destruição", int(stats["crashes"]) * 60])
	if bool(stats["mach"]):
		lines.append(["Barreira do som!", 500])
	var total := 0
	for l in lines:
		total += int(l[1])
	return {"lines": lines, "total": total}


## Chamado pela corrida no fim: calcula pontos, atualiza recordes e salva.
func finalize_race(result: Dictionary) -> void:
	var rec := get_record(track_id)
	var stats: Dictionary = result["player"]
	var score := compute_score(stats)
	var new_records: Array[String] = []
	rec["races"] = int(rec["races"]) + 1
	if int(stats["position"]) == 1:
		rec["wins"] = int(rec["wins"]) + 1
	var t: float = stats["time"]
	if t > 0.0 and (float(rec["best_time"]) <= 0.0 or t < float(rec["best_time"])):
		rec["best_time"] = t
		new_records.append("best_time")
	var lap: float = stats["best_lap"]
	if lap > 0.0 and (float(rec["best_lap"]) <= 0.0 or lap < float(rec["best_lap"])):
		rec["best_lap"] = lap
		new_records.append("best_lap")
	if float(stats["top_speed"]) > float(rec["top_speed"]):
		rec["top_speed"] = float(stats["top_speed"])
		new_records.append("top_speed")
	if int(score["total"]) > int(rec["best_score"]):
		rec["best_score"] = int(score["total"])
		new_records.append("best_score")
	result["score"] = score
	result["new_records"] = new_records
	last_results = result
	save_game()


## Recorde de velocidade atual da pista (usado na HUD durante a corrida).
func track_top_speed() -> float:
	return float(get_record(track_id)["top_speed"])


func reset_records() -> void:
	records.clear()
	save_game()


static func format_time(t: float) -> String:
	if t <= 0.0:
		return "--:--.--"
	var m := int(t / 60.0)
	var s := fmod(t, 60.0)
	return "%d:%05.2f" % [m, s]


# ---------------------------------------------------------------- salvar / carregar

func save_game() -> void:
	var cf := ConfigFile.new()
	for k in settings:
		cf.set_value("settings", k, settings[k])
	for t in records:
		cf.set_value("records", t, records[t])
	cf.set_value("progress", "selected_id", selected_id)
	cf.set_value("progress", "intro_seen", intro_seen)
	cf.save(SAVE_PATH)


func load_game() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) != OK:
		return
	for k in settings.keys():
		settings[k] = cf.get_value("settings", k, settings[k])
	if cf.has_section("records"):
		for t in cf.get_section_keys("records"):
			records[t] = cf.get_value("records", t, {})
	selected_id = cf.get_value("progress", "selected_id", selected_id)
	intro_seen = cf.get_value("progress", "intro_seen", false)
