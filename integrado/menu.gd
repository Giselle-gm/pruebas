extends Control
var _spacing_set := false

## MENU PRINCIPAL - "TABLON DE ANUNCIOS".
##
## Cada cartel del tablon es un minijuego. Se elige con las flechas (o
## haciendo clic) y se arranca con Enter. Los controles de cada juego son
## distintos, asi que el cartel solo indica como entrar.
##
## Anadir un minijuego es anadir una fila a POSTERS; el resto se dibuja solo.

const FONT := preload("res://pixel-comic-sans-undertale-sans-font.ttf")

## Cada cartel declara las teclas REALES de su juego (project.godot:
## Action1 = Z, Action2 = M, NewGame = ESPACIO, take_photo = Z), para que
## el cartel de controles no haya que inventarse nada. ESC no se lista
## aqui: en los tres juegos significa lo mismo (volver al tablón) y ya
## sale en la seccion de abajo.
const POSTERS := [
	{
		"title": ["TEST", "YOUR", "MIGHT"],
		"game_key": "test_your_might",
		"tag": "2 JUGADORES",
		"scene": "res://test_your_might/tym.tscn",
		"accent": Color("ff4d6d"),
		"art": "fight",
		"keys": [["Z", "JUGADOR 1"], ["M", "JUGADOR 2"]],
	},
	{
		"title": ["DRAW"],
		"game_key": "draw",
		"tag": "2 JUGADORES",
		"scene": "res://game1/draw_menu.tscn",
		"accent": Color("ffd45e"),
		"art": "duel",
		"keys": [["Z", "JUGADOR 1"], ["M", "JUGADOR 2"], ["ESPACIO", "OTRA RONDA"]],
	},
	{
		"title": ["TAKE"],
		"game_key": "take",
		"tag": "1 JUGADOR",
		"scene": "res://game2/game_2.tscn",
		"accent": Color("3ea6ff"),
		"art": "camera",
		"keys": [["Z", "HACER FOTO"]],
	},
]

# --- medidas del tablon (el viewport es de 320x180) ---
const BOARD_X := 14.0
const BOARD_Y := 26.0
const BOARD_W := 292.0
const BOARD_H := 126.0

const CARD_W := 74.0
const CARD_H := 100.0
const CARD_GAP := 16.0
const CARD_Y := 44.0

## Tope del titulo de los carteles. Los nombres cortos (DRAW, TAKE) se
## quedan pequenos si el tope es bajo, y parecian etiquetas y no titulares.
const TITLE_MAX := 18
const CHAR_SPACING := 1

## Separacion entre filas del panel de controles. Con 11 cada tecla
## lleva su aire; antes se tocaban y parecian un bloque.
const ROW_H := 11.0

# --- paleta ---
const C_BOARD := Color("4a2b2f")
const C_BOARD_HI := Color("6b4048")
const C_BOARD_EDGE := Color("2a161a")
const C_CORK := Color("8a6a4a")
const C_CORK_HI := Color("a98a63")
const C_PAPER := Color("f0e4cf")
const C_PAPER_SHADE := Color("c9b795")
const C_INK := Color("3a2230")
const C_DIM := Color("e8c8de")
const C_SEL := Color("ffd45e")
const C_SHADOW := Color(0, 0, 0, 0.6)

const C_BLOB_1 := Color("e8564f")
const C_BLOB_2 := Color("5b9bd5")

var index := 0
var show_controls := false
var screen_mode := "main"
var _t := 0.0
var _bob := 0.0


func _ready() -> void:
	get_tree().paused = false
	mouse_filter = Control.MOUSE_FILTER_STOP


func _process(delta: float) -> void:
	_t += delta
	if not show_controls:
		_bob += delta * 4.0
	queue_redraw()


# --- entrada -------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if show_controls:
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept") or event.is_action_pressed("NewGame"):
			show_controls = false
		return

	if event.is_action_pressed("ui_cancel"):
		if screen_mode != "main":
			screen_mode = "main"
			index = 0
			queue_redraw()
		else:
			get_tree().quit()
		return

	if event.is_action_pressed("ui_right") or event.is_action_pressed("ui_down"):
		_select(wrapi(index + 1, 0, POSTERS.size()))
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_up"):
		_select(wrapi(index - 1, 0, POSTERS.size()))
	elif event.is_action_pressed("NewGame"):
		if screen_mode == "main":
			show_controls = true
		else:
			_open_selected_library()
	elif event.is_action_pressed("ui_accept"):
		if screen_mode == "main":
			_activate()
		else:
			_open_selected_library()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R and screen_mode == "main":
			_open_library("ranking")
		elif event.keycode == KEY_V and screen_mode == "main":
			_open_library("rating")


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	if screen_mode == "main":
		if Rect2(42, 154, 105, 17).has_point(click.position):
			_open_library("ranking")
			accept_event()
			return
		if Rect2(173, 154, 105, 17).has_point(click.position):
			_open_library("rating")
			accept_event()
			return
	var i := _poster_at(click.position)
	if i >= 0:
		index = i
		if screen_mode == "main":
			_activate()
		else:
			_open_selected_library()
		accept_event()


func _open_library(mode: String) -> void:
	screen_mode = mode
	index = 0
	show_controls = false
	queue_redraw()


func _open_selected_library() -> void:
	var game_key := str(POSTERS[index]["game_key"])
	GameSession.establecer_minijuego(game_key)
	if screen_mode == "ranking":
		get_tree().change_scene_to_file("res://ranking/ranking2.tscn")
	else:
		get_tree().change_scene_to_file("res://ranking/valoracion_resumen.tscn")


func _select(i: int) -> void:
	index = i
	queue_redraw()


func _activate() -> void:
	var scene: String = POSTERS[index]["scene"]
	if scene != "":
		get_tree().change_scene_to_file(scene)


func _poster_at(p: Vector2) -> int:
	for i in POSTERS.size():
		if _card_rect(i).has_point(p):
			return i
	return -1


# --- dibujo --------------------------------------------------------------

func _draw() -> void:
	if not _spacing_set:
		_spacing_set = true
		FONT.set_extra_spacing(0, 3, 1)
	# Velo para que el tablon destaque sobre el fondo.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.02, 0.07, 0.45))

	if show_controls:
		_board()
		_controls()
		return

	_title()
	_board()
	for i in POSTERS.size():
		_poster(i)
	if screen_mode == "main":
		_footer()
	else:
		_library_footer()


func _title() -> void:
	var bob := sin(_t * 2.0)
	var s := _fit_size("TAKE OR DRAW", 14, size.x - 24)
	_text(Vector2(size.x * 0.5, 8.0 + bob), "TAKE OR DRAW", s, C_PAPER, true, true)


func _board() -> void:
	var b := Rect2(BOARD_X, BOARD_Y, BOARD_W, BOARD_H)
	draw_rect(Rect2(b.position - Vector2.ONE * 3, b.size + Vector2.ONE * 6), C_BOARD_EDGE)
	draw_rect(b, C_BOARD)
	draw_rect(Rect2(b.position, Vector2(b.size.x, 3)), C_BOARD_HI)
	draw_rect(Rect2(b.position + Vector2(0, b.size.y - 3), Vector2(b.size.x, 3)), C_BOARD_EDGE)

	var cork := Rect2(b.position + Vector2(3, 5), b.size - Vector2(6, 10))
	draw_rect(cork, C_CORK)
	draw_rect(Rect2(cork.position, Vector2(cork.size.x, 2)), C_CORK_HI)

	for c in [cork.position + Vector2(4, 4),
			Vector2(cork.end.x - 5, cork.position.y + 4),
			Vector2(cork.position.x + 4, cork.end.y - 5),
			cork.end - Vector2(5, 5)]:
		draw_rect(Rect2(c.x, c.y, 3, 3), C_BOARD_EDGE)
		draw_rect(Rect2(Vector2(c.x + 1, c.y), Vector2.ONE), Color(0.75, 0.65, 0.55))


func _card_rect(i: int) -> Rect2:
	var total := POSTERS.size() * CARD_W + (POSTERS.size() - 1) * CARD_GAP
	var x := size.x * 0.5 - total * 0.5 + i * (CARD_W + CARD_GAP)
	var lift := 0.0
	if i == index and not show_controls:
		lift = 3.0 + sin(_bob) * 1.5
	return Rect2(x, CARD_Y - lift, CARD_W, CARD_H)


## Un cartel = un minijuego. El interior se maqueta de arriba abajo para
## que el titulo, la ilustracion y la etiqueta nunca se pisen.
func _poster(i: int) -> void:
	var p: Dictionary = POSTERS[i]
	var sel := i == index
	var accent: Color = p["accent"]

	var r := _card_rect(i)
	var cx := r.position.x + r.size.x * 0.5

	draw_rect(Rect2(r.position + Vector2(2, 3), r.size), Color(0, 0, 0, 0.35))
	draw_rect(r, C_PAPER)
	draw_rect(Rect2(r.position + Vector2(0, r.size.y - 4), Vector2(r.size.x, 4)), C_PAPER_SHADE)
	draw_rect(Rect2(r.position, Vector2(r.size.x, 2)), C_PAPER.lightened(0.12))

	if sel:
		draw_rect(Rect2(r.position - Vector2.ONE * 2, r.size + Vector2.ONE * 4), accent)
		draw_rect(Rect2(r.position - Vector2.ONE, r.size + Vector2.ONE * 2), C_PAPER)

	# Chincheta.
	draw_rect(Rect2(cx - 2, r.position.y - 3, 5, 5), accent)
	draw_rect(Rect2(Vector2(cx - 1, r.position.y - 2), Vector2.ONE), Color(1, 1, 1, 0.85))

	# Ilustracion en una BANDA FIJA al pie del cartel. Antes colgaba del
	# titulo, asi que un cartel de una sola linea (DRAW, TAKE) dejaba un
	# boquete en medio y la ilustracion se caia al centro.
	var bottom := r.position.y + r.size.y - 13.0
	var art_h := 26.0
	var art_rect := Rect2(Vector2(r.position.x + 9, bottom - art_h),
		Vector2(r.size.x - 18, art_h))
	_draw_art(String(p["art"]), art_rect, accent)

	# Titulo: una linea por entrada, ajustada al ancho y centrado en el
	# hueco que queda sobre la ilustracion.
	var top := r.position.y + 8.0
	var lines: Array = p["title"]
	var s := TITLE_MAX
	for line in lines:
		s = mini(s, _fit_size(String(line), TITLE_MAX, r.size.x - 12))
	var line_h := s * 0.85
	var block := line_h * lines.size()
	var y := top + maxf(0.0, (art_rect.position.y - 3.0 - top - block) * 0.5)
	for line in lines:
		_text(Vector2(cx, y + line_h * 0.5), String(line), s, C_INK, true)
		y += line_h

	# Etiqueta al pie del cartel.
	var tag: String = p["tag"]
	_text(Vector2(cx, r.position.y + r.size.y - 8.0), tag,
		_fit_size(tag, 8, r.size.x - 10), C_PAPER_SHADE.darkened(0.3), true)


## Pequena ilustracion de cada cartel.
func _draw_art(kind: String, area: Rect2, accent: Color) -> void:
	var cx := area.position.x + area.size.x * 0.5
	var cy := area.position.y + area.size.y * 0.5
	var w: float = minf(area.size.x, 34.0)
	var h: float = minf(area.size.y, 16.0)

	match kind:
		"fight":
			_blob(Rect2(cx - w * 0.5 - 3, cy - h * 0.5, w * 0.42, h), C_BLOB_1)
			_blob(Rect2(cx + 3, cy - h * 0.5, w * 0.42, h), C_BLOB_2)
			draw_rect(Rect2(cx - 3, cy - 2, 6, 5), accent)
		"duel":
			# Dos duelistas enfrentados y el fogonazo del disparo entre los dos.
			var bw := w * 0.30
			var bh := h * 0.82
			_blob(Rect2(cx - w * 0.5, cy - bh * 0.5, bw, bh), C_BLOB_1)
			_blob(Rect2(cx + w * 0.5 - bw, cy - bh * 0.5, bw, bh), C_BLOB_2)
			draw_rect(Rect2(cx - 1, cy - 4, 2, 8), accent)
			draw_rect(Rect2(cx - 4, cy - 1, 8, 2), accent)
			draw_rect(Rect2(cx - 2, cy - 2, 4, 4), C_PAPER)
		"camera":
			_outline_rect(Rect2(cx - w * 0.5, cy - h * 0.5, w, h), C_INK)
			draw_rect(Rect2(cx - w * 0.3, cy - 1, w * 0.6, h * 0.4), accent)
			draw_rect(Rect2(cx - w * 0.34, cy, 2, 3), C_INK)
			draw_rect(Rect2(cx + w * 0.3, cy, 2, 3), C_INK)


## Blob pixelado con dos ojos.
func _blob(r: Rect2, color: Color) -> void:
	draw_rect(r, color)
	var eye := C_PAPER
	draw_rect(Rect2(r.position.x + r.size.x * 0.22, r.position.y + r.size.y * 0.3, 2, 2), eye)
	draw_rect(Rect2(r.position.x + r.size.x * 0.62, r.position.y + r.size.y * 0.3, 2, 2), eye)
	draw_rect(Rect2(r.position.x + 1, r.position.y + r.size.y - 3,
		r.size.x - 2, 2), color.darkened(0.25))


## Contorno de 1 px (estilo boceto a lapiz).
func _outline_rect(r: Rect2, color: Color) -> void:
	draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), color)
	draw_rect(Rect2(r.position + Vector2(0, r.size.y - 1), Vector2(r.size.x, 1)), color)
	draw_rect(Rect2(r.position, Vector2(1, r.size.y)), color)
	draw_rect(Rect2(r.position + Vector2(r.size.x - 1, 0), Vector2(1, r.size.y)), color)


func _footer() -> void:
	_draw_menu_button(Rect2(42, 154, 105, 17), "R  RANKING", Color("725523"))
	_draw_menu_button(Rect2(173, 154, 105, 17), "V  VALORACION", Color("28583d"))
	_text(Vector2(size.x * 0.5, 177), "FLECHAS: ELEGIR   ENTER: JUGAR   ESPACIO: CONTROLES",
		_fit_size("FLECHAS: ELEGIR   ENTER: JUGAR   ESPACIO: CONTROLES", 6, size.x - 8), C_DIM, true)


func _library_footer() -> void:
	var heading := "ELIGE UN JUEGO PARA VER SU " + ("RANKING" if screen_mode == "ranking" else "VALORACION")
	_text(Vector2(size.x * 0.5, 160), heading, _fit_size(heading, 7, size.x - 12), C_SEL, true)
	_text(Vector2(size.x * 0.5, 174), "FLECHAS: ELEGIR   ENTER: ABRIR   ESC: VOLVER",
		_fit_size("FLECHAS: ELEGIR   ENTER: ABRIR   ESC: VOLVER", 7, size.x - 10), C_DIM, true)


func _draw_menu_button(rect: Rect2, label: String, color: Color) -> void:
	draw_rect(Rect2(rect.position + Vector2(1, 2), rect.size), Color(0, 0, 0, 0.4))
	draw_rect(rect, color)
	draw_rect(rect, C_PAPER, false, 1.0)
	_text(rect.get_center(), label, 7, C_PAPER, true)


func _controls() -> void:
	# Panel mas compacto y centrado en el tablón.
	var r := Rect2(70, 18, 180, 140)
	draw_rect(Rect2(r.position + Vector2(2, 3), r.size), Color(0, 0, 0, 0.45))
	draw_rect(r, C_PAPER)
	draw_rect(Rect2(r.position, Vector2(r.size.x, 3)), POSTERS[index]["accent"])
	draw_rect(Rect2(r.position + Vector2(0, r.size.y - 4), Vector2(r.size.x, 4)), C_PAPER_SHADE)

	var accent: Color = POSTERS[index]["accent"]
	var cx := r.position.x + r.size.x * 0.5
	var pad := 16.0
	var kx := r.position.x + pad
	var right := r.position.x + r.size.x - pad

	_text(Vector2(cx, r.position.y + 11), "CONTROLES", 10, C_INK, true)
	draw_rect(Rect2(kx, r.position.y + 17, r.size.x - pad * 2.0, 1),
		C_PAPER_SHADE.darkened(0.15))

	# Que teclas son las del juego y cuales las del tablón: sin este
	# encabezado no se sabe si Z es suyo o del menu.
	var game := "EN " + " ".join(POSTERS[index]["title"])
	_text(Vector2(kx, r.position.y + 23), game,
		_fit_size(game, 7, r.size.x - pad * 2.0), C_INK.darkened(0.45), false)

	var keys: Array = POSTERS[index]["keys"]
	var menu_rows := [
		["FLECHAS", "CAMBIAR CARTEL"],
		["ENTER", "EMPEZAR"],
		["ESPACIO", "VER CONTROLES"],
		["ESC", "VOLVER / SALIR"],
	]

	# Columna de accion comun a las dos listas: si cada fila midiera su
	# propia, las acciones de arriba y de abajo no saldrian alineadas.
	var kw_max := 0.0
	for row in keys + menu_rows:
		kw_max = maxf(kw_max, text_width(String(row[0]), 8))
	var col := kx + kw_max + 14.0

	var y := r.position.y + 34.0
	for row in keys:
		_key_row(kx, col, right, y, String(row[0]), String(row[1]), accent)
		y += ROW_H

	draw_rect(Rect2(kx, y + 2.0, right - kx, 1), C_PAPER_SHADE.darkened(0.2))
	_text(Vector2(kx, y + 8.0), "EN EL TABLON", 7, C_INK.darkened(0.45), false)
	y += 16.0

	for row in menu_rows:
		_key_row(kx, col, right, y, String(row[0]), String(row[1]), accent)
		y += ROW_H


## Tecla en recuadro con relieve (sombra debajo) y su accion a la derecha.
func _key_row(kx: float, col: float, right: float, y: float, key: String,
		action: String, accent: Color) -> void:
	var kw := text_width(key, 8) + 10.0
	draw_rect(Rect2(kx, y - 4.5, kw, 11), C_INK.darkened(0.55))   # sombra
	draw_rect(Rect2(kx, y - 6.5, kw, 11), C_PAPER.lightened(0.45))
	draw_rect(Rect2(kx, y - 6.5, kw, 11), C_INK.darkened(0.35), false, 1.0)
	_text(Vector2(kx + kw * 0.5, y - 0.5), key, 8, C_INK, true)
	_text(Vector2(col, y), action, _fit_size(action, 8, right - col), accent, false)



func _fit_size(s: String, max_size: int, max_width: float) -> int:
	var size := max_size
	while size > 4 and text_width(s, size) > max_width:
		size -= 1
	return size


func text_width(s: String, size: int) -> float:
	var f: Font = FONT
	var w := 0.0
	for i in s.length():
		w += f.get_string_size(s.substr(i, 1), HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		if i < s.length() - 1:
			w += CHAR_SPACING
	return w


func _text(center: Vector2, s: String, size: int, color: Color,
		centered := true, shadow := false) -> void:
	var f: Font = FONT
	var w := text_width(s, size)
	var x := center.x - w * 0.5 if centered else center.x
	var pos := Vector2(x, center.y + f.get_ascent(size) * 0.5)
	if shadow:
		var ax := pos.x
		for i in s.length():
			var c := s.substr(i, 1)
			var cw := f.get_string_size(c, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
			draw_string(f, Vector2(ax, pos.y) + Vector2.ONE, c,
				HORIZONTAL_ALIGNMENT_LEFT, -1, size, C_SHADOW)
			ax += cw + CHAR_SPACING
	var ax := pos.x
	for i in s.length():
		var c := s.substr(i, 1)
		var cw := f.get_string_size(c, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		draw_string(f, Vector2(ax, pos.y), c, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
		ax += cw + CHAR_SPACING
