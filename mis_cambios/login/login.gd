extends Control

const MENU_PATH := "res://menu.tscn"
const INICIO_PATH := "res://inicio.tscn"
const REGISTRO_PATH := "res://login/registro.tscn"


@onready var campo_usuario: LineEdit = $VBoxContainer/LineEditUsuario
@onready var campo_password: LineEdit = $VBoxContainer/LineEditPassword
@onready var boton_login: Button = $VBoxContainerButton/ButtonLogin
@onready var boton_registro: Button = $VBoxContainerButton/ButtonRegistro
@onready var boton_volver: Button = $VBoxContainerButton/ButtonVolver
@onready var label_mensaje: Label = $VBoxContainerButton/LabelMensaje


func _ready() -> void:
	boton_login.pressed.connect(_on_login_pressed)
	boton_registro.pressed.connect(_on_registro_pressed)
	boton_volver.pressed.connect(_on_volver_pressed)

	BackendManager.login_completado.connect(_al_completar_login)


func _on_login_pressed() -> void:
	var usuario := campo_usuario.text.strip_edges()
	var password := campo_password.text

	if usuario.is_empty() or password.is_empty():
		label_mensaje.text = "Completa el usuario y la contraseña."
		return

	boton_login.disabled = true
	label_mensaje.text = "Iniciando sesión..."

	BackendManager.iniciar_sesion(usuario, password)

func _al_completar_login(
		exito: bool,
		respuesta: Dictionary
	) -> void:
	boton_login.disabled = false

	if exito:
		print("Nombre en BackendManager: '", BackendManager.nombre_usuario_actual, "'")
		print("Respuesta completa del login: ", respuesta)

		GameSession.iniciar_como_usuario(
			BackendManager.nombre_usuario_actual
			)
		print("Nombre en GameSession: '", GameSession.nombre_jugador, "'")

		label_mensaje.text = "¡Bienvenido!"
		get_tree().change_scene_to_file(MENU_PATH)
	else:
		label_mensaje.text = str(
			respuesta.get("detail",
			respuesta.get("detalle", "No se pudo iniciar sesión."))
		)

func _on_registro_pressed() -> void:
	get_tree().change_scene_to_file(REGISTRO_PATH)

func _on_volver_pressed() -> void:
	get_tree().change_scene_to_file(INICIO_PATH)
