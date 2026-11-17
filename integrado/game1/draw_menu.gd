extends Control
var _spacing_set := false

## Selector de serie para DRAW: al mejor de 3 o al mejor de 5.
##
## Se llega desde el cartel DRAW del tablon y, al confirmar, se guarda la
## eleccion en GameConfig y se arranca Game1/game_1.tscn. La revancha
## recarga la partida y conserva el modo elegido.

const FONT := preload("res://pixel-comic-sans-undertale-sans-font.ttf")

const OPTIONS := [3, 5]

# --- paleta (misma familia que el tablon y el escenario de DRAW) ---
const C_SKY := Color("b13a5e")
const C_SKY_LOW := Color("6e2347")
const C_MOUNTAIN := Color("3d1730")
const C_GROUND := Color("1c0d18")
const C_SUN := Color("ffd45e")
const C_SUN_HI := Color("ffe9a8")
const C_PAPER := Color("f0e4cf")
const C_PAPER_SHADE := Color("c9b795")
const C_PAPER_OFF := Color("d8c6a8")
const C_INK := Color("3a2230")
const C_DIM := Color("e8c8de")
const C_SEL := Color("ffd45e")
const C_SHADOW := Color(0, 0, 0, 0.55)

const CHAR_SPACING := 1

var index := 0
var _t := 0.0
var _buttons: Array[Rect2] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	index = 1 if GameConfig.draw_best_of == 5 else 0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


# --- entrada -------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_back()
	elif (event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right")
			or event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down")):
		index = 1 - index
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("NewGame"):
		_start()


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	for i in _buttons.size():
		if _buttons[i].has_point(click.position):
			index = i
			_start()
			accept_event()
			return


func _start() -> void:
	GameConfig.draw_best_of = OPTIONS[index]
	get_tree().change_scene_to_file("res://game1/game_1.tscn")


func _back() -> void:
	get_tree().change_scene_to_file("res://menu.tscn")


# --- dibujo --------------------------------------------------------------

func _draw() -> void:
	if not _spacing_set:
		_spacing_set = true
		FONT.set_extra_spacing(0, 3, 1)

	_backdrop()

	_text(Vector2(size.x * 0.5, 26.0), "DRAW", 24, C_SUN, true, true)
	_text(Vector2(size.x * 0.5, 46.0), "ELIGE LA SERIE", 8, C_DIM, true, true)

	_buttons = []
	var bw := 152.0
	var bh := 24.0
	for i in OPTIONS.size():
		var r := Rect2(size.x * 0.5 - bw * 0.5, 64.0 + i * 32.0, bw, bh)
		_buttons.push_back(r)
		_option(r, "AL MEJOR DE %d" % OPTIONS[i], i == index)

	var hints := "FLECHAS: ELEGIR    ENTER: EMPEZAR    ESC: VOLVER"
	_text(Vector2(size.x * 0.5, 170.0), hints,
		_fit_size(hints, 7, size.x - 12.0), C_DIM, true, true)


## Atardecer del duelo: cielo, sol y montanas.
func _backdrop() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), C_SKY)
	draw_rect(Rect2(0, size.y * 0.44, size.x, size.y * 0.30), C_SKY_LOW)

	var sun := Vector2(size.x * 0.5, size.y * 0.56)
	draw_circle(sun, 30.0, C_SUN_HI)
	draw_circle(sun, 25.0, C_SUN)

	draw_colored_polygon(PackedVector2Array([
		Vector2(0, size.y * 0.72),
		Vector2(72, size.y * 0.44),
		Vector2(150, size.y * 0.72),
	]), C_MOUNTAIN)
	draw_colored_polygon(PackedVector2Array([
		Vector2(size.x, size.y * 0.72),
		Vector2(size.x - 80, size.y * 0.40),
		Vector2(size.x - 158, size.y * 0.72),
	]), C_MOUNTAIN)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, size.y),
		Vector2(0, size.y * 0.72),
		Vector2(size.x, size.y * 0.72),
		Vector2(size.x, size.y),
	]), C_GROUND)
	draw_rect(Rect2(size.x * 0.5 - 60.0, size.y * 0.715, 120.0, 1.0),
		Color(1, 1, 1, 0.18))


## Opcion de serie: tarjeta de papel, la elegida con marco dorado pulsante.
func _option(r: Rect2, label: String, selected: bool) -> void:
	var pulse := (sin(_t * 5.0) + 1.0) * 0.5

	draw_rect(Rect2(r.position + Vector2(2, 3), r.size), C_SHADOW)
	if selected:
		draw_rect(Rect2(r.position - Vector2.ONE * 2, r.size + Vector2.ONE * 4),
			C_SEL.lerp(Color("fff3b0"), pulse))
	draw_rect(r, C_PAPER if selected else C_PAPER_OFF)
	draw_rect(Rect2(r.position, Vector2(r.size.x, 2)), C_PAPER.lightened(0.15))
	draw_rect(Rect2(r.position + Vector2(0, r.size.y - 3), Vector2(r.size.x, 3)),
		C_PAPER_SHADE)

	_text(Vector2(r.position.x + r.size.x * 0.5, r.position.y + r.size.y * 0.5),
		label, _fit_size(label, 12, r.size.x - 20.0), C_INK, true)

	if selected:
		var y := r.position.y + r.size.y * 0.5
		_text(Vector2(r.position.x - 10.0, y), ">", 14, C_SEL, true, true)
		_text(Vector2(r.end.x + 10.0, y), "<", 14, C_SEL, true, true)


# --- texto ---------------------------------------------------------------

func _fit_size(s: String, max_size: int, max_width: float) -> int:
	var size := max_size
	while size > 4 and _tw(s, size) > max_width:
		size -= 1
	return size


func _tw(s: String, size: int) -> float:
	var w := 0.0
	for i in s.length():
		w += FONT.get_string_size(s.substr(i, 1), HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		if i < s.length() - 1:
			w += CHAR_SPACING
	return w


func _text(center: Vector2, s: String, size: int, color: Color,
		centered := true, shadow := false) -> void:
	var w := _tw(s, size)
	var x := center.x - w * 0.5 if centered else center.x
	var y := center.y + FONT.get_ascent(size) * 0.5
	if shadow:
		_text_run(x + 1.0, y + 1.0, s, size, C_SHADOW)
	_text_run(x, y, s, size, color)


func _text_run(x: float, y: float, s: String, size: int, color: Color) -> void:
	for i in s.length():
		var c := s.substr(i, 1)
		draw_string(FONT, Vector2(x, y), c,
			HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
		x += FONT.get_string_size(c, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		x += CHAR_SPACING
