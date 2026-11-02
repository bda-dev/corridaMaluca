class_name CharacterData
extends Resource
## Ficha de um piloto + carro. Cada personagem é um arquivo .tres em res://data/characters/.
## PARA ADICIONAR UM PERSONAGEM: duplique um .tres, edite no Inspector e adicione o caminho
## em GameManager.ROSTER_PATHS. Nada mais precisa mudar no código.

@export var id: String = ""
@export var display_name: String = ""
@export var nationality: String = ""
@export_multiline var bio: String = ""
@export var catchphrase: String = ""

@export_group("Carro")
@export var car_name: String = ""
@export var car_year: int = 1900
## Recorde histórico real do carro (km/h) — exibido na seleção e na intro.
@export var car_record_kmh: float = 0.0
## Formato usado pelo desenho procedural (CarArt): jeantaud, jamais_contente,
## golden_arrow, blue_bird, spirit_of_america, thrust_ssc
@export var car_shape: String = "jeantaud"
@export var body_color: Color = Color(0.9, 0.2, 0.2)
@export var accent_color: Color = Color(1, 0.85, 0.2)

@export_group("Piloto (retrato)")
@export var skin_color: Color = Color(1.0, 0.8, 0.64)
## Estilo de cabeça do retrato procedural: top_hat, elegant, aviator, mad_hair, straw_hat
@export var hat_style: String = "top_hat"
@export var hair_color: Color = Color(0.25, 0.15, 0.1)

@export_group("Especial (toque duplo)")
## IDs implementados em Car.gd: faisca, nitro_real, pos_combustao, teleporte, nuvem_vapor
@export var special_id: String = ""
@export var special_name: String = ""
@export_multiline var special_desc: String = ""
## Segundos para carregar o especial do zero.
@export var special_charge_time: float = 14.0

@export_group("Física")
## Velocidade máxima em px/s (1 px/s = 1 km/h no velocímetro).
@export var max_speed: float = 680.0
## Aceleração em px/s².
@export var acceleration: float = 760.0
## Velocidade de giro (rad/s) em velocidade alta.
@export var handling: float = 3.0
## Aderência lateral: baixo = derrapa mais (drift longo e cômico).
@export var grip: float = 5.5
## Massa relativa nas trombadas.
@export var weight: float = 1.0

@export_group("Assets opcionais")
## Se definidos, substituem o desenho procedural (também dá para usar o AssetLib).
@export var car_texture: Texture2D
@export var portrait_texture: Texture2D


## Notas 1..5 para as barras de atributo da tela de seleção.
func stat_speed() -> float:
	return clampf(remap(max_speed, 600.0, 780.0, 1.0, 5.0), 1.0, 5.0)


func stat_accel() -> float:
	return clampf(remap(acceleration, 520.0, 920.0, 1.0, 5.0), 1.0, 5.0)


func stat_handling() -> float:
	return clampf(remap(handling + grip * 0.15, 2.6, 4.6, 1.0, 5.0), 1.0, 5.0)


func stat_weight() -> float:
	return clampf(remap(weight, 0.8, 1.6, 1.0, 5.0), 1.0, 5.0)


func car_top_texture() -> Texture2D:
	if car_texture != null:
		return car_texture
	return AssetLib.texture("car_top_" + id)


func car_side_texture() -> Texture2D:
	return AssetLib.texture("car_side_" + id)


func portrait() -> Texture2D:
	if portrait_texture != null:
		return portrait_texture
	return AssetLib.texture("portrait_" + id)
