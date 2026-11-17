extends Node2D

## Bloque destructible del Test Your Might.
##
## Hay cinco bloques de dureza creciente. No basta con tocar la linea: hay
## que MANTENER la carga por encima del umbral un tiempo (hold), que es lo
## que cuesta de verdad. Si la carga baja de la linea, la presion se
## pierde y hay que empezar otra vez.

class_name TymBlock
var _spacing_set := false

const WIDTH := 46.0
const HEIGHT := 56.0
## La misma fuente pixel del menu del proyecto.
const FONT := preload("res://pixel-comic-sans-undertale-sans-font.ttf")

## Los cinco bloques, de menos a mas duro. "threshold" es la linea de la
## barra y "hold" los segundos que hay que aguantarla encima.
const TIERS := [
	{"name": "MADERA", "color": Color("9a6238"), "threshold": 40.0, "hold": 0.9},
	{"name": "PIEDRA", "color": Color("8d8d95"), "threshold": 55.0, "hold": 1.3},
	{"name": "HIERRO", "color": Color("b3b9c7"), "threshold": 70.0, "hold": 1.7},
	{"name": "ACERO", "color": Color("6d7ea8"), "threshold": 84.0, "hold": 2.1},
	{"name": "DIAMANTE", "color": Color("6fe3e0"), "threshold": 96.0, "hold": 2.5},
]

@export var player_index := 0

var tier := 0
var press := 0.0            ## 0..1, presion acumulada sobre el bloque
var shake_t := 0.0
var shake_dir := 0.0
var flash := 0.0
var broken := false

var _debris: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func setup(t: int, idx: int) -> void:
	tier = clampi(t, 0, TIERS.size() - 1)
	player_index = idx
	broken = false
	press = 0.0
	shake_t = 0.0
	flash = 0.0
	_debris.clear()
	queue_redraw()


func info() -> Dictionary:
	return TIERS[tier]


func block_name() -> String:
	return String(TIERS[tier]["name"])


func color() -> Color:
	return TIERS[tier]["color"]


func threshold() -> float:
	return TIERS[tier]["threshold"]


func hold_time() -> float:
	return TIERS[tier]["hold"]


func is_last() -> bool:
	return tier >= TIERS.size() - 1


## Avanza la presion mientras la carga supere el umbral. Devuelve true en
## el frame que el bloque cede.
func press_tick(load: float, delta: float) -> bool:
	if broken:
		return false
	if load < threshold():
		# Suelta la linea: la presion se pierde (mas despacio de lo que sube,
		# para perdonar un fallo puntual sin regalar el bloque).
		press = maxf(0.0, press - delta / maxf(0.1, hold_time() * 0.6))
		if press <= 0.0:
			return false
	else:
		press = minf(1.0, press + delta / maxf(0.1, hold_time()))
		shake_t = maxf(shake_t, 0.35)
		shake_dir = -1.0 if player_index == 0 else 1.0

	if press >= 1.0:
		_blow()
		return true
	queue_redraw()
	return false


func _blow() -> void:
	broken = true
	press = 0.0
	flash = 1.0
	shake_t = 1.0
	shake_dir = -1.0 if player_index == 0 else 1.0
	_rng.seed = tier * 977 + 13
	for i in 14:
		_debris.append({
			"pos": Vector2(randf_range(-WIDTH * 0.4, WIDTH * 0.4),
				randf_range(-HEIGHT * 0.8, -4.0)),
			"vel": Vector2(_rng.randf_range(-70.0, 70.0), _rng.randf_range(-150.0, -50.0)),
			"size": _rng.randf_range(3.0, 8.0),
			"life": _rng.randf_range(0.5, 1.0),
			"age": 0.0,
		})
	queue_redraw()


func _process(delta: float) -> void:
	shake_t = maxf(0.0, shake_t - delta * 4.0)
	flash = maxf(0.0, flash - delta * 3.0)
	if not _debris.is_empty():
		for i in _debris.size():
			var d := _debris[i]
			d.age += delta
			d.pos += d.vel * delta
			d.vel.y += 420.0 * delta
			d.vel.x *= 0.98
		_debris = _debris.filter(func(d): return d.age < d.life)
		queue_redraw()


# --- dibujo --------------------------------------------------------------

func _draw() -> void:
	if not _spacing_set:
		_spacing_set = true
		FONT.set_extra_spacing(0, 3, 1)
	if broken:
		_draw_debris()
		return

	var w := WIDTH
	var h := HEIGHT
	var shake := Vector2(shake_dir * shake_t * 2.5, 0.0)
	var col := color()
	if flash > 0.0:
		col = col.lerp(Color.WHITE, flash * 0.55)
	elif press > 0.0:
		# Mientras lo presionan el bloque se pone blanco del esfuerzo.
		col = col.lerp(Color.WHITE, press * 0.45)

	var r := Rect2(Vector2(-w * 0.5, -h) + shake, Vector2(w, h))
	draw_rect(Rect2(-w * 0.5 + 5, -4, w - 10, 6), Color(0, 0, 0, 0.3))
	draw_rect(r, col)
	draw_rect(Rect2(r.position, Vector2(w, 3)), col.lightened(0.3))
	draw_rect(Rect2(r.position + Vector2(0, h - 3), Vector2(w, 3)), col.darkened(0.45))
	draw_rect(r, col.darkened(0.5), false, 1.0)

	_draw_detail(tier, r, col)

	# Grietas segun la presion: el bloque se resiente cuanto mas lo cargas.
	if press > 0.02:
		_draw_cracks(r, press)

	# Numero de bloque en la cara.
	var label := str(tier + 1)
	var f: Font = FONT
	var fs := 14
	var tw := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var ink := col.darkened(0.55)
	if col.get_luminance() > 0.6:
		ink = Color(0.1, 0.1, 0.15)
	draw_string(f, Vector2(-tw * 0.5, -h * 0.5 + fs * 0.5), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)

	# Nota: el progreso de presion se ve en el propio bloque (blanco del
	# esfuerzo + grietas) y en la barra CEDE del HUD. No se dibuja nada
	# flotando aqui, que antes quedaba suelto en el aire.


## Grietas deterministas que crecen con la presion. Se recortan al bloque:
## antes se leian por debajo de la base.
func _draw_cracks(r: Rect2, wear: float) -> void:
	var col := Color(0, 0, 0, 0.55)
	for i in int(wear * 5.0) + 1:
		var rng := RandomNumberGenerator.new()
		rng.seed = tier * 131 + i * 17
		var px := r.position.x + rng.randf_range(4.0, r.size.x - 4.0)
		var py := r.position.y + rng.randf_range(2.0, r.size.y * 0.45)
		# Largo recortado para no salirse por abajo.
		var room := r.position.y + r.size.y - 2.0 - py
		var len_y := minf(rng.randf_range(4.0, 15.0), maxf(2.0, room))
		draw_line(Vector2(px, py),
			Vector2(px + rng.randf_range(-3.0, 3.0), py + len_y), col, 1.0)


## Detalle segun el material: troncos, piedra, remaches, placas o facetas.
func _draw_detail(tier: int, r: Rect2, col: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = tier * 131 + 5
	match tier:
		0:
			for i in 3:
				var y := r.position.y + r.size.y * (i + 0.5) / 3.0
				draw_rect(Rect2(r.position.x, y - 1, r.size.x, 2), col.darkened(0.4))
				draw_rect(Rect2(r.position.x, y - r.size.y / 12.0, 4, r.size.y / 6.0),
					col.darkened(0.3))
		1:
			for i in 14:
				draw_rect(Rect2(
					r.position.x + rng.randf_range(2, r.size.x - 5),
					r.position.y + rng.randf_range(2, r.size.y - 5),
					rng.randf_range(2, 4), 2), col.darkened(0.28))
		2:
			for p in [Vector2(6, 6), Vector2(r.size.x - 6, 6),
					Vector2(6, r.size.y - 8), Vector2(r.size.x - 6, r.size.y - 8)]:
				draw_rect(Rect2(r.position + p, Vector2(4, 4)), col.darkened(0.3))
		3:
			for i in 2:
				draw_rect(Rect2(r.position.x + 3, r.position.y + r.size.y * (i + 1) * 0.33,
					r.size.x - 6, 2), col.darkened(0.4))
		_:
			for i in 3:
				draw_line(
					Vector2(r.position.x, r.position.y + r.size.y * i / 3.0),
					Vector2(r.position.x + r.size.x, r.position.y + r.size.y * (i + 1) / 3.0),
					Color(1, 1, 1, 0.35), 1.0)


func _draw_debris() -> void:
	var col := color()
	for d in _debris:
		var t: float = d.age / d.life
		var s: float = d.size * (1.0 - t * 0.4)
		var pos: Vector2 = d.pos
		draw_rect(Rect2(pos - Vector2(s, s) * 0.5, Vector2(s, s)),
			Color(col.r, col.g, col.b, 1.0 - t))