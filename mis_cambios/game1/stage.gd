extends Node2D

const EndScreenScript := preload("res://end_screen.gd")

enum RoundState {
	WAITING,
	CAN_SHOOT,
	RESULT,
	GAME_OVER,
}

const MIN_WAIT_TIME := 5.0
const MAX_WAIT_TIME := 15.0

@onready var wait_timer: Timer = $WaitTimer
@onready var message_label: Label = $MessageLabel
@onready var gun: Node = $AudioStreamPlayer
@onready var jingleEnd: Node = $JingleEnd
@onready var jingleStart: Node = $JingleStart
@onready var wind: Node = $MysteriousWind

var round_state: RoundState = RoundState.WAITING
var signal_appeared_at_msec := 0

var round_counter: int
var round_ind

var game_winner = [0,0,0]

var best_time1 = -1
var best_time2 = -1

func _ready() -> void:
	GameSession.iniciar_partida("draw")
	round_ind = [$"../Round1",$"../Round2",$"../Round3"]
	wind.play()
	start_round(0)


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
		wind.volume_db = -15.0
		gun.play()
		_finish_early_shot(player)
	elif round_state == RoundState.CAN_SHOOT:
		gun.play()
		wind.volume_db = -15.0
		_finish_valid_shot(player)

	get_viewport().set_input_as_handled()

func start_round(setter: int) -> void:
	if setter == 0:
		round_counter = 0
		best_time1 = -1
		best_time2 = -1
	elif setter == 1:
		round_counter += 1
	
	$Player1.texture = load("res://Game1/player1-v2.png")
	$Player2.texture = load("res://Game1/player2-v2.png")
	
	wind.volume_db = -15.0
	jingleStart.play()
	await get_tree().create_timer(2).timeout
	wind.volume_db = 0.0
	
	round_state = RoundState.WAITING
	signal_appeared_at_msec = 0
	message_label.text = "Preparense!"
	wait_timer.start(randf_range(MIN_WAIT_TIME, MAX_WAIT_TIME))


func _on_wait_timer_timeout() -> void:
	# Ignore a timeout left over from a round that already ended.
	if round_state != RoundState.WAITING:
		return

	round_state = RoundState.CAN_SHOOT
	signal_appeared_at_msec = Time.get_ticks_msec()
	message_label.text = "DISPAREN!"


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
	
	var winner
	if player == 1:
		winner = 2
		$Player1.texture = load("res://Game1/player1-v3.png")
	else:
		winner = 1
		$Player2.texture = load("res://Game1/player2-v3.png")
	
	_set_round_indicator(winner)
	message_label.text = (
		"Jugador %d disparo antes - Jugador %d gana\n"
		+ "Presiona Espacio para jugar otra vez"
	) % [player, winner]
	
	check_end()


func _finish_valid_shot(player: int) -> void:
	# Lock the result before updating the UI so no later event can also win.
	_set_round_indicator(player)
	round_state = RoundState.RESULT
	
	if player == 1:
		$Player1.texture = load("res://Game1/player1-v3.png")
	else:
		$Player2.texture = load("res://Game1/player2-v3.png")
	
	var reaction_time := Time.get_ticks_msec() - signal_appeared_at_msec
	
	if player == 1:
		if best_time1 == -1 or reaction_time < best_time1:
			best_time1 = reaction_time
	else:
		if best_time2 == -1 or reaction_time < best_time2:
			best_time2 = reaction_time
			
	message_label.text = (
		"Jugador %d gana - %d ms\n"
		+ "Presiona Espacio para jugar otra vez"
	) % [player, reaction_time]
	
	check_end()


func _set_round_indicator(player: int) -> void:
	if round_counter < round_ind.size():
		game_winner[round_counter] = player
		var player_sprite = "res://Game1/player1.png" if player == 1 else "res://Game1/player2.png"
		round_ind[round_counter].texture = load(player_sprite)
		
		
		
func check_end():
	await get_tree().create_timer(1).timeout
	jingleEnd.play()
	await get_tree().create_timer(1).timeout
	wind.volume_db = 0.0
	
	if round_counter == 1 and game_winner[0] == game_winner[1]:
		game_over(game_winner[0])
		
	if round_counter >= 2:
		game_over(game_winner[2])
		
		
func game_over(winner):
	round_state = RoundState.GAME_OVER
	message_label.visible = false
	if best_time1 >= 0:
		GameSession.guardar_resultado_local("draw", best_time1, 1)
	if best_time2 >= 0:
		GameSession.guardar_resultado_local("draw", best_time2, 2)
	EndScreenScript.spawn(self, "J%d GANA" % winner, "AL MEJOR DE 3",
		Color("ff4d6d") if winner == 1 else Color("3ea6ff"))
