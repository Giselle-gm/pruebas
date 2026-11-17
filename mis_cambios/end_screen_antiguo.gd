extends Control
var _spacing_set := false

## PANTALLA FINAL COMUN de todos los minijuegos (Test Your Might, Draw,
## Take). Se anade como hijo de la escena en curso y se llama show_end():
##
##     var es := load("res://end_screen.tscn").instantiate()
##     add_child(es)
##     es.show_end("J1 GANA", "5 DE 5 BLOQUES", Color("ff4d6d"))
##
## Dibuja el ganador y dos botones que se pueden pulsar con el raton o
## con las teclas: ESC vuelve al tablon y ESPACIO repite el juego.
## Cada juego pasa su titulo, su detalle y el color de acento.

const MENU_PATH := "res://menu.tscn"

signal pressed_menu
signal pressed_rematch

var _title := ""
var _detail := ""
var _accent := Color("ffd45e")
var _buttons: Array = []
var _hover := -1
var _done := false


## Anade la pantalla final a `parent` en un CanvasLayer alto. Hace falta
## asi: los juegos pintan su HUD en su propia capa, y un Control a secas
## quedaria detras suyo aunque se anadiera el ultimo.
static func spawn(parent: Node, title: String, detail: String,
		accent: Color) -> Control:
	var es := load("res://end_screen.tscn").instantiate() as Control
	parent.add_child(es)
	es.show_end(title, detail, accent)
	return es


func show_end(title: String, detail: String, accent: Color) -> void:
	_title = title
	_detail = detail
	_accent = accent
	_hover = -1
	_done = false
	_fit_to_viewport()
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = true
	queue_redraw()


func _ready() -> void:
	_fit_to_viewport()
	mouse_filter = Control.MOUSE_FILTER_STOP


## _input y no _unhandled_input: al ser una pantalla a tamano completo con
## mouse_filter STOP, la GUI se traga el evento y _unhandled_input nunca
## llega a disparar. _input lo ve todo, antes que nadie.

## El padre de esta escena es un Node2D (la arena del juego), no un
## Control: los anchors no hacen nada y el tamano quedaria en 0x0, de
## modo que no se dibujaria ni recibiria el raton. Se pone a mano.
func _fit_to_viewport() -> void:
	var vs := get_viewport_rect().size
	position = Vector2.ZERO
	pivot_offset = Vector2.ZERO
	size = vs


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if _done:
		return
	if event.is_action_pressed("ui_cancel"):
		_go(0)
	elif event.is_action_pressed("NewGame"):
		_go(1)
	var click := event as InputEventMouseButton
	if click == null or click.button_index != MOUSE_BUTTON_LEFT:
		return
	var i := _button_at(click.position)
	if click.pressed:
		_hover = i
	elif i >= 0:
		_go(i)
	queue_redraw()


## 0 = menu, 1 = revancha. Con _done se evita que un mismo final dispare
## dos veces si llegan tecla y clic a la vez.
func _go(i: int) -> void:
	if _done:
		return
	_done = true
	get_tree().paused = false
	if i == 0:
		pressed_menu.emit()
		get_tree().change_scene_to_file(MENU_PATH)
	else:
		pressed_rematch.emit()
		get_tree().reload_current_scene()


func _button_at(p: Vector2) -> int:
	for i in _buttons.size():
		if _buttons[i].has_point(p):
			return i
	return -1


# --- dibujo --------------------------------------------------------------

const C_SHADOW := Color(0.05, 0.02, 0.05)
const C_PANEL := Color("2c1430")
const C_PANEL_HI := Color("4a2b2f")
const C_TEXT := Color("ffeede")
const C_DIM := Color("9c7a96")
const C_OK := Color("8ce8a0")
const C_GOLD := Color("ffd45e")

const FONT := preload("res://pixel-comic-sans-undertale-sans-font.ttf")


func _draw() -> void:
	if not _spacing_set:
		_spacing_set = true
		FONT.set_extra_spacing(0, 3, 1)
	if not visible:
		return

	# Velo sobre la arena. Bastante opaco: si no, los carteles del juego
	# (que no se ocultan) se cuelan y acaban pisando a los botones.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.02, 0.08, 0.97))

	var cx := size.x * 0.5
	_text_outline(Vector2(cx, 34.0), _title, 20, _accent)

	if _detail != "":
		_text(Vector2(cx, 52.0), _detail, 7, C_DIM, true)

	# Los botones se montan aqui para que _unhandled_input mismo pueda
	# comprobar el raton sobre ellos.
	_buttons = []
	var labels := [
		["ESC", "VOLVER AL MENU"],
		["ESPACIO", "REVANCHA"],
	]
	var y := 80.0
	for k in labels.size():
		var key: String = labels[k][0]
		var txt: String = labels[k][1]
		var kw := _tw(key, 8) + 12.0
		var tw := _tw(txt, 8)
		var bw := kw + 8.0 + tw
		var bx := cx - bw * 0.5
		var hot := k == _hover
		var bc := C_GOLD if k == 0 else C_OK
		_buttons.push_back(Rect2(bx, y - 6.0, bw, 14.0))
		draw_rect(Rect2(bx + 1, y + 8, bw, 3), C_SHADOW)
		draw_rect(Rect2(bx, y, bw, 14), C_PANEL)
		draw_rect(Rect2(bx, y, bw, 1), bc)
		draw_rect(Rect2(bx, y, bw, 14), Color(bc.r, bc.g, bc.b, 0.22) if hot else C_PANEL)
		draw_rect(Rect2(bx, y + 13, bw, 1), C_PANEL_HI)
		_text(Vector2(bx + kw * 0.5, y + 6.0), key, 8, C_TEXT, true)
		_text(Vector2(bx + kw + 8.0, y + 5.0), txt, 8, bc, false)
		y += 20.0


# --- texto ---------------------------------------------------------------

const CHAR_SPACING := 1


func _tw(s: String, size: int) -> float:
	var w := 0.0
	for i in s.length():
		w += FONT.get_string_size(s.substr(i, 1), HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		if i < s.length() - 1:
			w += CHAR_SPACING
	return w


func _text(center: Vector2, s: String, size: int, color: Color,
		centered := true) -> void:
	var w := _tw(s, size)
	var x := center.x - w * 0.5 if centered else center.x
	var ax := x
	for i in s.length():
		var c := s.substr(i, 1)
		var cw := FONT.get_string_size(c, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		draw_string(FONT, Vector2(ax, center.y + FONT.get_ascent(size) * 0.5), c,
			HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
		ax += cw + CHAR_SPACING


func _text_outline(center: Vector2, s: String, size: int, color: Color) -> void:
	var w := _tw(s, size)
	var pos := Vector2(center.x - w * 0.5, center.y + FONT.get_ascent(size) * 0.5)
	var ax := pos.x
	for i in s.length():
		var c := s.substr(i, 1)
		var cw := FONT.get_string_size(c, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		for o in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
			draw_string(FONT, Vector2(ax, pos.y) + o, c,
				HORIZONTAL_ALIGNMENT_LEFT, -1, size, C_SHADOW)
		draw_string(FONT, Vector2(ax, pos.y), c, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
		ax += cw + CHAR_SPACING
