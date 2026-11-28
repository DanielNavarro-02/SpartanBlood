extends CharacterBody3D
## Esqueleto gladiador.
## ACERCARSE -> AVISO (levanta la espada y brilla en rojo: es la señal para esquivar)
## -> GOLPE -> RECARGA. Si lo golpeas se aturde (interrumpe su aviso).
## Con poca vida huye un rato y luego vuelve enfurecido.

enum Estado { ACERCARSE, AVISO, GOLPE, RECARGA, HUIR, ATURDIDO }

@export var rapidez = 2.0
@export var radio_deteccion = 16.0
@export var rango_ataque = 1.4
@export var tiempo_aviso = 0.5
@export var tiempo_recarga = 1.2
@export var duracion_golpe = 0.38
@export var alcance_golpe = 1.7
@export var danio = 1
@export var vida = 3.0
@export var vida_huida = 1.0
@export var tiempo_huida = 3.0
@export var empuje_golpe = 6.0
@export var danio_prueba = 1.0
@export var fuerza_amortiguacion_retroceso = 10.0

var estado = Estado.ACERCARSE
var reloj = 0.0
var jugador = null
var velocidad_retroceso = Vector3.ZERO
var derrotado = false
var _golpe_hecho = false
var _ya_huyo = false
var _alertado = false
@onready var rig: RigSegmentado = $Rig


func _ready():
	jugador = get_tree().get_first_node_in_group("jugador")
	rig.reproducir("caminar")


# Caja con la que el jugador comprueba si lo alcanza.
func caja_golpe() -> AABB:
	return AABB(global_position + Vector3(-0.7, 0.0, -1.0), Vector3(1.4, 2.5, 2.0))


func _physics_process(delta):
	if derrotado:
		return
	if jugador == null or not is_instance_valid(jugador):
		jugador = get_tree().get_first_node_in_group("jugador")
		if jugador == null:
			return

	velocidad_retroceso = velocidad_retroceso.move_toward(Vector3.ZERO, fuerza_amortiguacion_retroceso * delta)
	velocity.y += get_gravity().y * delta
	reloj = maxf(reloj - delta, 0.0)

	var nuevo = decidir()
	if nuevo != estado:
		cambiar_a(nuevo)

	match estado:
		Estado.ACERCARSE:
			if not _alertado and distancia() > radio_deteccion:
				frenar()                       # aún no te ha visto
				rig.reproducir("idle", -1.0, 0.2, false)
			else:
				_alertado = true
				ir_a(jugador.global_position, 1.0)
		Estado.AVISO:
			frenar()
		Estado.GOLPE:
			frenar()
			if not _golpe_hecho and reloj <= duracion_golpe * 0.7:
				_golpe_hecho = true
				golpear()
		Estado.RECARGA:
			frenar()
		Estado.HUIR:
			ir_a(global_position + (global_position - jugador.global_position), 1.7)
		Estado.ATURDIDO:
			frenar()

	velocity.x += velocidad_retroceso.x
	velocity.z = 0.0
	move_and_slide()


func _jugador_muerto() -> bool:
	var s = jugador.get_node_or_null("Salud")
	return s != null and s.muerto


func decidir():
	if _jugador_muerto():
		return Estado.RECARGA
	if estado == Estado.ATURDIDO:
		return estado if reloj > 0.001 else Estado.RECARGA
	if estado == Estado.HUIR:
		if reloj <= 0.001:
			_ya_huyo = true
			return Estado.ACERCARSE
		return Estado.HUIR
	if not _ya_huyo and vida <= vida_huida:
		return Estado.HUIR
	match estado:
		Estado.ACERCARSE:
			if distancia() <= rango_ataque:
				return Estado.AVISO
		Estado.AVISO:
			if reloj <= 0.001:
				return Estado.GOLPE
		Estado.GOLPE:
			if reloj <= 0.001:
				return Estado.RECARGA
		Estado.RECARGA:
			if reloj <= 0.001:
				return Estado.ACERCARSE
	return estado


func cambiar_a(nuevo):
	estado = nuevo
	if estado != Estado.AVISO:
		rig.quitar_resaltado()
	match estado:
		Estado.ACERCARSE:
			rig.reproducir("caminar", -1.0, 0.12)
		Estado.AVISO:
			reloj = tiempo_aviso
			_mirar_hacia(jugador.global_position.x)
			rig.reproducir("aviso", tiempo_aviso, 0.08)
			rig.resaltar(Color(1.0, 0.1, 0.05), 0.3)      # telegrafía el golpe
		Estado.GOLPE:
			reloj = duracion_golpe
			_golpe_hecho = false
			rig.reproducir("golpe", duracion_golpe, 0.02)
		Estado.RECARGA:
			reloj = tiempo_recarga
			rig.reproducir("recarga", tiempo_recarga, 0.1)
		Estado.HUIR:
			reloj = tiempo_huida
			rig.reproducir("caminar", -1.0, 0.1)
		Estado.ATURDIDO:
			reloj = 0.35
			rig.reproducir("dano", 0.3, 0.03)


# Se llama igual que en la diana del Taller 8: el rayo ya la sabe usar.
func recibir_golpe(cuanto):
	if derrotado:
		return
	vida -= cuanto
	rig.destello(Color(1, 1, 1), 0.14, 0.85)
	Juego.texto_flotante(global_position + Vector3(0, 3.0, 0.5), str(int(cuanto)), Color(1.0, 0.9, 0.5), 48)
	if vida <= 0:
		_morir()
		return
	if estado != Estado.HUIR:
		cambiar_a(Estado.ATURDIDO)


func recibir_retroceso(direccion: Vector3, fuerza: float):
	velocidad_retroceso = direccion * fuerza


func _morir():
	derrotado = true
	remove_from_group("enemigos")
	collision_layer = 0                 # ya no estorba al jugador, pero sigue pisando el suelo
	velocity = Vector3.ZERO
	rig.quitar_resaltado()
	rig.reproducir("muerte", 1.1, 0.04)

	var j = get_tree().get_first_node_in_group("jugador")
	if j != null:
		var salud = j.get_node_or_null("Salud")
		if salud != null:
			salud.agregar_obolos(5)
			salud.agregar_sangre(1)
	Juego.texto_flotante(global_position + Vector3(0, 3.4, 0.5), "+5 óbolos", Color(1.0, 0.85, 0.3), 44)
	Juego.chispas(global_position + Vector3(0, 1.2, 0), Color(0.85, 0.85, 0.75), 18, 6.0)
	Juego.hitstop(0.1)

	await get_tree().create_timer(1.5).timeout
	rig.encoger(0.4)
	await get_tree().create_timer(0.45).timeout
	queue_free()


func golpear():
	if distancia() > alcance_golpe or absf(jugador.global_position.y - global_position.y) > 1.8:
		return                          # falló (el jugador se alejó o saltó)
	var dir = jugador.global_position - global_position
	dir.y = 0.0
	dir = dir.normalized()
	if jugador.has_method("recibir_dano"):
		jugador.recibir_dano(int(danio), dir, empuje_golpe)
	else:
		var salud = jugador.get_node_or_null("Salud")
		if salud != null:
			salud.recibir_golpe(danio)
		if jugador.has_method("recibir_retroceso"):
			jugador.recibir_retroceso(dir, empuje_golpe)


func _mirar_hacia(x: float):
	var dx = x - global_position.x
	if absf(dx) > 0.05:
		rotation.y = -PI / 2.0 * signf(dx)


func ir_a(destino, rel_rapidez: float):
	var hacia = destino - global_position
	hacia.y = 0.0
	var dir = hacia.normalized()
	velocity.x = dir.x * rapidez * rel_rapidez
	velocity.z = 0.0
	_mirar_hacia(global_position.x + dir.x)
	rig.reproducir("caminar", -1.0, 0.12, false)
	rig.velocidad(rel_rapidez)


func frenar():
	velocity.x = 0.0
	velocity.z = 0.0


func distancia():
	var p = jugador.global_position
	var o = global_position
	return Vector2(p.x - o.x, p.z - o.z).length()
