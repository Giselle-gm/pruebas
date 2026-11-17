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
# GUARDAR PUNTAJE
# --------------------------------------------------

func guardar_puntaje(
	minijuego: String,
	nombre_jugador: String,
	puntaje_final: int
	) -> void:
	var nombre := nombre_jugador.strip_edges()
	var juego := minijuego.strip_edges().to_lower()

	if nombre.is_empty():
		puntaje_guardado.emit(false, {
			"detail": "Debes ingresar un nombre para guardar el puntaje."
		})
		return

	if nombre.length() > 30:
		puntaje_guardado.emit(false, {
			"detail": "El nombre no puede superar los 30 caracteres."
		})
		return

	if puntaje_final < 0:
		puntaje_guardado.emit(false, {
			"detail": "El puntaje no puede ser negativo."
		})
		return

	var datos := {
		"minijuego": juego,
		"nombre_jugador": nombre,
		"puntaje_final": puntaje_final
	}

	realizar_solicitud(
		"/puntajes",
		HTTPClient.METHOD_POST,
		datos,
		"puntaje"
	)


# --------------------------------------------------
# CONSULTAR RANKING DE UN MINIJUEGO
# --------------------------------------------------

func obtener_ranking(minijuego: String) -> void:
	var juego := minijuego.strip_edges().to_lower()

	if juego.is_empty():
		ranking_recibido.emit(false, {
			"detail": "Debes indicar el minijuego."
		})
		return

	realizar_solicitud(
		"/ranking/" + juego,
		HTTPClient.METHOD_GET,
		{},
		"ranking"
	)


# --------------------------------------------------
# ENVIAR VALORACION
# --------------------------------------------------

func enviar_valoracion(
	minijuego: String,
	sesion_jugador_id: String,
	puntuacion: int
	) -> void:
	var juego := minijuego.strip_edges().to_lower()
	var id_sesion := sesion_jugador_id.strip_edges()

	if juego.is_empty():
		valoracion_completada.emit(false, {
			"detail": "Debes indicar el minijuego."
		})
		return

	if not _es_uuid_valido(id_sesion):
		valoracion_completada.emit(false, {
			"detail": "El identificador de sesión no es válido."
		})
		return

	if puntuacion < 1 or puntuacion > 5:
		valoracion_completada.emit(false, {
			"detail": "La puntuación debe estar entre 1 y 5."
		})
		return

	var datos := {
		"minijuego": juego,
		"sesion_jugador_id": id_sesion,
		"puntuacion": puntuacion
	}

	realizar_solicitud(
		"/valoraciones",
		HTTPClient.METHOD_POST,
		datos,
		"valoracion"
	)


# --------------------------------------------------
# CONSULTAR PROMEDIO DE VALORACIONES
# --------------------------------------------------

func obtener_resumen_valoraciones(minijuego: String) -> void:
	var juego := minijuego.strip_edges().to_lower()

	if juego.is_empty():
		resumen_valoraciones_recibido.emit(false, {
			"detail": "Debes indicar el minijuego."
		})
		return

	realizar_solicitud(
		"/valoraciones/resumen/" + juego,
		HTTPClient.METHOD_GET,
		{},
		"resumen"
	)


# --------------------------------------------------
# FUNCION GENERAL PARA PETICIONES HTTP
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
			cabeceras: PackedStringArray,
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
					var mensaje := texto
					conexion_comprobada.emit(exito, mensaje)

				"puntaje":
					puntaje_guardado.emit(exito, respuesta)

				"ranking":
					ranking_recibido.emit(exito, respuesta)

				"valoracion":
					valoracion_completada.emit(exito, respuesta)

				"resumen":
					resumen_valoraciones_recibido.emit(
						exito,
						respuesta
					)

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
		print("No se pudo iniciar la petición. Código: ", error)

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
				resumen_valoraciones_recibido.emit(
					false,
					respuesta_error
				)

		peticion.queue_free()


# --------------------------------------------------
# VALIDAR IDENTIFICADOR UUID DE SESION
# --------------------------------------------------

func _es_uuid_valido(valor: String) -> bool:
	var patron := RegEx.new()
	patron.compile(
		"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"
	)

	return patron.search(valor) != null
