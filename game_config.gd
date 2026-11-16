extends Node
## Configuracion compartida entre el tablon y los minijuegos.
##
## Vive como autoload para que una eleccion hecha en un menu (por ejemplo
## la serie de DRAW) sobreviva al cambio de escena y a la revancha, que
## recarga la escena actual.

## Serie de DRAW: 3 (al mejor de 3) o 5 (al mejor de 5).
var draw_best_of := 3
