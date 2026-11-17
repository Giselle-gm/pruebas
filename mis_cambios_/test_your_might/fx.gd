extends Node2D
## Efectos de impacto dibujados a mano: chispas, polvo y ondas.
## Todas las particulas viven en este unico nodo y se pintan en una sola
## llamada a _draw(), asi el coste es minimo.

class_name TymFx

const SQUARE := 0    ## chispas cuadradas (estetica pixel art)
const RING := 1      ## onda expansiva

var _parts: Array[Dictionary] = []


func _process(delta: float) -> void:
	if _parts.is_empty():
		return
	var i := _parts.size() - 1
	while i >= 0:
		var p := _parts[i]
		p.age += delta
		if p.age >= p.life:
			_parts.remove_at(i)
		else:
			p.pos += p.vel * delta
			p.vel.y += p.gravity * delta
			p.vel.x *= p.drag
		i -= 1
	queue_redraw()


func _draw() -> void:
	for p in _parts:
		var t: float = p.age / p.life
		var alpha := 1.0 - t
		var col := Color(p.color.r, p.color.g, p.color.b, alpha)
		if p.kind == RING:
			draw_arc(p.pos, p.size * (0.25 + t * 0.9), 0.0, TAU, 20, col,
				maxf(1.0, 2.0 * alpha), false)
		else:
			var s: float = p.size * (1.0 - t * 0.55)
			draw_rect(Rect2(p.pos - Vector2(s, s) * 0.5, Vector2(s, s)), col)


## Chispas de impacto que salen radiales y caen por gravedad.
func spark(pos: Vector2, color: Color, amount := 8, speed := 95.0) -> void:
	for i in amount:
		var a := randf() * TAU
		_parts.append({
			pos = pos,
			vel = Vector2(cos(a), sin(a)) * randf_range(speed * 0.35, speed),
			gravity = 280.0,
			drag = 0.93,
			life = randf_range(0.16, 0.32),
			age = 0.0,
			kind = SQUARE,
			color = color,
			size = randf_range(1.5, 3.0),
		})


## Polvo que sube despacio desde el suelo.
func dust(pos: Vector2, color := Color(0.55, 0.3, 0.45), amount := 5) -> void:
	for i in amount:
		_parts.append({
			pos = pos + Vector2(randf_range(-5.0, 5.0), randf_range(-2.0, 1.0)),
			vel = Vector2(randf_range(-16.0, 16.0), randf_range(-28.0, -10.0)),
			gravity = 22.0,
			drag = 0.97,
			life = randf_range(0.3, 0.55),
			age = 0.0,
			kind = SQUARE,
			color = color,
			size = randf_range(1.0, 2.2),
		})


## Onda expansiva de un golpe fuerte o de una caida.
func shock(pos: Vector2, color: Color, radius := 16.0, life := 0.26) -> void:
	_parts.append({
		pos = pos,
		vel = Vector2.ZERO,
		gravity = 0.0,
		drag = 1.0,
		life = life,
		age = 0.0,
		kind = RING,
		color = color,
		size = radius,
	})


func clear() -> void:
	_parts.clear()
	queue_redraw()
