extends Control

const VALORACION_PATH: String = "res://ranking/valoracion_individual.tscn"
const MENU_PATH: String = "res://menu.tscn"

var mostrar_form: bool = false
var guardando: bool = false
var juego_actual: String = ""
var _done: bool = false


@onready var boton_guardar: Button = $CanvasLayer/MenuContainer/ButtonGuardar
@onready var boton_descartar: Button = $CanvasLayer/MenuContainer/ButtonDescartar
@onready var boton_valorar: Button = $CanvasLayer/MenuContainer/ButtonValorar
@onready var boton_revancha: Button = $CanvasLayer/MenuContainer/ButtonRevancha

@onready var panel_formulario: Panel = $CanvasLayer/MenuContainer/PanelGuardarFormulario
@onready var line_edit_nombre: LineEdit = $CanvasLayer/MenuContainer/PanelGuardarFormulario/LineEditNombre
@onready var boton_confirmar: Button = $CanvasLayer/MenuContainer/PanelGuardarFormulario/HBoxContainer/ButtonConfirmar
@onready var boton_cancelar: Button = $CanvasLayer/MenuContainer/PanelGuardarFormulario/HBoxContainer/ButtonCancelar

# Mensajes
@onready var mensaje_label: Label = $CanvasLayer/MenuContainer/Mensaje

static func spawn( parent: Node, title: String, detail: String, accent: Color
	) -> Control:
	var pantalla := load("res://end_screen.tscn").instantiate() as Control
	parent.add_child(pantalla)
	pantalla.get_node("CanvasLayer").layer = 100
	
	return pantalla

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	var overlay := $CanvasLayer/ColorRect as ColorRect
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.05, 0.02, 0.08, 0.80)
	
	# Conectar botones
	boton_guardar.pressed.connect(_mostrar_formulario_guardar)
	boton_descartar.pressed.connect(_descartar_puntaje)
	boton_valorar.pressed.connect(_ir_a_valoracion)
	boton_revancha.pressed.connect(_revancha)
	boton_confirmar.pressed.connect(_confirmar_nombre)
	boton_cancelar.pressed.connect(_cancelar_nombre)

	line_edit_nombre.text_submitted.connect(_on_nombre_enviado)

	# Recibir la respuesta del backend
	if not BackendManager.puntaje_guardado.is_connected(_al_guardar_puntaje):
		BackendManager.puntaje_guardado.connect(_al_guardar_puntaje)

	juego_actual = GameSession.juego_pendiente

	panel_formulario.hide()
	mensaje_label.text = ""

	_mostrar_menu_normal()


func _mostrar_menu_normal() -> void:
	mostrar_form = false

	panel_formulario.hide()
	boton_descartar.show()
	boton_valorar.show()
	boton_revancha.show()
	boton_guardar.show()
	
	boton_descartar.disabled = false
	boton_valorar.disabled = false
	boton_revancha.disabled = false
	boton_confirmar.disabled = false

	mensaje_label.text = ""
	line_edit_nombre.release_focus()


func _mostrar_formulario_guardar() -> void:
	if guardando:
		return

	mostrar_form = true

	panel_formulario.show()
	boton_descartar.hide()
	boton_revancha.hide()
	boton_valorar.hide()
	boton_guardar.hide()

	mensaje_label.text = "Ingresa el nombre para el ranking."
	line_edit_nombre.clear()
	line_edit_nombre.grab_focus()


func _confirmar_nombre() -> void:
	if guardando:
		return

	var nombre := line_edit_nombre.text.strip_edges()

	if nombre.is_empty():
		mensaje_label.text = "Ingresa un nombre."
		line_edit_nombre.grab_focus()
		return

	if nombre.length() > 30:
		mensaje_label.text = "Máximo 30 caracteres."
		line_edit_nombre.grab_focus()
		return

	if GameSession.juego_pendiente.is_empty() or GameSession.puntaje_pendiente < 0:
		mensaje_label.text = "No hay un puntaje pendiente."
		return

	guardando = true
	boton_confirmar.disabled = true
	mensaje_label.text = "Guardando puntaje..."

	GameSession.confirmar_guardado(nombre)


func _on_nombre_enviado(_texto: String) -> void:
	_confirmar_nombre()


func _al_guardar_puntaje(
	exito: bool,
	respuesta: Dictionary
	) -> void:
		
	guardando = false
	boton_confirmar.disabled = false

	if exito:
		mensaje_label.text = str(
			respuesta.get("mensaje", "¡Puntaje guardado!")
		)
		
		GameSession.juego_para_valorar = GameSession.juego_pendiente
		GameSession.limpiar_resultado_pendiente()
		_done = true

		await get_tree().create_timer(2.0).timeout
		get_tree().change_scene_to_file(VALORACION_PATH)
		
	else:
		var detalle := str(
			respuesta.get(
				"detail",
				respuesta.get("detalle", "No se pudo guardar el puntaje.")
			)
		)
		mensaje_label.text = "ERROR: " + detalle

func _descartar_puntaje() -> void:
	if guardando or _done:
		return

	GameSession.juego_para_valorar = GameSession.juego_pendiente
	GameSession.descartar_resultado()

	mostrar_form = false
	_done = true

	mensaje_label.text = "Puntaje descartado. ¡Gracias por jugar!"

	boton_guardar.hide()
	boton_descartar.hide()
	boton_valorar.hide()
	boton_revancha.hide()

	await get_tree().create_timer(2.0).timeout
	get_tree().change_scene_to_file(VALORACION_PATH)

func _ir_a_valoracion() -> void:
	if guardando or _done:
		return

	if GameSession.juego_para_valorar.is_empty():
		GameSession.juego_para_valorar = juego_actual

	_done = true
	get_tree().change_scene_to_file(VALORACION_PATH)


func _revancha() -> void:
	if guardando or _done:
		return

	_done = true
	get_tree().paused = false
	get_tree().reload_current_scene()


func _input(event: InputEvent) -> void:
	if _done or not is_inside_tree():
		return

	if not event.is_pressed() or event.is_echo():
		return

	if mostrar_form:
		if event.is_action_pressed("ui_cancel") and not guardando:
			_mostrar_menu_normal()
			get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_cancel"):
		_ir_a_valoracion()
		get_viewport().set_input_as_handled()
		

func _cancelar_nombre() -> void:
	_mostrar_menu_normal()
