extends Control

const MENU_PATH := "res://menu.tscn"
const INICIO_PATH := "res://inicio.tscn"

@onready var campo_usuario: LineEdit = $VBoxContainer/LineEditUsuario
@onready var campo_password: LineEdit = $VBoxContainer/LineEditPassword
@onready var boton_registro: Button = $VBoxContainerButton/ButtonRegistro
@onready var boton_volver: Button = $VBoxContainerButton/ButtonVolver
@onready var label_mensaje: Label = $VBoxContainerButton/LabelMensaje


func _ready() -> void:
	boton_registro.pressed.connect(_on_registro_pressed)
	boton_volver.pressed.connect(_on_volver_pressed)

	BackendManager.registro_completado.connect(_al_completar_registro)


func _on_registro_pressed() -> void:
	var usuario := campo_usuario.text.strip_edges()
	var password := campo_password.text

	if usuario.is_empty() or password.is_empty():
		label_mensaje.text = "Completa el usuario y la contraseña."
		return

	boton_registro.disabled = true
	label_mensaje.text = "Usuario Registrado."

	BackendManager.registrar_usuario(usuario, password)


func _al_completar_registro(
	exito: bool,
	respuesta: Dictionary
	) -> void:
	boton_registro.disabled = false

	if exito:
		var nombre := BackendManager.nombre_usuario_actual

		GameSession.iniciar_como_usuario(nombre)

		print("Nombre en BackendManager: ", nombre)
		print("Nombre en GameSession: ", GameSession.nombre_jugador)
		print(
			"Token disponible: ",
			not BackendManager.token_usuario.is_empty()
		)

		label_mensaje.text = "¡Bienvenido, " + nombre + "!"
		get_tree().change_scene_to_file(MENU_PATH)
	else:
		label_mensaje.text = str(
			respuesta.get(
				"detail",
				respuesta.get(
					"detalle",
					"No se pudo crear la cuenta."
					)
			)
		)


func _on_volver_pressed() -> void:
	get_tree().change_scene_to_file(INICIO_PATH)
