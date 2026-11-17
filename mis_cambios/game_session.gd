extends Node

# Identificador compartido por todos los participantes de una partida.
var id_partida: String = ""
var minijuego_actual: String = ""
var juego_para_valorar: String = ""

# Resultados pendientes indexados por numero de jugador (1 o 2).
# Cada entrada contiene minijuego, puntaje_final y nombre_jugador.
var resultados_pendientes: Dictionary = {}

# Compatibilidad temporal con las pantallas antiguas de un solo jugador.
var nombre_jugador: String = ""
var puntaje_pendiente: int = -1
var juego_pendiente: String = ""


func _ready() -> void:
	if id_partida.is_empty():
		iniciar_partida()


func iniciar_partida(minijuego: String = "") -> void:
	id_partida = _generar_uuid()
	minijuego_actual = minijuego.strip_edges().to_lower()
	resultados_pendientes.clear()
	_actualizar_compatibilidad()

	print("Nueva partida: ", id_partida, " | Juego: ", minijuego_actual)


# Alias temporal para llamadas antiguas. No representa una sesión de usuario.
func iniciar_jugador() -> void:
	iniciar_partida(minijuego_actual)


func establecer_minijuego(minijuego: String) -> void:
	minijuego_actual = minijuego.strip_edges().to_lower()


func guardar_resultado_local(
	juego: String,
	puntaje: int,
	jugador_numero: int = 1
) -> void:
	if jugador_numero < 1 or jugador_numero > 2:
		push_error("El numero de jugador debe ser 1 o 2.")
		return

	if id_partida.is_empty():
		iniciar_partida(juego)

	var minijuego := juego.strip_edges().to_lower()
	minijuego_actual = minijuego

	resultados_pendientes[jugador_numero] = {
		"minijuego": minijuego,
		"puntaje_final": puntaje,
		"nombre_jugador": ""
	}

	_actualizar_compatibilidad()
	print("Resultado pendiente P", jugador_numero, ": ", minijuego, " / ", puntaje)


func confirmar_guardado(nombre: String, jugador_numero: int = 1) -> void:
	var nombre_limpio := nombre.strip_edges()

	if nombre_limpio.is_empty():
		push_warning("Debes ingresar un nombre para guardar el puntaje.")
		return

	if nombre_limpio.length() > 30:
		push_warning("El nombre no puede superar los 30 caracteres.")
		return

	if not resultados_pendientes.has(jugador_numero):
		push_warning("No hay resultado pendiente para este jugador.")
		return

	var resultado: Dictionary = resultados_pendientes[jugador_numero]
	resultado["nombre_jugador"] = nombre_limpio

	BackendManager.guardar_puntaje(
		id_partida,
		str(resultado["minijuego"]),
		nombre_limpio,
		int(resultado["puntaje_final"]),
		jugador_numero
	)


func registrar_valoracion(jugador_numero: int, puntuacion: int) -> void:
	if id_partida.is_empty():
		push_warning("No existe una partida para asociar la valoracion.")
		return

	if jugador_numero < 1 or jugador_numero > 2:
		push_warning("El numero de jugador debe ser 1 o 2.")
		return

	if puntuacion < 1 or puntuacion > 5:
		push_warning("La valoracion debe estar entre 1 y 5.")
		return

	if juego_para_valorar.is_empty():
		push_warning("No se ha indicado el minijuego que se va a valorar.")
		return

	BackendManager.enviar_valoracion(
		id_partida,
		juego_para_valorar,
		jugador_numero,
		puntuacion
	)


func descartar_resultado(jugador_numero: int = 1) -> void:
	if resultados_pendientes.has(jugador_numero):
		resultados_pendientes.erase(jugador_numero)
	_actualizar_compatibilidad()


func descartar_resultados_pendientes() -> void:
	resultados_pendientes.clear()
	_actualizar_compatibilidad()


func limpiar_resultado_pendiente(jugador_numero: int = 1) -> void:
	descartar_resultado(jugador_numero)


func preparar_revancha() -> void:
	var juego := minijuego_actual
	descartar_resultados_pendientes()
	iniciar_partida(juego)


func _actualizar_compatibilidad() -> void:
	if resultados_pendientes.has(1):
		var resultado: Dictionary = resultados_pendientes[1]
		juego_pendiente = str(resultado["minijuego"])
		puntaje_pendiente = int(resultado["puntaje_final"])
		nombre_jugador = str(resultado.get("nombre_jugador", ""))
	else:
		juego_pendiente = ""
		puntaje_pendiente = -1
		nombre_jugador = ""


func _generar_uuid() -> String:
	var bytes := Crypto.new().generate_random_bytes(16)

	# UUID version 4.
	bytes[6] = (bytes[6] & 0x0f) | 0x40
	bytes[8] = (bytes[8] & 0x3f) | 0x80

	var hex := bytes.hex_encode()

	return (
		hex.substr(0, 8) + "-"
		+ hex.substr(8, 4) + "-"
		+ hex.substr(12, 4) + "-"
		+ hex.substr(16, 4) + "-"
		+ hex.substr(20, 12)
	)
