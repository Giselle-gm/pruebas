extends Node2D
## Escenario: el piso del ring y la bolsa de golpeo.
## El nodo se coloca en (160, 136), justo sobre la linea del piso.

class_name TymArena

const FLOOR_THICK := 18.0
const LEFT := -120.0          ## x = 40 en pantalla
const RIGHT := 120.0         ## x = 280 en pantalla

## Bolsa: cuelga del borde superior y ocupa el centro del ring.
const BAG_ANCHOR := -136.0   ## donde se ancla la correa (borde superior)
const BAG_CENTER := -30.0    ## altura del centro de la bolsa
const BAG_W := 26.0
const BAG_H := 42.0

const C_FLOOR := Color("3a1230")
const C_FLOOR_TOP := Color("8c3a72")
const C_FLOOR_EDGE := Color("180a16")
const C_ACCENT := Color("ff5c7a")
const C_POST := Color("5a1c48")
const C_BAG := Color("d94f6e")
const C_BAG_HI := Color("ffd0c0")
const C_BAG_DARK := Color("6d1f3d")

var bag_visible := true
var bag_offset := 0.0       ## desplazamiento lateral de la bolsa

var _squash := 0.0
var _swing := 0.0


func _process(delta: float) -> void:
	if _squash > 0.0 or _swing != 0.0:
		_squash = move_toward(_squash, 0.0, delta * 4.0)
		_swing = move_toward(_swing, 0.0, delta * 6.0)
		queue_redraw()


## Golpe recibido por la bolsa. from_side: -1 si la pegó el de la izquierda.
func hit(strength := 1.0, from_side := 0.0) -> void:
	_squash = minf(1.0, _squash + strength)
	_swing = from_side * randf_range(0.6, 1.0)


## Punto de contacto en coordenadas globales.
func bag_contact() -> Vector2:
	return global_position + Vector2(bag_offset, BAG_CENTER)


func _draw() -> void:
	_draw_floor()
	if bag_visible:
		_draw_bag()


func _draw_floor() -> void:
	# Valla oscura bajo el piso para dar profundidad.
	draw_rect(Rect2(LEFT - 16, FLOOR_THICK, (RIGHT - LEFT) + 32, 26), Color("1d0a1a"))

	# Cuerpo de la plataforma.
	draw_rect(Rect2(LEFT, 0, RIGHT - LEFT, FLOOR_THICK), C_FLOOR)
	# Borde superior iluminado.
	draw_rect(Rect2(LEFT, 0, RIGHT - LEFT, 3), C_FLOOR_TOP)
	# Sombra inferior.
	draw_rect(Rect2(LEFT, FLOOR_THICK - 3, RIGHT - LEFT, 3), C_FLOOR_EDGE)

	# Linea de peligro punteada en el borde del ring.
	var x := LEFT + 4.0
	while x < RIGHT - 4.0:
		draw_rect(Rect2(x, 7.0, 4.0, 1.0), C_ACCENT)
		x += 8.0

	# Postes laterales.
	draw_rect(Rect2(LEFT - 8, -14, 8, FLOOR_THICK + 14), C_POST)
	draw_rect(Rect2(RIGHT, -14, 8, FLOOR_THICK + 14), C_POST)
	draw_rect(Rect2(LEFT - 8, -14, 8, 2), C_ACCENT)
	draw_rect(Rect2(RIGHT, -14, 8, 2), C_ACCENT)


func _draw_bag() -> void:
	var x := bag_offset + _swing * 4.0
	var w := BAG_W + _squash * 9.0
	var h := BAG_H - _squash * 15.0
	var top := BAG_CENTER - h * 0.5

	# Correa al techo.
	draw_line(Vector2(x * 0.35, BAG_ANCHOR), Vector2(x, top), C_BAG_DARK, 2.0)
	# Cuerpo de la bolsa.
	draw_rect(Rect2(x - w * 0.5, top, w, h), C_BAG)
	# Luz superior y sombra inferior.
	draw_rect(Rect2(x - w * 0.5, top, w, 4.0), C_BAG_HI)
	draw_rect(Rect2(x - w * 0.5, top + h - 5.0, w, 5.0), C_BAG_DARK)
	# Remache central.
	draw_rect(Rect2(x - 3.0, BAG_CENTER - 3.0, 6.0, 6.0), C_BAG_HI)