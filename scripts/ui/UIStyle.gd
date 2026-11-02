class_name UIStyle
extends RefCounted
## Paleta, tema e utilitários de texto do jogo (estilo cartoon: contorno grosso, cores vivas).
## O tema é aplicado na janela raiz pelo GameManager, então vale para todas as cenas.
## Se existirem texturas do Kenney UI Pack (ui_button, ui_panel... ver AssetLib), elas são usadas.

const INK := Color(0.1, 0.08, 0.14)
const CREAM := Color(1.0, 0.96, 0.84)
const YELLOW := Color(1.0, 0.82, 0.25)
const ORANGE := Color(1.0, 0.55, 0.12)
const RED := Color(0.9, 0.22, 0.27)
const BLUE := Color(0.2, 0.55, 0.9)
const TEAL := Color(0.18, 0.77, 0.71)
const GREEN := Color(0.35, 0.8, 0.3)
const PURPLE := Color(0.3, 0.2, 0.5)
const BG := Color(0.1, 0.07, 0.17)


static func build_theme() -> Theme:
	var t := Theme.new()
	var body_font := AssetLib.font("body")
	if body_font != null:
		t.default_font = body_font
	t.default_font_size = 24

	# Botões com "profundidade" (borda inferior grossa que afunda ao apertar)
	t.set_stylebox("normal", "Button", button_box(YELLOW))
	t.set_stylebox("hover", "Button", button_box(YELLOW.lightened(0.18)))
	t.set_stylebox("pressed", "Button", button_box(ORANGE, true))
	t.set_stylebox("hover_pressed", "Button", button_box(ORANGE, true))
	t.set_stylebox("disabled", "Button", button_box(Color(0.55, 0.55, 0.6)))
	t.set_stylebox("focus", "Button", focus_box())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(c, "Button", INK)
	t.set_color("font_disabled_color", "Button", Color(0.3, 0.3, 0.35))
	t.set_font_size("font_size", "Button", 28)

	t.set_color("font_color", "Label", CREAM)
	t.set_color("font_outline_color", "Label", INK)
	t.set_constant("outline_size", "Label", 6)

	t.set_stylebox("panel", "PanelContainer", panel_box())
	t.set_stylebox("panel", "Panel", panel_box())

	# CheckButton (interruptores das opções)
	t.set_color("font_color", "CheckButton", CREAM)
	t.set_color("font_hover_color", "CheckButton", YELLOW)
	t.set_color("font_pressed_color", "CheckButton", CREAM)
	t.set_color("font_hover_pressed_color", "CheckButton", YELLOW)
	t.set_color("font_focus_color", "CheckButton", CREAM)
	t.set_font_size("font_size", "CheckButton", 24)
	var empty := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		t.set_stylebox(s, "CheckButton", empty)

	# Slider
	var track := StyleBoxFlat.new()
	track.bg_color = INK
	track.set_corner_radius_all(8)
	track.content_margin_top = 6
	track.content_margin_bottom = 6
	var fill := StyleBoxFlat.new()
	fill.bg_color = TEAL
	fill.set_corner_radius_all(8)
	fill.content_margin_top = 6
	fill.content_margin_bottom = 6
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	return t


## Caixa de botão. Usa a textura do Kenney UI Pack se existir (9-slice), senão StyleBoxFlat.
static func button_box(color: Color, pressed: bool = false) -> StyleBox:
	var tex := AssetLib.texture("ui_button_pressed" if pressed else "ui_button")
	if tex != null:
		var sbt := StyleBoxTexture.new()
		sbt.texture = tex
		sbt.texture_margin_left = 16
		sbt.texture_margin_right = 16
		sbt.texture_margin_top = 16
		sbt.texture_margin_bottom = 16
		sbt.content_margin_left = 26
		sbt.content_margin_right = 26
		sbt.content_margin_top = 10
		sbt.content_margin_bottom = 14
		sbt.modulate_color = color.lightened(0.3)
		return sbt
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.border_color = INK
	sb.set_corner_radius_all(20)
	sb.set_border_width_all(4)
	sb.border_width_bottom = 4 if pressed else 10
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 14 if pressed else 8
	sb.content_margin_bottom = 8
	sb.anti_aliasing = true
	return sb


static func focus_box() -> StyleBox:
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = CREAM
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(22)
	sb.expand_margin_left = 4
	sb.expand_margin_right = 4
	sb.expand_margin_top = 4
	sb.expand_margin_bottom = 4
	return sb


static func panel_box(color: Color = Color(0.16, 0.11, 0.26, 0.96)) -> StyleBox:
	var tex := AssetLib.texture("ui_panel")
	if tex != null:
		var sbt := StyleBoxTexture.new()
		sbt.texture = tex
		sbt.texture_margin_left = 20
		sbt.texture_margin_right = 20
		sbt.texture_margin_top = 20
		sbt.texture_margin_bottom = 20
		sbt.content_margin_left = 24
		sbt.content_margin_right = 24
		sbt.content_margin_top = 20
		sbt.content_margin_bottom = 20
		return sbt
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.border_color = INK
	sb.set_border_width_all(5)
	sb.set_corner_radius_all(26)
	sb.content_margin_left = 26
	sb.content_margin_right = 26
	sb.content_margin_top = 20
	sb.content_margin_bottom = 20
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 10
	sb.shadow_offset = Vector2(0, 8)
	return sb


## Configurações de Label com contorno cartoon.
static func label_settings(size: int, color: Color = CREAM, outline: int = 8, title: bool = false) -> LabelSettings:
	var ls := LabelSettings.new()
	var f := AssetLib.font("title" if title else "body")
	if f != null:
		ls.font = f
	ls.font_size = size
	ls.font_color = color
	ls.outline_size = outline
	ls.outline_color = INK
	ls.shadow_color = Color(INK, 0.85)
	ls.shadow_size = 1
	ls.shadow_offset = Vector2(0, maxf(2.0, outline * 0.6))
	return ls


static func make_label(text: String, size: int, color: Color = CREAM, outline: int = 8,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER, title: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.label_settings = label_settings(size, color, outline, title)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func make_button(text: String, min_size: Vector2 = Vector2(280, 76), color: Color = YELLOW) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	if color != YELLOW:
		b.add_theme_stylebox_override("normal", button_box(color))
		b.add_theme_stylebox_override("hover", button_box(color.lightened(0.18)))
		b.add_theme_stylebox_override("pressed", button_box(color.darkened(0.15), true))
		b.add_theme_stylebox_override("hover_pressed", button_box(color.darkened(0.15), true))
	b.pressed.connect(AudioManager.play_sfx.bind("click", 1.0, 0.0))
	return b


## Desenha texto centralizado com contorno dentro de um _draw().
static func draw_text(ci: CanvasItem, center: Vector2, text: String, size: int, color: Color = CREAM,
		outline: int = 6, title: bool = false) -> void:
	var font := AssetLib.font_or_default("title" if title else "body")
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var pos := Vector2(center.x - w * 0.5, center.y + (font.get_ascent(size) - font.get_descent(size)) * 0.5)
	if outline > 0:
		ci.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, Color(INK, color.a))
	ci.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
