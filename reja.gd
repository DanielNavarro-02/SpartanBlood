extends Node3D
class_name Reja

signal reja_abierta   # se emite cuando la reja terminó de subir

@export var ancho = 1.5               # ancho de la salida en metros
@export var alto = 3.0                # alto de la salida en metros
@export var profundidad = 1.0         # grosor de la colisión (que nadie se cuele por detrás)
@export var cantidad_barrotes = 8
@export var color_hierro = Color("#2b2b33")
@export var tiempo_temblor = 1      # segundos que tiembla antes de subir
@export var intensidad_temblor = 0.06 # metros que se mueve de lado a lado
@export var tiempo_subida = 2       # segundos que tarda en subir

var cuerpo: StaticBody3D   # la parte que bloquea el paso
var barrotes: Node3D       # la parte que se ve (es la que tiembla)
var abierta = false


# Al empezar el juego se construyen la colisión y los barrotes. La reja nace cerrada.
func _ready():
	crear_colision()
	crear_barrotes()


# Crea el bloque invisible que impide pasar al jugador.
func crear_colision():
	cuerpo = StaticBody3D.new()
	add_child(cuerpo)
	var forma = CollisionShape3D.new()
	var caja = BoxShape3D.new()
	caja.size = Vector3(ancho, alto, profundidad)
	forma.shape = caja
	forma.position = Vector3(0, alto / 2.0, 0)   # el origen de la reja está en el suelo
	cuerpo.add_child(forma)


# Crea los barrotes verticales con punta y los dos travesaños horizontales.
func crear_barrotes():
	barrotes = Node3D.new()
	add_child(barrotes)

	var material = StandardMaterial3D.new()
	material.albedo_color = color_hierro
	material.metallic = 0.6
	material.roughness = 0.5

	var paso = ancho / cantidad_barrotes
	for i in cantidad_barrotes:
		var x = -ancho / 2.0 + paso * (i + 0.5)

		# Barrote vertical (deja 0.25 m arriba para la punta)
		var barra = MeshInstance3D.new()
		var cilindro = CylinderMesh.new()
		cilindro.top_radius = 0.04
		cilindro.bottom_radius = 0.04
		cilindro.height = alto - 0.25
		barra.mesh = cilindro
		barra.material_override = material
		barra.position = Vector3(x, (alto - 0.25) / 2.0, 0)
		barrotes.add_child(barra)

		# Punta de lanza (un cono)
		var punta = MeshInstance3D.new()
		var cono = CylinderMesh.new()
		cono.top_radius = 0.0
		cono.bottom_radius = 0.06
		cono.height = 0.25
		punta.mesh = cono
		punta.material_override = material
		punta.position = Vector3(x, alto - 0.125, 0)
		barrotes.add_child(punta)

	# Dos travesaños horizontales que unen todos los barrotes
	for y in [0.5, alto - 0.7]:
		var travesano = MeshInstance3D.new()
		var caja = BoxMesh.new()
		caja.size = Vector3(ancho, 0.1, 0.1)
		travesano.mesh = caja
		travesano.material_override = material
		travesano.position = Vector3(0, y, 0)
		barrotes.add_child(travesano)


# Abre la reja: primero tiembla y después sube. Llámala una sola vez.
func abrir():
	if abierta:
		return
	abierta = true

	var t = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	# 1) Temblor: los barrotes se mueven rápido de lado a lado
	var pasos = int(tiempo_temblor / 0.05)
	for i in pasos:
		var lado = 1.0 if i % 2 == 0 else -1.0
		t.tween_property(barrotes, "position:x", lado * intensidad_temblor, 0.05)
	t.tween_property(barrotes, "position:x", 0.0, 0.05)
	# 2) Subida: sube toda la reja (la colisión sube con ella, así el paso se va abriendo)
	t.tween_property(self, "position:y", position.y + alto + 0.3, tiempo_subida) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(terminar_apertura)


# Cuando termina de subir se quita la colisión por completo y se oculta.
func terminar_apertura():
	cuerpo.collision_layer = 0
	cuerpo.collision_mask = 0
	visible = false
	reja_abierta.emit()

# Cuántos segundos dura la apertura completa (temblor + subida).
func duracion_apertura() -> float:
	return int(tiempo_temblor / 0.05) * 0.05 + 0.05 + tiempo_subida
