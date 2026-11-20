extends OmniLight3D
class_name LuzFuego

@export var energia_base = 2.0   # brillo promedio de la luz
@export var variacion = 0.5      # cuánto sube y baja el brillo
@export var velocidad = 10.0     # qué tan rápido parpadea

var desfase = 0.0                # número al azar para que no parpadeen todas iguales


# Se ejecuta una vez al nacer: sortea el desfase de esta luz.
func _ready():
	desfase = randf() * 100.0


# Se ejecuta en cada cuadro: calcula el brillo con una mezcla de ondas.
func _process(_delta):
	var t = Time.get_ticks_msec() / 1000.0 * velocidad + desfase
	var onda = sin(t) * cos(t * 0.7) + sin(t * 1.5)
	light_energy = maxf(energia_base + onda * variacion * 0.5, 0.0)
