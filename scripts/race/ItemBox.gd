class_name ItemBox
extends Area2D
## Caixa "?" de item. Ao ser atravessada sorteia um power-up (sorteio depende da posição
## do carro na corrida — ver RaceController.roll_item) e reaparece depois de alguns segundos.

const RESPAWN_TIME := 2.5
const SIZE := 46.0

var _active := true
var _t := 0.0


func _ready() -> void:
	collision_layer = 4
	collision_mask = 2 | 8
	monitorable = false
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(SIZE + 10.0, SIZE + 10.0)
	cs.shape = shape
	add_child(cs)
	body_entered.connect(_on_body_entered)
	_t = randf() * 4.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if not _active:
		return
	var bob := sin(_t * 4.0) * 3.0
	var pulse := 1.0 + sin(_t * 7.0) * 0.06
	draw_colored_polygon(CarArt.ellipse(Vector2(6, 10), Vector2(26, 16), 14), Color(0, 0, 0, 0.18))
	draw_set_transform(Vector2(0, bob), _t * 1.4, Vector2(pulse, pulse))
	var h := SIZE * 0.5
	var hue := fmod(_t * 0.15, 1.0)
	CarArt.outlined(self, CarArt.rrect(Rect2(-h, -h, SIZE, SIZE), 9), Color.from_hsv(hue, 0.55, 1.0), 4.0)
	draw_colored_polygon(CarArt.rrect(Rect2(-h + 6, -h + 6, SIZE - 12, SIZE - 12), 6), Color.from_hsv(fmod(hue + 0.15, 1.0), 0.45, 1.0, 0.9))
	UIStyle.draw_text(self, Vector2(0, 2), "?", 34, Color.WHITE, 6, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _on_body_entered(body: Node2D) -> void:
	if not _active or not (body is Car):
		return
	var car := body as Car
	_active = false
	set_deferred("monitoring", false)
	if car.can_take_item():
		car.give_item(car.race.roll_item(car))
		if car.is_player:
			AudioManager.play_sfx("pickup")
	RaceFX.puff(car.race, global_position, Color(1, 1, 1, 0.9), 10, 0.5)
	get_tree().create_timer(RESPAWN_TIME, false).timeout.connect(_respawn)


func _respawn() -> void:
	_active = true
	monitoring = true
