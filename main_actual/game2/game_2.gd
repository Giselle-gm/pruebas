extends Node2D

const EndScreenScript := preload("res://end_screen.gd")

enum GameState {
	PREPARATION,
	PLAYING,
	GAME_OVER
}

const MENU_PATH: String = "res://menu.tscn"

@export_group("Reglas de Juego")
@export var max_attempts: int = 5
@export var tolerance_perfect: float = 30.0
@export var tolerance_good: float = 70.0

@export_group("Tiempos y Velocidad")
@export var car_speed: float = 850.0
@export var prep_duration: float = 5.0
@export var freeze_duration: float = 1.0
@export var min_interval: float = 5.0
@export var max_interval: float = 8.0

@onready var car: Sprite2D = $Car
@onready var frame_target: Sprite2D = $FrameTarget
@onready var road: Sprite2D = $Road
@onready var flash: ColorRect = $Flash
@onready var dim_overlay: ColorRect = $HUD/DimOverlay
@onready var instruction_label: Label = $HUD/InstructionLabel
@onready var result_label: Label = $HUD/ResultLabel
@onready var score_label: Label = $HUD/ScoreLabel
@onready var attempts_label: Label = $HUD/AttemptsLabel

# Referencias a los nodos AudioStreamPlayer en el árbol de escena
@onready var car_audio: AudioStreamPlayer = $CarAudio
@onready var camera_audio: AudioStreamPlayer = $CameraAudio

var current_state: GameState = GameState.PREPARATION
var prep_timer: float = 0.0

var car_active: bool = false
var photo_taken: bool = false
var score: int = 0
var attempts_left: int = 0

var screen_width: float = 0.0
var car_width: float = 100.0

func _ready() -> void:
	randomize()
	
	var viewport_rect: Rect2 = get_viewport_rect()
	screen_width = viewport_rect.size.x
	
	if car.texture:
		car_width = car.texture.get_width() * abs(car.scale.x)
	
	car.position.x = -(car_width / 2.0)
	car.visible = false
	
	dim_overlay.visible = true
	dim_overlay.modulate.a = 1.0
	
	instruction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	instruction_label.set_deferred("size", Vector2(screen_width * 0.8, 120.0))
	instruction_label.set_deferred("position", Vector2(screen_width * 0.1, 40.0))
	
	attempts_left = max_attempts
	result_label.text = ""
	score_label.text = "Puntos: 0"
	update_attempts_ui()
	flash.modulate.a = 0.0
	
	current_state = GameState.PREPARATION
	prep_timer = prep_duration

func _process(delta: float) -> void:
	match current_state:
		GameState.PREPARATION:
			process_preparation(delta)
		GameState.PLAYING:
			process_gameplay(delta)

func process_preparation(delta: float) -> void:
	prep_timer -= delta
	var seconds_left: int = int(ceil(prep_timer))
	
	instruction_label.text = "QUE NO ESCAPE!\nPresiona [Z] para fotografiar el auto dentro del marco.\nTienes " + str(max_attempts) + " intentos.\nIniciando en: " + str(seconds_left) + " s"
	
	if prep_timer <= 0.0:
		current_state = GameState.PLAYING
		instruction_label.text = ""
		
		var tween: Tween = create_tween()
		tween.tween_property(dim_overlay, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		
		wait_and_respawn()

func process_gameplay(delta: float) -> void:
	if car_active:
		car.position.x += car_speed * delta
		
		var despawn_x: float = screen_width + (car_width / 2.0)
		if car.position.x > despawn_x:
			car_active = false
			car_audio.stop()
			if not photo_taken:
				evaluate_miss()
			
			attempts_left -= 1
			update_attempts_ui()
			check_game_flow()

func _unhandled_input(event: InputEvent) -> void:
	# En GAME_OVER las teclas las lleva la pantalla final comun.
	if current_state != GameState.GAME_OVER and event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file(MENU_PATH)
		return
	
	var is_z_pressed: bool = false
	if event.is_action_pressed("take_photo"):
		is_z_pressed = true
	elif event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_Z or event.physical_keycode == KEY_Z:
			is_z_pressed = true
			
	if is_z_pressed and current_state == GameState.PLAYING and car_active and not photo_taken:
		take_photo()

func spawn_car() -> void:
	car.position.x = -(car_width / 2.0)
	car.visible = true
	photo_taken = false
	car_active = true
	car_audio.play()

func take_photo() -> void:
	photo_taken = true
	car_active = false
	
	# Se reproduce el sonido del obturador sin cortar el audio del auto
	camera_audio.play()
	
	trigger_flash()
	
	var car_rect: Rect2 = get_sprite_rect(car)
	var target_rect: Rect2 = get_sprite_rect(frame_target)
	
	if not target_rect.intersects(car_rect):
		result_label.text = "Fuera de Cuadro"
	else:
		var car_center_x: float = get_sprite_center_x(car)
		var target_center_x: float = get_sprite_center_x(frame_target)
		var delta_x: float = abs(car_center_x - target_center_x)
		
		if delta_x <= tolerance_perfect:
			result_label.text = "Perfecto!"
			score += 100
		elif delta_x <= tolerance_good:
			result_label.text = "Bien!"
			score += 50
		else:
			result_label.text = "Casi"
			score += 20
	
	score_label.text = "Puntos: " + str(score)
	
	attempts_left -= 1
	update_attempts_ui()
	
	# Mantiene el fotograma congelado con el sonido del auto activo
	await get_tree().create_timer(freeze_duration).timeout
	
	# El sonido se detiene al mismo tiempo que desaparece el auto
	car_audio.stop()
	car.visible = false
	car.position.x = -(car_width / 2.0)
	
	check_game_flow()

func evaluate_miss() -> void:
	result_label.text = "Fallaste!"

func check_game_flow() -> void:
	if attempts_left <= 0:
		trigger_game_over()
	else:
		wait_and_respawn()

func wait_and_respawn() -> void:
	var random_delay: float = randf_range(min_interval, max_interval)
	await get_tree().create_timer(random_delay).timeout
	
	if current_state == GameState.PLAYING:
		result_label.text = ""
		spawn_car()

func trigger_game_over() -> void:
	current_state = GameState.GAME_OVER

	var tween: Tween = create_tween()
	tween.tween_property(dim_overlay, "modulate:a", 0.7, 0.5)

	# Mismo final que los otros dos minijuegos.
	instruction_label.visible = false
	result_label.visible = false
	if score_label != null:
		score_label.visible = false
	EndScreenScript.spawn(self, "FIN DEL JUEGO", "%d PUNTOS" % score, Color("3ea6ff"))

func update_attempts_ui() -> void:
	attempts_label.text = str(attempts_left) + "/5"

func trigger_flash() -> void:
	flash.modulate.a = 0.85
	var tween: Tween = create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func get_sprite_center_x(sprite: Sprite2D) -> float:
	if sprite.centered:
		return sprite.global_position.x + (sprite.offset.x * sprite.scale.x)
	else:
		var width: float = sprite.texture.get_width() * sprite.scale.x if sprite.texture else 0.0
		return sprite.global_position.x + (width / 2.0)

func get_sprite_rect(sprite: Sprite2D) -> Rect2:
	if sprite.texture == null:
		return Rect2(sprite.global_position, Vector2.ZERO)
	
	var size: Vector2 = sprite.texture.get_size() * sprite.scale.abs()
	var top_left: Vector2 = sprite.global_position
	
	if sprite.centered:
		top_left -= size / 2.0
	else:
		top_left += sprite.offset * sprite.scale
		
	return Rect2(top_left, size)
