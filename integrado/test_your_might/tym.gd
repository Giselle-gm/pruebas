extends Node2D
## TEST YOUR MIGHT - el minijuego del arcade de Mortal Kombat.
##
## Un boton por jugador (Z el de J1, M el de J2) y a SPAMEAR. Cada toque
## sube el medidor, pero la barra BAJA sola: hay que machacar sin parar.
## El bloque no cede en cuanto tocas la linea: hay que MANTENER la carga
## por encima del umbral un tiempo, y cada bloque dura mas que el anterior.
##
## Hay cinco bloques de dureza creciente. Gana quien rompa los cinco.

const NUM_PLAYERS := 2

enum Phase {
	IDLE,
	INTRO,
	FIGHT,
	MATCH_END,
}

# --- carga ---
const GAUGE_MAX := 110.0
const TAP_GAIN := 7.0           ## lo que sube la barra por toque
const GAUGE_DRAIN := 32.0       ## lo que baja sola
## Por debajo de este ritmo (~4,6/s) la barra no sube nunca.
const MIN_RATE := GAUGE_DRAIN / TAP_GAIN

# --- partida ---
const INTRO_TIME := 2.2
const MATCH_TIME := 90.0

# --- escenario ---
const FLOOR_Y := 136.0
const BLOCK_X := [112.0, 208.0]
const FIGHTER_X := [64.0, 256.0]
const GAUGE_X := [18.0, 302.0]

## Las acciones que ya usaba el proyecto: Z para J1 y M para J2.
const BUTTON_ACTIONS := ["Action1", "Action2"]
const PLAYER_COLORS := [Color("ff4d6d"), Color("3ea6ff")]
const EndScreenScript := preload("res://end_screen.gd")

@onready var world: TymShake = $World
@onready var arena: TymArena = $World/Arena
@onready var blocks: Array[TymBlock] = [$World/Blocks/Block1, $World/Blocks/Block2]
@onready var gauges: Array[TymGauge] = [$World/Gauges/Gauge1, $World/Gauges/Gauge2]
@onready var fighters: Array[TymFighter] = [$World/Fighters/P1, $World/Fighters/P2]
@onready var fx: TymFx = $World/FX
@onready var hud: TymHud = $HUD/Hud
@onready var sfx: TymSfx = $Sfx

var phase := Phase.IDLE
var phase_time := 0.0
var time_left := MATCH_TIME
var match_winner := -1

var gauge: Array[float] = [0.0, 0.0]   ## carga (0..GAUGE_MAX)
var was_press: Array[float] = [0.0, 0.0]  ## presion del frame anterior
var tier: Array[int] = [0, 0]          ## bloque actual (0..4)
var broken: Array[int] = [0, 0]        ## bloques rotos
var hits: Array[int] = [0, 0]          ## bloques cedidos
var strikes: Array[int] = [0, 0]       ## toques
var last_flash: Array[float] = [0.0, 0.0]
var last_ok: Array[bool] = [false, false]
var resultados_registrados := false


func _ready() -> void:
	GameSession.iniciar_partida("test_your_might")
	for i in NUM_PLAYERS:
		fighters[i].facing = 1 if i == 0 else -1
		fighters[i].position = Vector2(FIGHTER_X[i], FLOOR_Y)
		blocks[i].position = Vector2(BLOCK_X[i], FLOOR_Y)
		gauges[i].position = Vector2(GAUGE_X[i], FLOOR_Y - 2.0)
		gauges[i].accent = PLAYER_COLORS[i]
		gauges[i].max_value = GAUGE_MAX
	arena.bag_visible = false
	# Corto a proposito: la linea de abajo son 320 px de ancho.
	hud.hint = "J1: Z    J2: M    ESC: MENU"
	_enter(Phase.IDLE)


# --- entrada -------------------------------------------------------------

func _process(delta: float) -> void:
	phase_time += delta

	if phase == Phase.FIGHT:
		_tick_taps()
		_tick_fight(delta)
	else:
		fighters[0].charge = 0.0
		fighters[1].charge = 0.0

	match phase:
		Phase.IDLE:
			if phase_time > 0.3:
				_start_match()
		Phase.INTRO:
			if phase_time > INTRO_TIME:
				_enter(Phase.FIGHT)
		Phase.MATCH_END:
			pass

	_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	# En MATCH_END las teclas las lleva la pantalla final comun.
	if phase == Phase.MATCH_END:
		return
	if event.is_action_pressed("ui_cancel"):
		get_tree().paused = false
		get_tree().change_scene_to_file("res://menu.tscn")


## Un boton a spam: cada toque sube la barra un poco.
func _tick_taps() -> void:
	for i in NUM_PLAYERS:
		if not Input.is_action_just_pressed(BUTTON_ACTIONS[i]):
			continue
		strikes[i] += 1
		gauge[i] = minf(GAUGE_MAX, gauge[i] + TAP_GAIN)
		fighters[i].punch()
		var c: Vector2 = fighters[i].punch()
		if blocks[i].press <= 0.0:
			fx.spark(c, PLAYER_COLORS[i], 2, 40.0)


# --- fases ---------------------------------------------------------------

func _enter(p: int) -> void:
	phase = p
	phase_time = 0.0
	match p:
		Phase.INTRO:
			hud.show_banner("TEST YOUR MIGHT",
				"ROMPE LOS %d BLOQUES" % TymBlock.TIERS.size(), INTRO_TIME)
			sfx.play("bell")
		Phase.FIGHT:
			hud.clear_banner()
		Phase.MATCH_END:
			hud.clear_banner()


func _start_match() -> void:
	time_left = MATCH_TIME
	match_winner = -1
	for i in NUM_PLAYERS:
		gauge[i] = 0.0
		tier[i] = 0
		broken[i] = 0
		hits[i] = 0
		strikes[i] = 0
		last_flash[i] = 0.0
		last_ok[i] = false
		was_press[i] = 0.0
		fighters[i].reset_visual()
		fighters[i].charge = 0.0
		blocks[i].setup(0, i)
		gauges[i].threshold = blocks[i].threshold()
	fx.clear()
	_enter(Phase.INTRO)


func _tick_fight(delta: float) -> void:
	time_left -= delta

	for i in NUM_PLAYERS:
		last_flash[i] = maxf(0.0, last_flash[i] - delta * 2.0)
		# La barra baja sola: hay que spamear mas rapido que esto.
		gauge[i] = maxf(0.0, gauge[i] - GAUGE_DRAIN * delta)

		gauges[i].value = gauge[i]
		gauges[i].flash = last_flash[i]
		gauges[i].flash_ok = last_ok[i]
		fighters[i].charge = gauge[i] / GAUGE_MAX

		# El bloque cede solo si aguantamos la carga encima del tiempo pedido.
		if blocks[i].press_tick(gauge[i], delta):
			_break_block(i)
		elif was_press[i] > 0.0 and blocks[i].press <= 0.0:
			# Se le ha escapado la carga y ha perdido la presion entera.
			last_ok[i] = false
			last_flash[i] = 1.0
			world.shake(1.0)
			fx.shock(blocks[i].global_position + Vector2(0, -32),
				Color("ff8fa8"), 16.0, 0.25)
			sfx.play("bounce")
		was_press[i] = blocks[i].press

	if time_left <= 0.0:
		_win_by_progress()


func _break_block(i: int) -> void:
	hits[i] += 1
	broken[i] += 1
	last_flash[i] = 1.0
	last_ok[i] = true
	# Cada bloque empieza de cero: la carga que sobrara no se arrastra.
	gauge[i] = 0.0
	fighters[i].charge = 0.0
	# Y se olvida la presion anterior. Si no, el frame siguiente ve que ha
	# caido a cero y canta un fallo falso encima del BRAKE!!.
	was_press[i] = 0.0
	var b := blocks[i]
	var contact := b.global_position + Vector2(0, -32)
	fx.spark(contact, b.color(), 26, 165.0)
	fx.shock(contact, b.color(), 34.0, 0.45)
	fx.dust(Vector2(b.global_position.x, FLOOR_Y), 10)
	sfx.play("break")
	world.shake(5.0)

	tier[i] += 1
	if tier[i] >= TymBlock.TIERS.size():
		_win_match(i)
		return
	blocks[i].setup(tier[i], i)
	gauges[i].threshold = blocks[i].threshold()


## La pantalla final vive en su propia escena (end_screen.tscn) para
## que Draw y Take puedan usar la misma sin copiar codigo.
func _show_end(title: String, detail: String, accent: Color) -> void:
	hud.visible = false
	if not resultados_registrados:
		resultados_registrados = true
		GameSession.guardar_resultado_local("test_your_might", broken[0], 1)
		GameSession.guardar_resultado_local("test_your_might", broken[1], 2)
	EndScreenScript.spawn(self, title, detail, accent)


func _win_match(winner: int) -> void:
	match_winner = winner
	fighters[winner].celebrate()
	sfx.play("win")
	_show_end("J%d GANA" % (winner + 1),
		"%d DE %d BLOQUES" % [broken[winner], TymBlock.TIERS.size()],
		PLAYER_COLORS[winner])
	_enter(Phase.MATCH_END)


## Si se acaba el tiempo gana quien haya roto mas bloques.
func _win_by_progress() -> void:
	if broken[0] != broken[1]:
		_win_match(0 if broken[0] > broken[1] else 1)
		return
	_show_end("EMPATE", "SE ACABO EL TIEMPO", Color("ffd45e"))
	_enter(Phase.MATCH_END)


# --- HUD -----------------------------------------------------------------

func _update_hud() -> void:
	hud.total_blocks = TymBlock.TIERS.size()
	hud.show_time = phase == Phase.FIGHT
	hud.time_left = maxf(0.0, time_left)
	hud.time_max = MATCH_TIME

	for i in NUM_PLAYERS:
		hud.set_player(i,
			blocks[i].block_name(), tier[i] + 1, broken[i],
			blocks[i].threshold(), blocks[i].hold_time(), blocks[i].press,
			last_flash[i], last_ok[i])

	hud.tag = "SPAMEA Y MANTEN LA BARRA ARRIBA" if phase == Phase.FIGHT else ""