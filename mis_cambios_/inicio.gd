extends Control

const MENU_PATH := "res://menu.tscn"
const LOGIN_PATH := "res://login/login.tscn"

@onready var boton_login: Button = $VBoxContainer/ButtonLogin
@onready var boton_invitado: Button = $VBoxContainer/ButtonInvitado


func _ready() -> void:
	boton_login.pressed.connect(_on_login_pressed)
	boton_invitado.pressed.connect(_on_invitado_pressed)

func _on_login_pressed() -> void:
	get_tree().change_scene_to_file(LOGIN_PATH)

func _on_invitado_pressed() -> void:
	GameSession.iniciar_como_invitado()
	get_tree().change_scene_to_file(MENU_PATH)
