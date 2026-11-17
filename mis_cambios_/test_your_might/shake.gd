extends Node2D
## Sacudida de camara barata: el nodo entero vibra y vuelve a su sitio.
## Se coloca en el contenedor "World" para que el fondo vibre tambien,
## mientras el HUD (dentro de un CanvasLayer) se queda quieto.

class_name TymShake

const MAX_OFFSET := 5.0
const DECAY := 9.0

var _amount := 0.0
var _home := Vector2.ZERO


func _ready() -> void:
	_home = position


func shake(amount: float) -> void:
	_amount = minf(MAX_OFFSET, _amount + amount)


func _process(delta: float) -> void:
	if _amount <= 0.02:
		if position != _home:
			position = _home
			_amount = 0.0
		return
	_amount = maxf(0.0, _amount - DECAY * _amount * delta - 0.6 * delta)
	position = _home + Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _amount
