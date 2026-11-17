extends Control

## HUD del Test Your Might: bloque actual, progreso, umbral y tiempo.
## Los medidores verticales se dibujan en el mundo (gauge.gd).

class_name TymHud
var _spacing_set := false

const NUM_PLAYERS := 2
## La misma fuente pixel del menu del proyecto.
const FONT := preload("res://pixel-comic-sans-undertale-sans-font.ttf")

const C_P1 := Color("ff4d6d")
const C_P2 := Color("3ea6ff")
const C_PANEL := Color("1a0b1c")
const C_BORDER := Color("8c3a72")
const C_TEXT := Color("ffeede")
const C_DIM := Color("9c7a96")
const C_GOLD := Color("ffd45e")
const C_OK := Color("8ce8a0")
const C_BAD := Color("ff8fa8")

const PANEL_H := 34.0
const PANEL_W := 104.0

# Las tres filas del panel, en bandas disjuntas. Antes los puntos (14..19)
# y la barra CEDE (18..26) se comian 2 px: se dibujaban encima.
const ROW1_Y := 6.0     ## centro de la linea de texto
const PIP_Y := 12.0     ## borde superior de los puntos
const PIP_H := 5.0
const BAR_Y := 20.0     ## borde superior de la barra CEDE
const BAR_H := 6.0

# --- estado que escribe tym.gd ---
var total_blocks := 5
var time_left := 0.0
var time_max := 1.0
var show_time := false
var tag := ""
var hint := ""

var players := [
	{"material": "", "tier": 1, "broken": 0, "threshold": 0.0, "hold": 0.0,
		"press": 0.0, "flash": 0.0, "ok": false},
	{"material": "", "tier": 1, "broken": 0, "threshold": 0.0, "hold": 0.0,
		"press": 0.0, "flash": 0.0, "ok": false},
]

var _banner_t := 0.0

func _process(delta: float) -> void:
	if _banner_t > 0.0:
		_banner_t = maxf(0.0, _banner_t - delta)
	queue_redraw()


func show_banner(text: String, sub := "", seconds := 1.2) -> void:
	players_banner_text = text
	players_banner_sub = sub
	_banner_t = seconds


var players_banner_text := ""
var players_banner_sub := ""


func clear_banner() -> void:
	players_banner_text = ""
	players_banner_sub = ""
	_banner_t = 0.0


func set_player(i: int, material: String, tier: int, broken: int,
		threshold: float, hold: float, press: float, flash: float, ok: bool) -> void:
	players[i] = {
		"material": material, "tier": tier, "broken": broken,
		"threshold": threshold, "hold": hold, "press": press,
		"flash": flash, "ok": ok,
	}


# --- dibujo --------------------------------------------------------------

func _draw() -> void:
	if not _spacing_set:
		_spacing_set = true
		FONT.set_extra_spacing(0, 3, 1)
	draw_rect(Rect2(0, 0, size.x, PANEL_H), C_PANEL)
	draw_rect(Rect2(0, PANEL_H - 1, size.x, 1), C_BORDER)

	_panel(0, C_P1, 3.0)
	_panel(1, C_P2, size.x - PANEL_W - 3.0)
	_center()

	if show_time:
		_draw_time()
	if tag != "":
		_text(Vector2(size.x * 0.5, size.y - 21.0), tag, 6, C_DIM, true)
	if _banner_t > 0.0:
		_draw_banner()
	if hint != "":
		draw_rect(Rect2(0, size.y - 10, size.x, 10), C_PANEL)
		draw_rect(Rect2(0, size.y - 11, size.x, 1), C_BORDER)
		_text(Vector2(size.x * 0.5, size.y - 3.5), hint, 6, C_DIM, true)


func _panel(i: int, color: Color, x: float) -> void:
	var d: Dictionary = players[i]
	var r := Rect2(x, 1, PANEL_W, PANEL_H - 3)
	draw_rect(r, Color(color.r, color.g, color.b, 0.10))
	draw_rect(r, Color(color.r, color.g, color.b, 0.45), false, 1.0)

	# Fila 1: jugador + material (alineados a la izquierda), y a la derecha
	# linea y aguantar.
	_text(Vector2(r.position.x + 4, ROW1_Y), "J%d" % (i + 1), 7, C_TEXT, false)
	_text(Vector2(r.position.x + 17, ROW1_Y), String(d["material"]), 6, C_DIM, false)
	_text_right(r.end.x - 4.0, ROW1_Y, "%d / %.1fs" % [
		int(d["threshold"]), float(d["hold"])], 6, C_GOLD)

	# Fila 2: progreso, un punto por bloque roto.
	var pip := 7.0
	var px := r.position.x + 4.0
	for k in total_blocks:
		var on := k < int(d["broken"])
		draw_rect(Rect2(px, PIP_Y, pip, PIP_H), color if on else Color("2c1430"))
		if on:
			draw_rect(Rect2(px, PIP_Y, pip, 2), color.lightened(0.4))
		px += pip + 2.0

	# Fila 3: cuanto le falta al bloque para ceder.
	var press: float = d["press"]
	var lx := r.position.x + 4.0
	_text(Vector2(lx, BAR_Y + BAR_H * 0.5), "CEDE", 5, C_DIM, false)
	var bx := lx + 20.0
	var bw := r.end.x - 5.0 - bx
	draw_rect(Rect2(bx - 1, BAR_Y - 1, bw + 2, BAR_H + 2), C_SHADOW)
	draw_rect(Rect2(bx, BAR_Y, bw, BAR_H), Color("2c1430"))
	if press > 0.0:
		draw_rect(Rect2(bx, BAR_Y, bw * clampf(press, 0.0, 1.0), BAR_H), C_GOLD)

	# Aviso del ultimo golpe, con fondo para que se lea encima.
	# Voces del announcer de MK: "BRAKE!!" al romper, "TOO SLOW" al fallar.
	var flash: float = d["flash"]
	if flash > 0.01:
		var ok: bool = d["ok"]
		var c := C_OK if ok else C_BAD
		draw_rect(r, Color(0, 0, 0, 0.75 * flash))
		# El texto aguanta opaco casi todo el flash: si comparte alfa con
		# el fondo se va apagando y acaba leyendose muddy.
		# Centrado en el panel (1..PANEL_H-2), no en una fila concreta.
		_text(Vector2(r.position.x + PANEL_W * 0.5, (PANEL_H - 2.0) * 0.5),
			"BRAKE!!" if ok else "TOO SLOW", 7,
			Color(c.r, c.g, c.b, clampf(flash * 3.0, 0.0, 1.0)), true)



func _center() -> void:
	var cx := size.x * 0.5
	var d0: Dictionary = players[0]
	var d1: Dictionary = players[1]
	var lead: Dictionary = players[0] if int(d0["broken"]) >= int(d1["broken"]) else players[1]
	_text(Vector2(cx, 10.0), "%d/%d" % [int(lead["broken"]), total_blocks], 10, C_TEXT, true)
	_text(Vector2(cx, 21.0), "BLOQUES", 5, C_DIM, true)


func _draw_time() -> void:
	var ratio := clampf(time_left / maxf(0.001, time_max), 0.0, 1.0)
	var w := 62.0
	var label := "TIEMPO "
	var num := "%d" % int(ceil(time_left))
	var lw := text_size(label, 6)
	var nw := text_size(num, 7)
	var total := lw + 2.0 + w + 3.0 + nw
	var x := size.x * 0.5 - total * 0.5
	var y := PANEL_H + 4.0

	_text(Vector2(x, y + 1.0), label, 6, C_DIM, false)

	var bx := x + lw + 2.0
	draw_rect(Rect2(bx - 1, y - 1, w + 2, 8), Color(0.07, 0.04, 0.09, 0.92))
	draw_rect(Rect2(bx, y, w, 6), Color("2c1430"))
	draw_rect(Rect2(bx, y, w * ratio, 6), C_GOLD if ratio > 0.25 else C_BAD)

	# El numero va FUERA de la barra: encima del oro no se leia.
	_text(Vector2(bx + w + 3.0, y + 5.0), num, 7, C_TEXT, false)


const CHAR_SPACING := 1

func _tw(s: String, font_size: int) -> float:
	var f := _font()
	var w := 0.0
	for i in s.length():
		w += f.get_string_size(s.substr(i, 1), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		if i < s.length() - 1:
			w += CHAR_SPACING
	return w

func text_size(s: String, font_size: int) -> float:
	return _tw(s, font_size)


func _draw_banner() -> void:
	var a := clampf(_banner_t * 4.0, 0.0, 1.0)
	var cy := 80.0 + (1.0 - a) * -6.0
	if players_banner_sub != "":
		_text_outline(Vector2(size.x * 0.5, cy + 16.0), players_banner_sub, 7,
			Color(C_DIM.r, C_DIM.g, C_DIM.b, a))
	_text_outline(Vector2(size.x * 0.5, cy), players_banner_text, 15,
		Color(C_TEXT.r, C_TEXT.g, C_TEXT.b, a))


# --- texto ---------------------------------------------------------------

const C_SHADOW := Color(0.07, 0.03, 0.06)


func _font() -> Font:
	return FONT


func _text(center: Vector2, s: String, font_size: int, color: Color,
		centered := true) -> void:
	var f := _font()
	var w := _tw(s, font_size)
	var x := center.x - w * 0.5 if centered else center.x
	var ax := x
	var ascent := f.get_ascent(font_size) * 0.5
	for i in s.length():
		var c := s.substr(i, 1)
		var cw := f.get_string_size(c, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string(f, Vector2(ax, center.y + ascent), c,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		ax += cw + CHAR_SPACING


## Texto cuyo extremo derecho queda en x_right.
func _text_right(x_right: float, y: float, s: String, font_size: int, color: Color) -> void:
	var f := _font()
	var w := _tw(s, font_size)
	var ax := x_right - w
	for i in s.length():
		var c := s.substr(i, 1)
		var cw := f.get_string_size(c, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string(f, Vector2(ax, y + f.get_ascent(font_size) * 0.5), c,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		ax += cw + CHAR_SPACING


func _text_outline(center: Vector2, s: String, font_size: int, color: Color) -> void:
	var f := _font()
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var pos := Vector2(center.x - w * 0.5, center.y + f.get_ascent(font_size) * 0.5)
	for o in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		draw_string(f, pos + o, s, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, C_SHADOW)
	draw_string(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
