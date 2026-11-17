extends Node2D
## Luchador del Test Your Might.
##
## El cuerpo es un Sprite2D (los blobs existentes) y el brazo / aura se
## dibujan a mano en _draw(). El cuerpo usa z_index = -1 para que el puño
## quede por delante; la sombra va en z_index = -2.
##
## El nodo esta en el PIE del luchador: el cuerpo se ancla al suelo
## calculando el rectangulo opaco de la textura, porque los sprites
## traen bastante margen transparente.

class_name TymFighter

const BODY_SCALE := 1.0
const PUNCH_TIME := 0.22
const REACH := 30.0            ## alcance del puño desde el centro del cuerpo
const FIST_HEIGHT := -26.0     ## altura del puño (media vida del luchador)
const TRAIL := 3

## Marcador de posicion: un rectangulo de color mientras no haya sprite.
const BOX_W := 28.0
const BOX_H := 42.0

@export var player_index := 0
@export var accent: Color = Color.WHITE
@export var body_texture: Texture2D

@onready var body: Sprite2D = $Body
@onready var shadow: TymShadow = $Shadow

var facing := 1
var punch_time := 999.0
var aura := 0.0
var falling := false
var celebrate_t := 0.0
## 0..1 mientras el jugador mantiene el boton: el puño se alarga a medida
## que carga, para que se vea cuanto lleva cargado.
var charge := 0.0

var _fall_speed := 0.0
var _fall_spin := 0.0
var _home_scale := Vector2.ONE * BODY_SCALE


func _ready() -> void:
	if body_texture != null:
		body.texture = body_texture
		_anchor_to_ground()
	else:
		# De momento los personajes son un rectangulo de color.
		body.visible = false
		shadow.radius = BOX_W * 0.5
	reset_visual()


## Mueve el sprite para que su parte visible se apoye en el suelo (y = 0)
## y quede centrada de lado a lado, ignorando el margen del PNG.
func _anchor_to_ground() -> void:
	var used := Rect2i()
	if body_texture != null:
		var img := body_texture.get_image()
		if img != null:
			used = img.get_used_rect()
	var tex_size := body_texture.get_size() if body_texture != null else Vector2.ZERO
	if used.size == Vector2i.ZERO:
		used = Rect2i(Vector2i.ZERO, Vector2i(tex_size))
	tex_size = tex_size if tex_size != Vector2.ZERO else Vector2.ONE

	body.offset = Vector2(
		tex_size.x * 0.5 - used.get_center().x,
		tex_size.y * 0.5 - used.end.y
	)
	shadow.radius = used.size.x * BODY_SCALE * 0.5


func reset_visual() -> void:
	falling = false
	celebrate_t = 0.0
	punch_time = 999.0
	aura = 0.0
	_fall_speed = 0.0
	body.position = Vector2.ZERO
	body.rotation = 0.0
	body.scale = _home_scale
	body.modulate = Color.WHITE
	body.flip_h = facing < 0
	shadow.visible = true
	queue_redraw()


## Lanza un puñetazo y devuelve el punto de contacto en coordenadas globales.
func punch() -> Vector2:
	punch_time = 0.0
	return global_position + Vector2(
		facing * (BODY_SCALE * 12.0 + REACH * 0.9),
		FIST_HEIGHT
	)


func celebrate() -> void:
	celebrate_t = 0.001
	aura = 1.0


func start_fall(spin := 2.4) -> void:
	falling = true
	celebrate_t = 0.0
	aura = 0.0
	_fall_speed = 40.0
	_fall_spin = spin
	shadow.visible = false


func _process(delta: float) -> void:
	punch_time += delta

	if falling:
		_fall_speed += 900.0 * delta
		position.y += _fall_speed * delta
		body.rotation += _fall_spin * delta
		body.modulate.a = maxf(0.0, body.modulate.a - delta * 0.55)
		queue_redraw()
		return

	var e := extend()
	var hop := 0.0
	if celebrate_t > 0.0:
		celebrate_t += delta
		hop = absf(sin(celebrate_t * 9.0)) * 5.0
	elif aura > 0.0:
		aura = maxf(0.0, aura - delta * 1.5)

	body.position = Vector2(facing * e * 6.0, -hop)
	var stretch := 1.0 + e * 0.22
	body.scale = Vector2(_home_scale.x * stretch, _home_scale.y / stretch)
	queue_redraw()


## 0 -> 1 -> 0 durante el puñetazo.
func extend() -> float:
	if punch_time >= PUNCH_TIME:
		return 0.0
	return sin(clampf(punch_time / PUNCH_TIME, 0.0, 1.0) * PI)


func _draw() -> void:
	# Rectangulo de marcador cuando no hay sprite.
	if body_texture == null:
		var e0 := maxf(extend(), charge)
		var bx := Vector2(-BOX_W * 0.5 + facing * e0 * 5.0, -BOX_H)
		var r := Rect2(bx, Vector2(BOX_W, BOX_H))
		draw_rect(r, accent)
		draw_rect(Rect2(r.position, Vector2(BOX_W, 3)), accent.lightened(0.35))
		draw_rect(r, accent.darkened(0.5), false, 1.0)
		# Ojos, para saber hacia donde mira.
		var ex := facing * 2.0
		draw_rect(Rect2(r.position.x + BOX_W * 0.5 + ex - 5.0, r.position.y + 13.0, 3, 4),
			Color(0.1, 0.06, 0.1))
		draw_rect(Rect2(r.position.x + BOX_W * 0.5 + ex + 2.0, r.position.y + 13.0, 3, 4),
			Color(0.1, 0.06, 0.1))

	# Aura de empuje.
	if aura > 0.01:
		var c := Vector2(0, FIST_HEIGHT)
		draw_circle(c, 20.0 + 8.0 * aura, Color(accent.r, accent.g, accent.b, 0.16 * aura))
		draw_arc(c, 24.0 + 9.0 * aura, 0.0, TAU, 28,
			Color(accent.r, accent.g, accent.b, 0.55 * aura), 1.0, false)

	# El puño sale o se queda extendido segun se este cargando.
	var e := maxf(extend(), charge)
	if e > 0.01:
		_fist(e)


## Dibuja el puño a una extension dada (0 = recogido, 1 = al maximo).
func _fist(reach_t: float) -> void:
	# Estela del brazo.
	for i in range(TRAIL, 0, -1):
		var t := 1.0 - float(i) / float(TRAIL + 1)
		var x := facing * (9.0 + reach_t * REACH - i * 5.0 * reach_t)
		draw_circle(
			Vector2(x, FIST_HEIGHT),
			(4.0 + 2.5 * reach_t) * (0.55 + 0.45 * t),
			Color(accent.r, accent.g, accent.b, 0.22 * reach_t * t)
		)

	# Puño.
	var px := facing * (9.0 + reach_t * REACH)
	var pr := 3.5 + 1.8 * reach_t
	draw_circle(Vector2(px, FIST_HEIGHT), pr + 1.0, Color(0, 0, 0, 0.55))
	draw_circle(Vector2(px, FIST_HEIGHT), pr, accent)
	draw_circle(Vector2(px - facing * 1.0, FIST_HEIGHT - 1.0), pr * 0.45,
		Color(1, 1, 1, 0.85))