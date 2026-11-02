extends Node
## AssetLib (autoload) — PONTO ÚNICO para trocar placeholders por assets reais.
##
## Todo o jogo pede assets por uma CHAVE lógica (ex.: "car_top_ze_vapor").
## O AssetLib procura o arquivo nesta ordem:
##   1) res://assets/custom/<caminho>.<ext>   (arte própria do projeto — prioridade)
##   2) res://assets/kenney/<caminho>.<ext>   (packs gratuitos CC0 do Kenney.nl)
## Se nada existir, devolve null e o jogo desenha um PLACEHOLDER procedural
## (formas coloridas + texto). Ou seja: o jogo roda 100% sem nenhum asset baixado.
##
## >>> COMO TROCAR UM PLACEHOLDER <<<
## Copie o PNG/OGG do pack Kenney para o caminho da tabela abaixo (renomeando).
## Ex.: Racing Pack "PNG/Cars/car_green_2.png" -> res://assets/kenney/cars/car_ze_vapor.png
## Veja docs/ASSETS_KENNEY.md para a lista completa de sugestões.

const KENNEY := "res://assets/kenney/"
const CUSTOM := "res://assets/custom/"
const IMG_EXT: Array[String] = ["png", "webp", "svg", "jpg"]
const AUDIO_EXT: Array[String] = ["ogg", "wav", "mp3"]

## Chave lógica -> caminho relativo (sem extensão) dentro de assets/kenney ou assets/custom.
const TEXTURE_PATHS := {
	# --- Carros vistos de CIMA (Racing Pack -> PNG/Cars). A arte deve apontar para CIMA. ---
	"car_top_comte_eclair": "cars/car_comte_eclair",
	"car_top_lady_nitro": "cars/car_lady_nitro",
	"car_top_capitao_foguete": "cars/car_capitao_foguete",
	"car_top_doutor_thrust": "cars/car_doutor_thrust",
	"car_top_ze_vapor": "cars/car_ze_vapor",
	# --- Carros de LADO (Pixel Vehicle Pack) — usados na intro, menu e seleção. Apontando p/ DIREITA. ---
	"car_side_comte_eclair": "cars/side_comte_eclair",
	"car_side_lady_nitro": "cars/side_lady_nitro",
	"car_side_capitao_foguete": "cars/side_capitao_foguete",
	"car_side_doutor_thrust": "cars/side_doutor_thrust",
	"car_side_ze_vapor": "cars/side_ze_vapor",
	# --- Retratos dos pilotos (Toon Characters 1) ---
	"portrait_comte_eclair": "characters/comte_eclair",
	"portrait_lady_nitro": "characters/lady_nitro",
	"portrait_capitao_foguete": "characters/capitao_foguete",
	"portrait_doutor_thrust": "characters/doutor_thrust",
	"portrait_ze_vapor": "characters/ze_vapor",
	# --- Objetos da pista (Racing Pack -> PNG/Objects) ---
	"obj_tires": "cars/objects/tires",
	"obj_cone": "cars/objects/cone",
	"obj_barrel": "cars/objects/barrel",
	"obj_oil": "cars/objects/oil",
	"obj_rock": "cars/objects/rock",
	# --- Efeitos (Particle Pack / Smoke Particles) — texturas BRANCAS, o jogo colore ---
	"fx_smoke": "effects/smoke",
	"fx_spark": "effects/spark",
	"fx_star": "effects/star",
	# --- UI (UI Pack) — botões 9-slice e painel ---
	"ui_button": "ui/button",
	"ui_button_pressed": "ui/button_pressed",
	"ui_panel": "ui/panel",
	# --- Input Prompts (ícones de toque para o tutorial da HUD) ---
	"ui_touch_hold": "ui/touch_hold",
	"ui_touch_swipe": "ui/touch_swipe",
	"ui_touch_double": "ui/touch_double",
}

## Fontes: o primeiro arquivo existente é usado. Kenney Fonts -> assets/fonts/.
const FONT_PATHS := {
	"title": ["res://assets/fonts/title.ttf", "res://assets/fonts/Kenney Future.ttf", "res://assets/fonts/Kenney Rocket.ttf"],
	"body": ["res://assets/fonts/body.ttf", "res://assets/fonts/Kenney Future Narrow.ttf"],
}

var _tex_cache := {}
var _audio_cache := {}
var _font_cache := {}
var _soft_circle: Texture2D
var _hard_circle: Texture2D


## Devolve a textura da chave ou null (=> use placeholder procedural).
func texture(key: String) -> Texture2D:
	if _tex_cache.has(key):
		return _tex_cache[key]
	var rel: String = TEXTURE_PATHS.get(key, key)
	var tex: Texture2D = null
	for base in [CUSTOM, KENNEY]:
		for ext in IMG_EXT:
			var path := "%s%s.%s" % [base, rel, ext]
			if ResourceLoader.exists(path):
				tex = load(path) as Texture2D
				break
		if tex != null:
			break
	_tex_cache[key] = tex
	return tex


## Procura um som em assets/custom/audio e assets/kenney/audio (ogg/wav/mp3).
## Retorna null se não existir (o AudioManager então sintetiza um som placeholder).
func audio(sound_name: String) -> AudioStream:
	if _audio_cache.has(sound_name):
		return _audio_cache[sound_name]
	var stream: AudioStream = null
	for base in [CUSTOM + "audio/", KENNEY + "audio/"]:
		for ext in AUDIO_EXT:
			var path := "%s%s.%s" % [base, sound_name, ext]
			if ResourceLoader.exists(path):
				stream = load(path) as AudioStream
				break
		if stream != null:
			break
	_audio_cache[sound_name] = stream
	return stream


## Fonte por chave ("title" / "body"). Sem arquivo => fonte padrão do Godot.
## A fonte padrão entra como fallback para garantir acentos (ã, ç, é...).
func font(key: String) -> Font:
	if _font_cache.has(key):
		return _font_cache[key]
	var result: Font = null
	var candidates: Array = FONT_PATHS.get(key, [])
	for path in candidates:
		if ResourceLoader.exists(path):
			var f := load(path) as Font
			if f != null:
				var fb: Array[Font] = [ThemeDB.fallback_font]
				f.fallbacks = fb
				result = f
				break
	_font_cache[key] = result
	return result


## Fonte garantida (custom se houver, senão a padrão do Godot).
func font_or_default(key: String) -> Font:
	var f := font(key)
	return f if f != null else ThemeDB.fallback_font


## Círculo suave (fumaça/poeira). Usa "fx_smoke" do Kenney se existir.
func soft_circle() -> Texture2D:
	var t := texture("fx_smoke")
	if t != null:
		return t
	if _soft_circle == null:
		_soft_circle = _make_radial([0.0, 1.0], [Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	return _soft_circle


## Círculo duro (faíscas, confete). Usa "fx_spark" do Kenney se existir.
func hard_circle() -> Texture2D:
	var t := texture("fx_spark")
	if t != null:
		return t
	if _hard_circle == null:
		_hard_circle = _make_radial([0.0, 0.7, 1.0], [Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	return _hard_circle


func _make_radial(offsets: Array, colors: Array) -> Texture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offsets)
	g.colors = PackedColorArray(colors)
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(0.5, 0.0)
	gt.width = 64
	gt.height = 64
	return gt
