extends Control

const MENU_PATH := "res://menu.tscn"
var minijuego_actual := "take"

@onready var titulo_label: Label = $LabelTitulo
@onready var top1_label: RichTextLabel = $Top1_Label
@onready var top2_label: RichTextLabel = $Top2_Label
@onready var top3_label: RichTextLabel = $Top3_Label

@onready var ranking_label: RichTextLabel = $VBoxContainer/RichTextLabelRanking
@onready var mensaje_label: Label = $VBoxContainer/LabelMensaje
@onready var boton_actualizar: Button = $VBoxContainer/VBoxContainer/ButtonActualizar
@onready var boton_volver: Button = $VBoxContainer/VBoxContainer/ButtonVolver


func _ready() -> void:
	minijuego_actual = GameSession.minijuego_actual if not GameSession.minijuego_actual.is_empty() else "take"
	titulo_label.text = "RANKING - " + minijuego_actual.to_upper()
	boton_actualizar.pressed.connect(_on_actualizar_pressed)
	boton_volver.pressed.connect(_on_volver_pressed)

	if not BackendManager.ranking_recibido.is_connected(_al_recibir_ranking):
		BackendManager.ranking_recibido.connect(_al_recibir_ranking)

	mensaje_label.text = "Cargando ranking..."
	ranking_label.text = ""
	_limpiar_podio()

	BackendManager.obtener_ranking(minijuego_actual)


func _on_actualizar_pressed() -> void:
	mensaje_label.text = "Actualizando ranking..."
	ranking_label.text = ""
	_limpiar_podio()

	BackendManager.obtener_ranking(minijuego_actual)


func _al_recibir_ranking(exito: bool, respuesta: Dictionary) -> void:
	if not exito:
		mensaje_label.text = str(
			respuesta.get(
				"detail",
				respuesta.get("detalle", "No se pudo cargar el ranking.")
			)
		)
		print("Error al cargar ranking: ", respuesta)
		return

	# El backend puede devolver directamente una lista o un objeto con "ranking".
	var jugadores: Array = []
	if respuesta.get("ranking", []) is Array:
		jugadores = respuesta.get("ranking", [])
	elif respuesta.get("partidas", []) is Array:
		jugadores = respuesta.get("partidas", [])

	print("Cantidad de jugadores: ", jugadores.size())

	if jugadores.is_empty():
		_limpiar_podio()
		ranking_label.text = "Todavía no hay puntajes registrados."
		mensaje_label.text = ""
		return

	var texto1 := ""
	var texto2 := ""
	var texto3 := ""
	var texto := ""

	for i in range(jugadores.size()):
		var jugador: Dictionary = jugadores[i]

		# Admite los nombres de campos del backend nuevo y del anterior.
		var posicion := int(jugador.get("posicion", i + 1))
		var nombre := str(
			jugador.get("nombre_jugador", jugador.get("nombre_usuario", "Desconocido"))
		)
		var puntaje := int(
			jugador.get("puntaje_final", jugador.get("mejor_puntaje", 0))
		)
		var unidad := "ms" if minijuego_actual == "draw" else "puntos"

		match posicion:
			1:
				texto1 = "[color=#fed403]%s[/color]\n[color=white]%d %s[/color]" % [nombre, puntaje, unidad]
			2:
				texto2 = "[color=#385cd6]%s[/color]\n[color=white]%d %s[/color]" % [nombre, puntaje, unidad]
			3:
				texto3 = "[color=#ff8736]%s[/color]\n[color=white]%d %s[/color]" % [nombre, puntaje, unidad]
			_:
				texto += "[color=#6abe30]%d. %s — [/color][color=white]%d %s[/color]\n" % [
					posicion, nombre, puntaje, unidad
				]

	top1_label.text = texto1
	top2_label.text = texto2
	top3_label.text = texto3
	ranking_label.text = texto
	mensaje_label.text = ""

	print("Respuesta del ranking: ", respuesta)


func _limpiar_podio() -> void:
	top1_label.text = ""
	top2_label.text = ""
	top3_label.text = ""


func _on_volver_pressed() -> void:
	get_tree().change_scene_to_file(MENU_PATH)
