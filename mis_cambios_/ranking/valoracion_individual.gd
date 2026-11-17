
extends Control

const MENU_PATH: String = "res://menu.tscn"
const ICON_ESTRELLA_SELECT = "res://assets/estrella_normal.png"
const ICON_ESTRELLA_VACIA = "res://assets/estrella_vacial.png"


var puntuacion_seleccionada: int = 0
var envio_en_curso: bool = false

#Pregunta 1
@onready var boton1_1: Button = $Panel/VBoxContainer/HBoxPregunta1/HBoxContainerEstrellas/Button1
@onready var boton1_2: Button = $Panel/VBoxContainer/HBoxPregunta1/HBoxContainerEstrellas/Button2
@onready var boton1_3: Button = $Panel/VBoxContainer/HBoxPregunta1/HBoxContainerEstrellas/Button3
@onready var boton1_4: Button = $Panel/VBoxContainer/HBoxPregunta1/HBoxContainerEstrellas/Button4
@onready var boton1_5: Button = $Panel/VBoxContainer/HBoxPregunta1/HBoxContainerEstrellas/Button5

#Pregunta 2
@onready var boton2_1: Button = $Panel/VBoxContainer/HBoxPregunta2/HBoxContainerEstrellas/Button1
@onready var boton2_2: Button = $Panel/VBoxContainer/HBoxPregunta2/HBoxContainerEstrellas/Button2
@onready var boton2_3: Button = $Panel/VBoxContainer/HBoxPregunta2/HBoxContainerEstrellas/Button3
@onready var boton2_4: Button = $Panel/VBoxContainer/HBoxPregunta2/HBoxContainerEstrellas/Button4
@onready var boton2_5: Button = $Panel/VBoxContainer/HBoxPregunta2/HBoxContainerEstrellas/Button5

#Pregunta 3
@onready var comentario: LineEdit = $Panel/VBoxContainer/HBoxPregunta3/LineEditComentario

@onready var boton_enviar: Button = $Panel/VBoxContainer/HBoxContainer/ButtonEnviar
@onready var boton_volver: Button = $Panel/VBoxContainer/HBoxContainer/ButtonVolver

@onready var mensaje_label: Label = $Panel/VBoxContainer/Mensaje

func _ready() -> void:
	
	#Pregunta 1
	boton1_1.pressed.connect(func(): seleccionar_puntuacion(1,1))
	boton1_2.pressed.connect(func(): seleccionar_puntuacion(2,1))
	boton1_3.pressed.connect(func(): seleccionar_puntuacion(3,1))
	boton1_4.pressed.connect(func(): seleccionar_puntuacion(4,1))
	boton1_5.pressed.connect(func(): seleccionar_puntuacion(5,1))
	
	#Pregunta 2
	boton2_1.pressed.connect(func(): seleccionar_puntuacion(1,2))
	boton2_2.pressed.connect(func(): seleccionar_puntuacion(2,2))
	boton2_3.pressed.connect(func(): seleccionar_puntuacion(3,2))
	boton2_4.pressed.connect(func(): seleccionar_puntuacion(4,2))
	boton2_5.pressed.connect(func(): seleccionar_puntuacion(5,2))

	boton_enviar.pressed.connect(_on_enviar_pressed)
	boton_volver.pressed.connect(_on_volver_pressed)

	if not BackendManager.valoracion_completada.is_connected(_al_completar_valoracion):
		BackendManager.valoracion_completada.connect(_al_completar_valoracion)

	actualizar_botones(1)
	actualizar_botones(2)


func seleccionar_puntuacion(puntuacion: int, b: int) -> void:
	if envio_en_curso:
		return

	puntuacion_seleccionada = puntuacion
	actualizar_botones(b)


func actualizar_botones(b: int) -> void:
	var botones : Array[Button] = []
	if b ==1:
		botones = [boton1_1, boton1_2, boton1_3, boton1_4, boton1_5]
	elif b == 2:
		botones = [boton2_1, boton2_2, boton2_3, boton2_4, boton2_5]

	for i in range(botones.size()):
		botones[i].icon = preload(ICON_ESTRELLA_SELECT)  if i < puntuacion_seleccionada else preload(ICON_ESTRELLA_VACIA)
		

func _on_enviar_pressed() -> void:
	if envio_en_curso:
		return

	if puntuacion_seleccionada == 0:
		mensaje_label.text = "Selecciona una puntuación antes de enviar."
		return

	envio_en_curso = true
	boton_enviar.disabled = true
	mensaje_label.text = "Enviando valoración..."
	
	print("Juego: ", GameSession.juego_para_valorar)
	print("ID sesión: ", GameSession.sesion_jugador_id)
	print("Puntuación: ", puntuacion_seleccionada)

	BackendManager.enviar_valoracion(
		GameSession.juego_para_valorar,
		GameSession.sesion_jugador_id,
		puntuacion_seleccionada
	)


func _al_completar_valoracion(
		exito: bool,
		respuesta: Dictionary
	) -> void:

	envio_en_curso = false
	boton_enviar.disabled = false

	if exito:
		mensaje_label.text = str(
			respuesta.get(
				"mensaje",
                "¡Gracias por valorar el juego!"
			)
		)
	else:
		mensaje_label.text = str(
			respuesta.get(
				"detail",
				respuesta.get(
					"detalle",
                    "No se pudo guardar la valoración."
				)
			)
		)


func _on_volver_pressed() -> void:
	get_tree().change_scene_to_file(MENU_PATH)


func _exit_tree() -> void:
	if BackendManager.valoracion_completada.is_connected(_al_completar_valoracion):
		BackendManager.valoracion_completada.disconnect(_al_completar_valoracion)
