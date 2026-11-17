
extends Node

# Jugador actual
var nombre_jugador: String = ""
var sesion_jugador_id: String = ""

# Resultado pendiente de guardar
var puntaje_pendiente: int = -1
var juego_pendiente: String = ""

#Juego actual
var juego_para_valorar: String = ""

func iniciar_jugador() -> void:
	nombre_jugador = ""
	sesion_jugador_id = _generar_uuid()

	limpiar_resultado_pendiente()

	print("Nueva sesión de jugador: ", sesion_jugador_id)
	print("ID vacío: ", sesion_jugador_id.is_empty())


func guardar_resultado_local(juego: String, puntaje: int) -> void:
	juego_pendiente = juego
	puntaje_pendiente = puntaje

	print("Juego: ", juego_pendiente)
	print("Puntaje pendiente: ", puntaje_pendiente)


func confirmar_guardado(nombre: String) -> void:
	var nombre_limpio := nombre.strip_edges()

	if nombre_limpio.is_empty():
		print("Debes ingresar un nombre para guardar el puntaje.")
		return

	if nombre_limpio.length() > 30:
		print("El nombre no puede superar los 30 caracteres.")
		return

	if juego_pendiente.is_empty() or puntaje_pendiente < 0:
		print("No hay ningún resultado pendiente.")
		return

	BackendManager.guardar_puntaje(
		juego_pendiente,
		nombre_limpio,
		puntaje_pendiente
	)


func descartar_resultado() -> void:
	print("Se descartó el resultado de ", juego_pendiente)
	limpiar_resultado_pendiente()


func limpiar_resultado_pendiente() -> void:
	puntaje_pendiente = -1
	juego_pendiente = ""


func _generar_uuid() -> String:
	var bytes := Crypto.new().generate_random_bytes(16)

	# UUID versión 4
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
