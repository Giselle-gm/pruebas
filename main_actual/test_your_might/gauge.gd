extends Node2D

## Medidor vertical que hay al lado de cada personaje. Se llena martilleando
## y lleva marcado el punto a superar para romper el bloque.

class_name TymGauge
var _spacing_set := false

const WIDTH := 11.0
const HEIGHT := 86.0
## La misma fuente pixel del menu del proyecto.
const FONT := preload("res://pixel-comic-sans-undertale-sans-font.ttf")

@export var player_index := 0
@export var accent: Color = Color.WHITE

var value := 0.0          ## carga actual
var max_value := 100.0    ## tope de la barra
var threshold := 45.0
var flash := 0.0          ## destello al golpear
var flash_ok := false
var _t := 0.0


func _ready() -> void:
	_t = randf() * 4.0


func _process(delta: float) -> void:
	_t += delta
	flash = maxf(0.0, flash - delta * 2.5)
	queue_redraw()


func _draw() -> void:
	if not _spacing_set:
		_spacing_set = true
		FONT.set_extra_spacing(0, 3, 1)
	var r := Rect2(0, -HEIGHT, WIDTH, HEIGHT)
	var scale_max := maxf(1.0, max_value)

	# Fondo y marco.
	draw_rect(r.grow(2), Color(0.06, 0.03, 0.08, 0.85))
	draw_rect(r, Color("2c1430"))

	# Relleno desde abajo.
	var ratio := clampf(value / scale_max, 0.0, 1.0)
	var fill := HEIGHT * ratio
	var ready := value >= threshold

	if fill > 0.0:
		var col := accent
		if ready:
			col = Color("ffd45e")          # ya llega: color de "listo"
			if flash > 0.0:
				col = col.lerp(Color.WHITE, flash * 0.6)
		elif flash > 0.0 and not flash_ok:
			col = col.lerp(Color("ff5c5c"), flash * 0.6)
		draw_rect(Rect2(r.position.x, r.end.y - fill, WIDTH, fill), col)
		draw_rect(Rect2(r.position.x, r.end.y - fill, WIDTH, 2), col.lightened(0.4))

	# Linea del umbral: el toque tiene que caer por encima.
	var ty := r.end.y - HEIGHT * clampf(threshold / scale_max, 0.0, 1.0)
	var mark := Color("ffe08a") if ready else Color("ff8fa8")
	draw_rect(Rect2(r.position.x - 3, ty, WIDTH + 6, 1), mark)
	draw_rect(Rect2(r.position.x - 4, ty - 1, 2, 3), mark)

	draw_rect(r, Color("8c3a72"), false, 1.0)

	# Lectura del valor ARRIBA de la barra: con la fuente pixel tres digitos
	# no caben dentro de 11 px y se salian por los lados.
	var f: Font = FONT
	var txt := "%d" % int(value)
	# Separacion de un px entre digitos: con la fuente pixel sin eso
	# quedan "pegados" y se lee mal.
	var w := 0.0
	for i in txt.length():
		w += f.get_string_size(txt.substr(i, 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		if i < txt.length() - 1:
			w += 1.0
	var x0 := WIDTH * 0.5 - w * 0.5
	var ax := x0
	var top := -HEIGHT - 4.0
	var is_ready := value >= threshold
	var col := Color("ffeede") if is_ready else Color("9c7a96")
	for i in txt.length():
		var c := txt.substr(i, 1)
		var cw := f.get_string_size(c, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		draw_string(f, Vector2(ax, top), c,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0, 0, 0, 0.85))
		draw_string(f, Vector2(ax, top - 1), c,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)
		ax += cw + 1.0
