extends Control

const MENU_PATH := "res://menu.tscn"
const GAME_NAMES := {
	"take": "TAKE",
	"draw": "DRAW",
	"test_your_might": "TEST YOUR MIGHT"
}

var minijuego_actual := "take"
var titulo_label: Label
var promedio_label: Label
var cantidad_label: Label
var estado_label: Label
var boton_volver: Button
var boton_actualizar: Button


func _ready() -> void:
	minijuego_actual = GameSession.minijuego_actual if not GameSession.minijuego_actual.is_empty() else "take"
	_crear_interfaz()
	if not BackendManager.resumen_valoraciones_recibido.is_connected(_al_recibir_resumen):
		BackendManager.resumen_valoraciones_recibido.connect(_al_recibir_resumen)
	_consultar()


func _crear_interfaz() -> void:
	var fondo := ColorRect.new()
	fondo.color = Color("171323")
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)

	var decoracion := ColorRect.new()
	decoracion.color = Color("35243a")
	decoracion.position = Vector2(18, 18)
	decoracion.size = Vector2(284, 144)
	add_child(decoracion)

	titulo_label = _label("VALORACIONES", Rect2(20, 27, 280, 18), 13, Color("ffd45e"), true)
	promedio_label = _label("Promedio: -- / 5", Rect2(28, 63, 264, 24), 12, Color("ffffff"), true)
	cantidad_label = _label("Partidas valoradas: --", Rect2(28, 91, 264, 16), 8, Color("f0e4cf"), true)
	estado_label = _label("Consultando...", Rect2(28, 113, 264, 16), 7, Color("c9b795"), true)

	boton_actualizar = _button("ACTUALIZAR", Rect2(55, 139, 95, 18))
	boton_volver = _button("VOLVER", Rect2(170, 139, 95, 18))
	boton_actualizar.pressed.connect(_consultar)
	boton_volver.pressed.connect(_volver)


func _label(texto: String, rect: Rect2, tamano: int, color: Color, centrado: bool) -> Label:
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.position = rect.position
	etiqueta.size = rect.size
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centrado else HORIZONTAL_ALIGNMENT_LEFT
	etiqueta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	etiqueta.add_theme_color_override("font_color", color)
	etiqueta.add_theme_font_size_override("font_size", tamano)
	var fuente := load("res://fonts/Pixellari.ttf") as Font
	if fuente != null:
		etiqueta.add_theme_font_override("font", fuente)
	add_child(etiqueta)
	return etiqueta


func _button(texto: String, rect: Rect2) -> Button:
	var boton := Button.new()
	boton.text = texto
	boton.position = rect.position
	boton.size = rect.size
	boton.add_theme_font_size_override("font_size", 8)
	var fuente := load("res://fonts/Pixellari.ttf") as Font
	if fuente != null:
		boton.add_theme_font_override("font", fuente)
	add_child(boton)
	return boton


func _consultar() -> void:
	titulo_label.text = "VALORACIONES - " + str(GAME_NAMES.get(minijuego_actual, minijuego_actual.to_upper()))
	promedio_label.text = "Promedio: consultando..."
	cantidad_label.text = "Partidas valoradas: --"
	estado_label.text = ""
	boton_actualizar.disabled = true
	BackendManager.obtener_resumen_valoraciones(minijuego_actual)


func _al_recibir_resumen(exito: bool, respuesta: Dictionary) -> void:
	boton_actualizar.disabled = false
	if not exito:
		estado_label.text = str(respuesta.get("detail", "No se pudieron cargar las valoraciones."))
		return

	var promedio = respuesta.get("promedio", null)
	var cantidad := int(respuesta.get("cantidad", 0))
	if promedio == null:
		promedio_label.text = "Promedio: sin valoraciones"
	else:
		promedio_label.text = "Promedio: %s / 5" % str(promedio)
	cantidad_label.text = "Valoraciones recibidas: %d" % cantidad
	estado_label.text = "Resumen general de este minijuego."


func _volver() -> void:
	get_tree().change_scene_to_file(MENU_PATH)


func _exit_tree() -> void:
	if BackendManager.resumen_valoraciones_recibido.is_connected(_al_recibir_resumen):
		BackendManager.resumen_valoraciones_recibido.disconnect(_al_recibir_resumen)
