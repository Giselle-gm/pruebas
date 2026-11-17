extends Node

signal conexion_comprobada(exito: bool, mensaje: String)
signal ranking_recibido(exito: bool, respuesta: Dictionary)
signal puntaje_guardado(exito: bool, respuesta: Dictionary)
signal valoracion_completada(exito: bool, respuesta: Dictionary)
signal resumen_valoraciones_recibido(exito: bool, respuesta: Dictionary)

const URL_BACKEND := "http://127.0.0.1:8000"


func _ready() -> void:
	comprobar_conexion()


# --------------------------------------------------
# CONEXION CON EL BACKEND
# --------------------------------------------------

func comprobar_conexion() -> void:
	realizar_solicitud("/", HTTPClient.METHOD_GET, {}, "conexion")


# --------------------------------------------------
# GUARDAR RESULTADO DE UN JUGADOR
# --------------------------------------------------

func guardar_puntaje(
	id_partida: String,
	minijuego: String,
	nombre_jugador: String,
	puntaje_final: int,
	jugador_numero: int
) -> void:
	var uuid := id_partida.strip_edges()
	var juego := minijuego.strip_edges().to_lower()
	var nombre := nombre_jugador.strip_edges()

	if not _es_uuid_valido(uuid):
		puntaje_guardado.emit(false, {
			"detail": "El identificador de partida no es válido."
		})
		return

	if not _es_minijuego_valido(juego):
		puntaje_guardado.emit(false, {
			"detail": "El identificador del minijuego no es válido."
		})
		return

	if nombre.is_empty() or nombre.length() > 30:
		puntaje_guardado.emit(false, {
			"detail": "El nombre debe tener entre 1 y 30 caracteres."
		})
		return

	if puntaje_final < 0:
		puntaje_guardado.emit(false, {
			"detail": "El puntaje no puede ser negativo."
		})
		return

	if jugador_numero < 1 or jugador_numero > 2:
		puntaje_guardado.emit(false, {
			"detail": "El jugador debe ser 1 o 2."
		})
		return

	var datos := {
		"id_partida": uuid,
		"minijuego": juego,
		"nombre_jugador": nombre,
		"puntaje_final": puntaje_final,
		"jugador_numero": jugador_numero
	}

	realizar_solicitud(
		"/puntajes",
		HTTPClient.METHOD_POST,
		datos,
		"puntaje"
	)


# --------------------------------------------------
# CONSULTAR RANKING
# --------------------------------------------------

func obtener_ranking(minijuego: String) -> void:
	var juego := minijuego.strip_edges().to_lower()

	if not _es_minijuego_valido(juego):
		ranking_recibido.emit(false, {
			"detail": "El identificador del minijuego no es válido."
		})
		return

	realizar_solicitud(
		"/ranking/" + juego,
		HTTPClient.METHOD_GET,
		{},
		"ranking"
	)


# --------------------------------------------------
# ENVIAR VALORACION INDIVIDUAL
# --------------------------------------------------

func enviar_valoracion(
	id_partida: String,
	minijuego: String,
	jugador_numero: int,
	puntuacion: int
) -> void:
	var uuid := id_partida.strip_edges()
	var juego := minijuego.strip_edges().to_lower()

	if not _es_uuid_valido(uuid):
		valoracion_completada.emit(false, {
			"detail": "El identificador de partida no es válido."
		})
		return

	if not _es_minijuego_valido(juego):
		valoracion_completada.emit(false, {
			"detail": "El identificador del minijuego no es válido."
		})
		return

	if jugador_numero < 1 or jugador_numero > 2:
		valoracion_completada.emit(false, {
			"detail": "El jugador debe ser 1 o 2."
		})
		return

	if puntuacion < 1 or puntuacion > 5:
		valoracion_completada.emit(false, {
			"detail": "La puntuación debe estar entre 1 y 5."
		})
		return

	var datos := {
		"id_partida": uuid,
		"minijuego": juego,
		"jugador_numero": jugador_numero,
		"puntuacion": puntuacion
	}

	realizar_solicitud(
		"/valoraciones",
		HTTPClient.METHOD_POST,
		datos,
		"valoracion"
	)


# --------------------------------------------------
# CONSULTAR RESUMEN DE VALORACIONES
# --------------------------------------------------

func obtener_resumen_valoraciones(minijuego: String) -> void:
	var juego := minijuego.strip_edges().to_lower()

	if not _es_minijuego_valido(juego):
		resumen_valoraciones_recibido.emit(false, {
			"detail": "El identificador del minijuego no es válido."
		})
		return

	realizar_solicitud(
		"/valoraciones/resumen/" + juego,
		HTTPClient.METHOD_GET,
		{},
		"resumen"
	)


# --------------------------------------------------
# PETICIONES HTTP
# --------------------------------------------------

func realizar_solicitud(
	ruta: String,
	metodo: int,
	datos: Dictionary,
	tipo: String
) -> void:
	var peticion := HTTPRequest.new()
	add_child(peticion)

	peticion.request_completed.connect(
		func(
			resultado: int,
			codigo_http: int,
			_cabeceras: PackedStringArray,
			cuerpo: PackedByteArray
		) -> void:
			var texto := cuerpo.get_string_from_utf8()
			var respuesta: Dictionary = {}
			var parseo := JSON.new()
			var error_json := parseo.parse(texto)

			if error_json == OK and parseo.data is Dictionary:
				respuesta = parseo.data
			else:
				respuesta = {"detail": texto}

			var exito := (
				resultado == HTTPRequest.RESULT_SUCCESS
				and codigo_http >= 200
				and codigo_http < 300
			)

			print("Petición: ", ruta)
			print("Código HTTP: ", codigo_http)
			print("Respuesta: ", respuesta)

			match tipo:
				"conexion":
					conexion_comprobada.emit(exito, texto)
				"puntaje":
					puntaje_guardado.emit(exito, respuesta)
				"ranking":
					ranking_recibido.emit(exito, respuesta)
				"valoracion":
					valoracion_completada.emit(exito, respuesta)
				"resumen":
					resumen_valoraciones_recibido.emit(exito, respuesta)

			peticion.queue_free(),
		CONNECT_ONE_SHOT
	)

	var cabeceras := PackedStringArray([
		"Content-Type: application/json"
	])
	var cuerpo_json := ""

	if not datos.is_empty():
		cuerpo_json = JSON.stringify(datos)

	var error := peticion.request(
		URL_BACKEND + ruta,
		cabeceras,
		metodo,
		cuerpo_json
	)

	if error != OK:
		var respuesta_error := {
			"detail": "No se pudo iniciar la solicitud HTTP."
		}

		match tipo:
			"conexion":
				conexion_comprobada.emit(
					false,
					"No se pudo conectar con el servidor."
				)
			"puntaje":
				puntaje_guardado.emit(false, respuesta_error)
			"ranking":
				ranking_recibido.emit(false, respuesta_error)
			"valoracion":
				valoracion_completada.emit(false, respuesta_error)
			"resumen":
				resumen_valoraciones_recibido.emit(false, respuesta_error)

		peticion.queue_free()


# --------------------------------------------------
# VALIDACIONES
# --------------------------------------------------

func _es_minijuego_valido(valor: String) -> bool:
	return valor in ["take", "draw", "test_your_might"]


func _es_uuid_valido(valor: String) -> bool:
	var patron := RegEx.new()
	patron.compile(
		"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"
	)
	return patron.search(valor) != null
