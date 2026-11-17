extends Node2D

const EndScreenScript := preload("res://end_screen.gd")

enum RoundState {
	WAITING,
	CAN_SHOOT,
	RESULT,
	GAME_OVER,
}

const MIN_WAIT_TIME := 3.0
const MAX_WAIT_TIME := 6.0

## "Preparense!" se ve un momento y luego se apaga. Cuando por fin sale
## "DISPAREN!" la pantalla esta limpia y el aviso canta mucho mas.
const PREPARE_HOLD := 0.7
const PREPARE_FADE := 0.6

const MESSAGE_COLOR := Color(1, 1, 1, 1)
const SIGNAL_COLOR := Color("ffd45e")
const MESSAGE_SIZE := 12
const SIGNAL_SIZE := 20

## Volumen del viento de fondo (dB).
const WIND_DB := -14.0

@onready var wait_timer: Timer = $WaitTimer
@onready var message_label: Label = $MessageLabel
@onready var gun: AudioStreamPlayer = $AudioStreamPlayer
@onready var wind: AudioStreamPlayer = $WindAmbience

var round_state: RoundState = RoundState.WAITING
var signal_appeared_at_msec := 0

## Serie elegida en el menu de DRAW: se juega al mejor de 3 o de 5.
var best_of := 3
var wins_needed := 2
var wins := [0, 0]

var _msg_tween: Tween


func _ready() -> void:
	best_of = 5 if GameConfig.draw_best_of == 5 else 3
	wins_needed = int(ceil(best_of * 0.5))
	_start_wind()
	start_round(0)


## Viento de ambiente en bucle. El import ya lo trae en loop; de todos
## modos se reengancha al terminar por si el recurso se importa sin el.
func _start_wind() -> void:
	if wind.stream == null:
		return
	if wind.stream is AudioStreamWAV:
		var w := wind.stream as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(w.get_length() * w.mix_rate)
	wind.volume_db = WIND_DB
	if not wind.playing:
		wind.play()
	if not wind.finished.is_connected(_start_wind):
		wind.finished.connect(_start_wind)


func _unhandled_input(event: InputEvent) -> void:
	var player := _get_player_from_event(event)

	# En GAME_OVER las teclas las lleva la pantalla final comun.
	if round_state == RoundState.RESULT and Input.is_action_just_pressed("NewGame"):
		start_round(1)
		get_viewport().set_input_as_handled()
		return

	if player == 0 or player == 3:
		return

	if round_state == RoundState.WAITING:
		gun.play()
		_finish_early_shot(player)
	elif round_state == RoundState.CAN_SHOOT:
		gun.play()
		_finish_valid_shot(player)

	get_viewport().set_input_as_handled()


func start_round(setter: int) -> void:
	# setter == 0 arranca la partida; setter == 1 pasa a la siguiente ronda.
	if setter == 0:
		wins = [0, 0]

	$Player1.texture = load("res://Game1/player1-v2.png")
	$Player2.texture = load("res://Game1/player2-v2.png")

	round_state = RoundState.WAITING
	signal_appeared_at_msec = 0
	wait_timer.stop()
	_show_prepare()
	wait_timer.start(randf_range(MIN_WAIT_TIME, MAX_WAIT_TIME))


func _on_wait_timer_timeout() -> void:
	# Ignore a timeout left over from a round that already ended.
	if round_state != RoundState.WAITING:
		return

	round_state = RoundState.CAN_SHOOT
	signal_appeared_at_msec = Time.get_ticks_msec()
	if _msg_tween != null:
		_msg_tween.kill()
	_set_message("DISPAREN!", SIGNAL_COLOR, SIGNAL_SIZE)
	_punch_message()


func _get_player_from_event(event: InputEvent) -> int:
	if event.is_action_pressed("NewGame", false):
		return 3
	if event.is_action_pressed("Action1", false):
		return 1
	if event.is_action_pressed("Action2", false):
		return 2
	return 0


func _finish_early_shot(player: int) -> void:
	round_state = RoundState.RESULT
	wait_timer.stop()
	if _msg_tween != null:
		_msg_tween.kill()

	var winner := 2 if player == 1 else 1
	if player == 1:
		$Player1.texture = load("res://Game1/player1-v3.png")
	else:
		$Player2.texture = load("res://Game1/player2-v3.png")

	_add_win(winner)
	if _match_over(winner):
		game_over(winner)
		return

	_set_message(
		("Jugador %d disparo antes - Jugador %d gana (%d-%d)\n"
		+ "Espacio para la siguiente ronda") % [player, winner, wins[0], wins[1]],
		MESSAGE_COLOR, MESSAGE_SIZE
	)


func _finish_valid_shot(player: int) -> void:
	# Lock the result before updating the UI so no later event can also win.
	round_state = RoundState.RESULT
	if _msg_tween != null:
		_msg_tween.kill()

	if player == 1:
		$Player1.texture = load("res://Game1/player1-v3.png")
	else:
		$Player2.texture = load("res://Game1/player2-v3.png")

	_add_win(player)
	if _match_over(player):
		game_over(player)
		return

	var reaction_time := Time.get_ticks_msec() - signal_appeared_at_msec
	_set_message(
		("Jugador %d gana - %d ms (%d-%d)\n"
		+ "Espacio para la siguiente ronda") % [player, reaction_time, wins[0], wins[1]],
		MESSAGE_COLOR, MESSAGE_SIZE
	)


## Suma la victoria de la ronda. El marcador se muestra en el texto.
func _add_win(winner: int) -> void:
	wins[winner - 1] += 1


func _match_over(winner: int) -> bool:
	return wins[winner - 1] >= wins_needed


func game_over(winner: int) -> void:
	round_state = RoundState.GAME_OVER
	message_label.visible = false
	if _msg_tween != null:
		_msg_tween.kill()

	EndScreenScript.spawn(self, "J%d GANA" % winner,
		"AL MEJOR DE %d  (%d-%d)" % [best_of, wins[0], wins[1]],
		Color("ff4d6d") if winner == 1 else Color("3ea6ff"))


# --- mensajes ------------------------------------------------------------

## Muestra un mensaje a plena opacidad, con su color y tamano.
func _set_message(text: String, color: Color, size: int) -> void:
	message_label.text = text
	message_label.modulate.a = 1.0
	message_label.scale = Vector2.ONE
	message_label.add_theme_color_override("font_color", color)
	message_label.add_theme_font_size_override("font_size", size)


## "Preparense!" aparece y se desvanece: la espera se hace en silencio
## visual y el DISPAREN! posterior destaca mucho mas.
func _show_prepare() -> void:
	if _msg_tween != null:
		_msg_tween.kill()
	_set_message("Preparense!", MESSAGE_COLOR, MESSAGE_SIZE)
	_msg_tween = create_tween()
	_msg_tween.tween_interval(PREPARE_HOLD)
	_msg_tween.tween_property(message_label, "modulate:a", 0.0, PREPARE_FADE)


## Pequeno golpe de escala para que la senal de disparo no pase inadvertida.
func _punch_message() -> void:
	message_label.pivot_offset = message_label.size * 0.5
	message_label.scale = Vector2(1.3, 1.3)
	create_tween().tween_property(message_label, "scale", Vector2.ONE, 0.16) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
