extends Node3D
# ---------------------------------------------------------------------------
# EFECTO DE DASH
# Mientras Kael se desplaza rápido deja detrás:
#   - Líneas de velocidad (rojo y dorado) estiradas hacia atrás
#   - Chispas doradas
#   - Una nubecita de polvo al arrancar (solo si estaba en el suelo)
# Las partículas se quedan en el mundo (no siguen a Kael), por eso parece
# que dejan una estela detrás de él.
# ---------------------------------------------------------------------------

var tamano := 1.0          # personaje.gd lo ajusta según qué tan grande es Kael en tu juego

@onready var lineas = $Lineas
@onready var chispas = $Chispas
@onready var polvo = $Polvo


# Arranca el efecto.
#   direccion: 1.0 si el dash va hacia +X (derecha), -1.0 hacia -X (izquierda)
#   en_suelo:  true si Kael pisaba el piso (para sacar polvo)
#   duracion:  cuánto dura el dash en segundos (las partículas se detienen al acabar)
func iniciar(direccion: float, en_suelo: bool, duracion: float = 0.2):
	var s := tamano
	var caja := AABB(Vector3(-6, -3, -3) * s, Vector3(12, 6, 6) * s)

	# Líneas de velocidad: salen hacia atrás, rápidas y finas.
	var pl = lineas.process_material
	pl.direction = Vector3(-direccion, 0.0, 0.0)
	pl.emission_box_extents = Vector3(0.12, 0.42, 0.25) * s
	pl.initial_velocity_min = 7.0 * s
	pl.initial_velocity_max = 12.0 * s
	lineas.draw_pass_1.size = Vector2(0.05, 0.9) * s
	lineas.visibility_aabb = caja

	# Chispas doradas: salen hacia atrás y un poco hacia arriba.
	var pc = chispas.process_material
	pc.direction = Vector3(-direccion, 0.2, 0.0)
	pc.emission_box_extents = Vector3(0.1, 0.4, 0.2) * s
	pc.initial_velocity_min = 1.5 * s
	pc.initial_velocity_max = 4.5 * s
	pc.gravity = Vector3(0.0, -2.0, 0.0) * s
	chispas.draw_pass_1.size = Vector2(0.07, 0.07) * s
	chispas.visibility_aabb = caja

	# Polvo: solo si estaba en el suelo, sale a los pies.
	var pp = polvo.process_material
	pp.direction = Vector3(-direccion, 0.4, 0.0)
	pp.emission_box_extents = Vector3(0.1, 0.02, 0.2) * s
	pp.initial_velocity_min = 0.6 * s
	pp.initial_velocity_max = 1.8 * s
	polvo.draw_pass_1.size = Vector2(0.35, 0.35) * s
	polvo.visibility_aabb = caja

	lineas.emitting = true
	chispas.emitting = true
	if en_suelo:
		polvo.position = Vector3(0.0, -0.42 * s, 0.0)
		polvo.restart()

	# Pasado el tiempo del dash dejamos de crear partículas nuevas.
	await get_tree().create_timer(duracion).timeout
	detener()


# Deja de crear partículas y borra el efecto cuando ya se apagaron las últimas.
func detener():
	lineas.emitting = false
	chispas.emitting = false
	await get_tree().create_timer(0.7).timeout
	queue_free()
