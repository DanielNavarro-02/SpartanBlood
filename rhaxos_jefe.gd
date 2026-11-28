extends CharacterBody3D

enum Estado { INACTIVO, ACECHAR, AVISO, GOLPE, RECARGA, DERROTADO }

@onready var anim = get_node_or_null("Modelo/AnimationPlayer")

@export var vida_maxima: int = 12
@export var rapidez: float = 3.2
@export var radio_activacion: float = 12.0
@export var rango_ataque: float = 2.2
@export var alcance_golpe: float = 2.6
@export var tiempo_aviso: float = 0.65
@export var tiempo_recarga: float = 1.0
@export var danio_golpe: int = 2
@export var obolos_recompensa: int = 25
@export var sangre_recompensa: int = 2
@export var fuerza_amortiguacion_retroceso: float = 8.0
@export var botas_hermes_pickup_scene: PackedScene

var vida: int = 12
var estado: Estado = Estado.INACTIVO
var reloj: float = 0.0
var jugador: Node3D = null
var velocidad_retroceso: Vector3 = Vector3.ZERO
var _golpe_aplicado: bool = false


func _ready() -> void:
	vida = vida_maxima
	if not is_in_group("enemigos"):
		add_to_group("enemigos")
	jugador = get_tree().get_first_node_in_group("jugador")


func _physics_process(delta: float) -> void:
	if jugador == null:
		jugador = get_tree().get_first_node_in_group("jugador")

	velocidad_retroceso = velocidad_retroceso.move_toward(Vector3.ZERO, fuerza_amortiguacion_retroceso * delta)
	if not is_on_floor():
		velocity += get_gravity() * delta

	if estado == Estado.DERROTADO:
		velocity.x = velocidad_retroceso.x * 0.25
		velocity.z = 0.0
		move_and_slide()
		return

	reloj = maxf(reloj - delta, 0.0)
	var nuevo := _decidir()
	if nuevo != estado:
		_cambiar(nuevo)

	match estado:
		Estado.INACTIVO:
			velocity.x = 0.0
			velocity.z = 0.0
			_reproducir(["Idle", "idle"])
		Estado.ACECHAR:
			if jugador != null:
				var dx := jugador.global_position.x - global_position.x
				var dir_x := signf(dx)
				velocity.x = dir_x * rapidez
				velocity.z = 0.0
				if absf(dir_x) > 0.0:
					rotation.y = -PI * 0.5 * dir_x
				_reproducir(["Correr", "walk", "Idle", "idle"])
		Estado.AVISO:
			velocity.x = 0.0
			velocity.z = 0.0
			_mirar_jugador()
			_reproducir(["Aviso", "interact-right", "Idle", "idle"])
		Estado.GOLPE:
			velocity.x = 0.0
			velocity.z = 0.0
			_mirar_jugador()
			_reproducir(["Atacar", "attack-melee-right", "Idle", "idle"])
			if not _golpe_aplicado and reloj <= 0.18:
				_golpe_aplicado = true
				_golpear_jugador()
		Estado.RECARGA:
			velocity.x = 0.0
			velocity.z = 0.0
			_reproducir(["Idle", "idle"])

	velocity.x += velocidad_retroceso.x
	move_and_slide()
	velocity.x -= velocidad_retroceso.x


func _decidir() -> Estado:
	if jugador == null:
		return Estado.INACTIVO
	var dist := _distancia_xz()
	match estado:
		Estado.INACTIVO:
			if dist <= radio_activacion:
				return Estado.ACECHAR
		Estado.ACECHAR:
			if dist <= rango_ataque:
				return Estado.AVISO
		Estado.AVISO:
			if reloj <= 0.001:
				return Estado.GOLPE
		Estado.GOLPE:
			if reloj <= 0.001:
				return Estado.RECARGA
		Estado.RECARGA:
			if reloj <= 0.001:
				return Estado.ACECHAR
	return estado


func _cambiar(nuevo: Estado) -> void:
	estado = nuevo
	if estado == Estado.AVISO:
		reloj = tiempo_aviso
	elif estado == Estado.GOLPE:
		reloj = 0.42
		_golpe_aplicado = false
	elif estado == Estado.RECARGA:
		reloj = tiempo_recarga


func _mirar_jugador() -> void:
	if jugador == null:
		return
	var dx := jugador.global_position.x - global_position.x
	if absf(dx) > 0.05:
		rotation.y = -PI * 0.5 * signf(dx)


func _golpear_jugador() -> void:
	if jugador == null or _distancia_xz() > alcance_golpe:
		return
	var salud_pj := jugador.get_node_or_null("Salud")
	if salud_pj != null and salud_pj.has_method("recibir_golpe"):
		salud_pj.recibir_golpe(danio_golpe)
	if jugador.has_method("recibir_retroceso"):
		var dir := Vector3(signf(jugador.global_position.x - global_position.x), 0.0, 0.0)
		if dir.x == 0.0:
			dir.x = 1.0
		jugador.recibir_retroceso(dir, 9.0)


func recibir_golpe(cuanto: int) -> void:
	if estado == Estado.DERROTADO:
		return
	vida = maxi(vida - cuanto, 0)
	print("Rhaxos vida: ", vida, "/", vida_maxima)
	if vida <= 0:
		_derrotar()


func recibir_retroceso(direccion: Vector3, fuerza: float) -> void:
	if estado == Estado.DERROTADO:
		return
	velocidad_retroceso = direccion * (fuerza * 0.35)


func _derrotar() -> void:
	estado = Estado.DERROTADO
	remove_from_group("enemigos")

	if jugador != null:
		var salud_pj := jugador.get_node_or_null("Salud")
		if salud_pj != null:
			if salud_pj.has_method("agregar_obolos"):
				salud_pj.agregar_obolos(obolos_recompensa)
			if salud_pj.has_method("agregar_sangre"):
				salud_pj.agregar_sangre(sangre_recompensa)

	if botas_hermes_pickup_scene != null:
		var pickup := botas_hermes_pickup_scene.instantiate()
		get_parent().add_child(pickup)
		if pickup is Node3D:
			pickup.global_position = global_position + Vector3(0.0, 0.6, 0.0)
	elif jugador != null and jugador.has_method("desbloquear_botas_hermes"):
		jugador.desbloquear_botas_hermes()

	var dur_muerte := 0.5
	if anim != null:
		for n in ["Derrota", "Morir", "die"]:
			if anim.has_animation(n):
				anim.play(n)
				dur_muerte = maxf(anim.get_animation(n).length, 0.3)
				break
	await get_tree().create_timer(dur_muerte).timeout
	if is_inside_tree():
		queue_free()


func _distancia_xz() -> float:
	if jugador == null:
		return INF
	return Vector2(jugador.global_position.x - global_position.x, jugador.global_position.z - global_position.z).length()


func _reproducir(candidatos: Array[String]) -> void:
	if anim == null:
		return
	for nombre in candidatos:
		if anim.has_animation(nombre):
			if anim.current_animation != nombre or not anim.is_playing():
				anim.play(nombre)
			return
