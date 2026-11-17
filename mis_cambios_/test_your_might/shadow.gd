extends Node2D
## Sombra elipsoidal que se dibuja bajo el luchador.
## El nodo se coloca en el pie del luchador (y = 0).

class_name TymShadow

const SQUASH := 0.30
const BASE_RADIUS := 20.0

@export var color := Color(0, 0, 0, 0.38)

var radius := BASE_RADIUS
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	# Un leve "respirado" evita que la sombra se vea estatica.
	var wobble := 1.0 + sin(_t * 2.4) * 0.04
	draw_set_transform(Vector2(0, -2), 0.0, Vector2(1.0, SQUASH))
	draw_circle(Vector2.ZERO, radius * wobble, color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
