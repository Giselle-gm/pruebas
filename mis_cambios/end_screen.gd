extends Control

const MENU_PATH := "res://menu.tscn"

var titulo_fin := "FIN DEL JUEGO"
var detalle_fin := ""
var color_acento := Color("3ea6ff")
var juego_actual := ""
var es_dos_jugadores := false
var modo_valoracion := false
var solicitud_puntaje_jugador := 0
var solicitud_valoracion_jugador := 0
var valoraciones_enviadas: Dictionary = {}
var puntuaciones_seleccionadas: Dictionary = {}
var botones_guardar: Dictionary = {}
var campos_nombre: Dictionary = {}
var etiquetas_estado: Dictionary = {}
var botones_valorar: Dictionary = {}
var etiquetas_valoracion: Dictionary = {}
var mensaje_global: Label
var fuente_pixel: Font
var fuente_titulo: Font

@onready var lienzo: ColorRect = $CanvasLayer/ColorRect


static func spawn(parent: Node, title: String, detail: String, accent: Color) -> Control:
	var pantalla := load("res://end_screen.tscn").instantiate() as Control
	pantalla.titulo_fin = title
	pantalla.detalle_fin = detail
	pantalla.color_acento = accent
	parent.add_child(pantalla)
	pantalla.get_node("CanvasLayer").layer = 100
	return pantalla


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false
	fuente_pixel = load("res://fonts/Pixellari.ttf") as Font
	fuente_titulo = load("res://pixel-comic-sans-undertale-sans-font.ttf") as Font
	juego_actual = GameSession.minijuego_actual
	if juego_actual.is_empty():
		juego_actual = GameSession.juego_pendiente
	es_dos_jugadores = juego_actual in ["draw", "test_your_might"]

	if not BackendManager.puntaje_guardado.is_connected(_al_guardar_puntaje):
		BackendManager.puntaje_guardado.connect(_al_guardar_puntaje)
	if not BackendManager.valoracion_completada.is_connected(_al_enviar_valoracion):
		BackendManager.valoracion_completada.connect(_al_enviar_valoracion)

	_mostrar_resultados()


func _mostrar_resultados() -> void:
	_limpiar_lienzo()
	_agregar_label(lienzo, titulo_fin, Rect2(4, 3, 312, 17), 13, color_acento, true, true)
	_agregar_label(lienzo, detalle_fin, Rect2(4, 20, 312, 12), 8, Color("f4dca0"), true)

	if es_dos_jugadores:
		_crear_panel_resultado(1, 7, 35, 150)
		_crear_panel_resultado(2, 163, 35, 150)
	else:
		_crear_panel_resultado(1, 50, 35, 220)

	mensaje_global = _agregar_label(lienzo, "", Rect2(8, 128, 304, 13), 7, Color("ffcf70"), true)
	var revancha := _agregar_boton(lienzo, "REVANCHA", Rect2(48, 146, 104, 25), Color("294e78"))
	var salir := _agregar_boton(lienzo, "SALIR", Rect2(168, 146, 104, 25), Color("28583d"))
	revancha.pressed.connect(_revancha)
	salir.pressed.connect(_salir_a_valoracion)


func _crear_panel_resultado(jugador: int, x: float, y: float, ancho: float) -> void:
	var panel := _crear_panel(x, y, ancho, 88, jugador)
	_agregar_label(panel, "JUGADOR %d" % jugador, Rect2(3, 2, ancho - 6, 12), 9, Color("ffe29a"), true, true)
	var resultado: Dictionary = GameSession.resultados_pendientes.get(jugador, {})
	if resultado.is_empty():
		_agregar_label(panel, "SIN RESULTADO", Rect2(4, 28, ancho - 8, 16), 8, Color("c6b9ca"), true)
		return

	var puntaje := int(resultado.get("puntaje_final", 0))
	var unidad := "ms" if juego_actual == "draw" else "PTS"
	_agregar_label(panel, "%d %s" % [puntaje, unidad], Rect2(4, 15, ancho - 8, 15), 9, Color("ffffff"), true)

	var campo := LineEdit.new()
	campo.position = Vector2(8, 33)
	campo.size = Vector2(ancho - 16, 18)
	campo.max_length = 30
	campo.placeholder_text = "Nombre para ranking"
	campo.add_theme_font_size_override("font_size", 8)
	if fuente_pixel != null:
		campo.add_theme_font_override("font", fuente_pixel)
	panel.add_child(campo)
	campos_nombre[jugador] = campo

	var boton := _agregar_boton(panel, "GUARDAR", Rect2(8, 54, ancho - 16, 17), Color("725523"))
	boton.pressed.connect(func(): _guardar_jugador(jugador))
	botones_guardar[jugador] = boton
	etiquetas_estado[jugador] = _agregar_label(panel, "", Rect2(3, 72, ancho - 6, 11), 6, Color("a8e6b2"), true)


func _guardar_jugador(jugador: int) -> void:
	if solicitud_puntaje_jugador != 0 or modo_valoracion:
		return
	if not GameSession.resultados_pendientes.has(jugador):
		return

	var campo: LineEdit = campos_nombre[jugador]
	var nombre := campo.text.strip_edges()
	if nombre.is_empty():
		etiquetas_estado[jugador].text = "Escribe un nombre"
		campo.grab_focus()
		return

	solicitud_puntaje_jugador = jugador
	for boton in botones_guardar.values():
		boton.disabled = true
	etiquetas_estado[jugador].text = "Guardando..."
	GameSession.confirmar_guardado(nombre, jugador)


func _al_guardar_puntaje(exito: bool, respuesta: Dictionary) -> void:
	var jugador := solicitud_puntaje_jugador
	if jugador == 0:
		return
	solicitud_puntaje_jugador = 0

	if exito:
		GameSession.descartar_resultado(jugador)
		etiquetas_estado[jugador].text = "¡Guardado!"
		campos_nombre[jugador].editable = false
		botones_guardar[jugador].text = "GUARDADO"
		botones_guardar[jugador].disabled = true
	else:
		var detalle := str(respuesta.get("detail", respuesta.get("detalle", "No se pudo guardar.")))
		etiquetas_estado[jugador].text = detalle.left(28)
		for boton in botones_guardar.values():
			boton.disabled = false


func _revancha() -> void:
	if solicitud_puntaje_jugador != 0 or modo_valoracion:
		return
	GameSession.descartar_resultados_pendientes()
	get_tree().paused = false
	get_tree().reload_current_scene()


func _salir_a_valoracion() -> void:
	if solicitud_puntaje_jugador != 0 or modo_valoracion:
		return
	GameSession.descartar_resultados_pendientes()
	GameSession.juego_para_valorar = juego_actual
	_mostrar_valoracion()


func _mostrar_valoracion() -> void:
	modo_valoracion = true
	_limpiar_lienzo()
	_agregar_label(lienzo, "VALORACIÓN", Rect2(4, 5, 312, 18), 13, color_acento, true, true)
	_agregar_label(lienzo, "¿Qué te pareció esta partida?", Rect2(4, 24, 312, 12), 8, Color("f4dca0"), true)

	if es_dos_jugadores:
		_crear_panel_valoracion(1, 7, 42, 150)
		_crear_panel_valoracion(2, 163, 42, 150)
	else:
		_crear_panel_valoracion(1, 50, 42, 220)

	mensaje_global = _agregar_label(lienzo, "Cada jugador envía su valoración por separado.", Rect2(5, 134, 310, 12), 7, Color("ffcf70"), true)


func _crear_panel_valoracion(jugador: int, x: float, y: float, ancho: float) -> void:
	var panel := _crear_panel(x, y, ancho, 88, jugador)
	_agregar_label(panel, "JUGADOR %d" % jugador, Rect2(3, 3, ancho - 6, 12), 9, Color("ffe29a"), true, true)
	_agregar_label(panel, "PUNTUACIÓN (1 A 5)", Rect2(3, 18, ancho - 6, 10), 7, Color("ffffff"), true)

	var fila := HBoxContainer.new()
	fila.position = Vector2(7, 31)
	fila.size = Vector2(ancho - 14, 20)
	fila.add_theme_constant_override("separation", 3)
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(fila)

	var botones: Array[Button] = []
	for valor in range(1, 6):
		var boton := Button.new()
		boton.text = str(valor)
		boton.custom_minimum_size = Vector2(22, 19)
		boton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		boton.add_theme_font_size_override("font_size", 8)
		fila.add_child(boton)
		boton.pressed.connect(func(): _seleccionar_valoracion(jugador, valor))
		botones.append(boton)
	botones_valorar[jugador] = botones

	etiquetas_valoracion[jugador] = _agregar_label(panel, "Elige de 1 a 5", Rect2(3, 52, ancho - 6, 10), 6, Color("cfc1d6"), true)
	var enviar := _agregar_boton(panel, "ENVIAR", Rect2(8, 66, ancho - 16, 17), Color("28583d"))
	enviar.pressed.connect(func(): _enviar_valoracion(jugador))
	panel.set_meta("boton_enviar", enviar)


func _seleccionar_valoracion(jugador: int, valor: int) -> void:
	puntuaciones_seleccionadas[jugador] = valor
	var botones: Array = botones_valorar[jugador]
	for indice in range(botones.size()):
		botones[indice].modulate = Color("ffe08a") if indice + 1 == valor else Color("ffffff")
	etiquetas_valoracion[jugador].text = "Seleccionado: %d/5" % valor


func _enviar_valoracion(jugador: int) -> void:
	if solicitud_valoracion_jugador != 0 or valoraciones_enviadas.has(jugador):
		return
	if not puntuaciones_seleccionadas.has(jugador):
		etiquetas_valoracion[jugador].text = "Elige de 1 a 5"
		return
	solicitud_valoracion_jugador = jugador
	etiquetas_valoracion[jugador].text = "Enviando..."
	GameSession.registrar_valoracion(jugador, int(puntuaciones_seleccionadas[jugador]))


func _al_enviar_valoracion(exito: bool, respuesta: Dictionary) -> void:
	var jugador := solicitud_valoracion_jugador
	if jugador == 0:
		return
	solicitud_valoracion_jugador = 0

	if exito:
		valoraciones_enviadas[jugador] = true
		etiquetas_valoracion[jugador].text = "¡Gracias!"
		for boton in botones_valorar[jugador]:
			boton.disabled = true
		var panel: Panel = etiquetas_valoracion[jugador].get_parent()
		var enviar: Button = panel.get_meta("boton_enviar")
		enviar.disabled = true
		var total := 2 if es_dos_jugadores else 1
		if valoraciones_enviadas.size() >= total:
			mensaje_global.text = "¡Gracias por jugar!"
			await get_tree().create_timer(1.2).timeout
			get_tree().change_scene_to_file(MENU_PATH)
	else:
		var detalle := str(respuesta.get("detail", "No se pudo enviar la valoración."))
		etiquetas_valoracion[jugador].text = detalle.left(28)


func _crear_panel(x: float, y: float, ancho: float, alto: float, jugador: int) -> Panel:
	var panel := Panel.new()
	panel.position = Vector2(x, y)
	panel.size = Vector2(ancho, alto)
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color("21152b")
	estilo.border_color = color_acento if jugador == 1 else Color("55b8ff")
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(3)
	panel.add_theme_stylebox_override("panel", estilo)
	lienzo.add_child(panel)
	return panel


func _limpiar_lienzo() -> void:
	for hijo in lienzo.get_children():
		hijo.queue_free()
	botones_guardar.clear()
	campos_nombre.clear()
	etiquetas_estado.clear()
	botones_valorar.clear()
	etiquetas_valoracion.clear()


func _agregar_label(padre: Control, texto: String, rect: Rect2, tamano: int, color: Color, centrado: bool = false, usar_titulo: bool = false) -> Label:
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.position = rect.position
	etiqueta.size = rect.size
	etiqueta.add_theme_color_override("font_color", color)
	etiqueta.add_theme_font_size_override("font_size", tamano)
	var fuente := fuente_titulo if usar_titulo else fuente_pixel
	if fuente != null:
		etiqueta.add_theme_font_override("font", fuente)
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centrado else HORIZONTAL_ALIGNMENT_LEFT
	etiqueta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	etiqueta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	padre.add_child(etiqueta)
	return etiqueta


func _agregar_boton(padre: Control, texto: String, rect: Rect2, color: Color) -> Button:
	var boton := Button.new()
	boton.text = texto
	boton.position = rect.position
	boton.size = rect.size
	boton.custom_minimum_size = rect.size
	boton.add_theme_font_size_override("font_size", 8)
	if fuente_pixel != null:
		boton.add_theme_font_override("font", fuente_pixel)
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = color
	estilo.border_color = Color("d9c58c")
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(2)
	boton.add_theme_stylebox_override("normal", estilo)
	boton.add_theme_stylebox_override("hover", estilo)
	boton.add_theme_stylebox_override("pressed", estilo)
	padre.add_child(boton)
	return boton


func _input(event: InputEvent) -> void:
	if modo_valoracion or solicitud_puntaje_jugador != 0:
		return
	if event.is_pressed() and not event.is_echo() and event.is_action_pressed("ui_cancel"):
		_salir_a_valoracion()
		get_viewport().set_input_as_handled()
