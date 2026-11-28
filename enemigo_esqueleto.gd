extends CharacterBody3D

enum Estado { PATRULLAR, PERSEGUIR, AVISO, GOLPE, RECARGA, MUERTO }

@onready var anim = $Modelo/AnimationPlayer

@export var rapidez_patrulla: float = 1.6
@export var rapidez_perseguir: float = 2.8
@export var radio_deteccion: float = 8.0
@export var rango_ataque: float = 1.5
@export var alcance_golpe: float = 1.8
@export var tiempo_aviso: float = 0.55
@export var tiempo_recarga: float = 1.1
@export var danio: int = 1
@export var vida: int = 3
@export var obolos_recompensa: int = 5
@export var sangre_recompensa: int = 1
@export var fuerza_amortiguacion_retroceso: float = 11.0

var estado: Estado = Estado.PATRULLAR
var reloj: float = 0.0
var jugador: Node3D = null
var velocidad_retroceso: Vector3 = Vector3.ZERO
var _golpe_ejecutado: bool = false
var _origen_x: float = 0.0
var _dir_patrulla: float = 1.0


func _ready() -> void:
	if not is_in_group("enemigos"):
		add_to_group("enemigos")
	_origen_x = global_position.x
	jugador = get_tree().get_first_node_in_group("jugador")


func _physics_process(delta: float) -> void:
	if jugador == null:
		jugador = get_tree().get_first_node_in_group("jugador")

	velocidad_retroceso = velocidad_retroceso.move_toward(Vector3.ZERO, fuerza_amortiguacion_retroceso * delta)

	if not is_on_floor():
		velocity += get_gravity() * delta

	if estado == Estado.MUERTO:
		velocity.x = velocidad_retroceso.x
		velocity.z = velocidad_retroceso.z
		move_and_slide()
		return

	reloj = maxf(reloj - delta, 0.0)
	var nuevo := _decidir_estado()
	if nuevo != estado:
		_cambiar_estado(nuevo)

	match estado:
		Estado.PATRULLAR:
			_patrullar(delta)
		Estado.PERSEGUIR:
			if jugador != null:
				_mover_hacia(jugador.global_position, rapidez_perseguir)
		Estado.AVISO:
			velocity.x = 0.0
			velocity.z = 0.0
			_mirar_hacia_jugador()
			_reproducir_si_existe(["interact-right", "idle", "Idle"])
		Estado.GOLPE:
			velocity.x = 0.0
			velocity.z = 0.0
			_mirar_hacia_jugador()
			_reproducir_si_existe(["attack-melee-right", "Atacar", "idle"])
			if not _golpe_ejecutado and reloj <= tiempo_aviso * 0.4:
				_golpe_ejecutado = true
				_ejecutar_golpe()
		Estado.RECARGA:
			velocity.x = 0.0
			velocity.z = 0.0
			_reproducir_si_existe(["idle", "Idle"])

	velocity.x += velocidad_retroceso.x
	velocity.z += velocidad_retroceso.z
	move_and_slide()
	velocity.x -= velocidad_retroceso.x
	velocity.z -= velocidad_retroceso.z


func _decidir_estado() -> Estado:
	if jugador == null:
		return Estado.PATRULLAR
	var dist := _distancia_jugador()
	match estado:
		Estado.PATRULLAR:
			if dist <= radio_deteccion:
				return Estado.PERSEGUIR
		Estado.PERSEGUIR:
			if dist > radio_deteccion * 1.35:
				return Estado.PATRULLAR
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
				return Estado.PERSEGUIR if dist <= radio_deteccion else Estado.PATRULLAR
	return estado


func _cambiar_estado(nuevo: Estado) -> void:
	estado = nuevo
	if estado == Estado.AVISO:
		reloj = tiempo_aviso
	elif estado == Estado.GOLPE:
		reloj = 0.35
		_golpe_ejecutado = false
	elif estado == Estado.RECARGA:
		reloj = tiempo_recarga


func _patrullar(_delta: float) -> void:
	if absf(global_position.x - _origen_x) > 3.5:
		_dir_patrulla = -signf(global_position.x - _origen_x)
	velocity.x = _dir_patrulla * rapidez_patrulla
	velocity.z = 0.0
	if absf(_dir_patrulla) > 0.0:
		rotation.y = -PI * 0.5 * _dir_patrulla
	_reproducir_si_existe(["walk", "Correr", "idle"])


func _mover_hacia(destino: Vector3, vel: float) -> void:
	var hacia := destino - global_position
	hacia.y = 0.0
	var dir_x := signf(hacia.x)
	velocity.x = dir_x * vel
	velocity.z = 0.0
	if absf(dir_x) > 0.0:
		rotation.y = -PI * 0.5 * dir_x
	_reproducir_si_existe(["walk", "Correr", "idle"])


func _mirar_hacia_jugador() -> void:
	if jugador == null:
		return
	var dx := jugador.global_position.x - global_position.x
	if absf(dx) > 0.05:
		rotation.y = -PI * 0.5 * signf(dx)


func _ejecutar_golpe() -> void:
	if jugador == null or _distancia_jugador() > alcance_golpe:
		return
	var salud_pj := jugador.get_node_or_null("Salud")
	if salud_pj != null and salud_pj.has_method("recibir_golpe"):
		salud_pj.recibir_golpe(danio)
	if jugador.has_method("recibir_retroceso"):
		var dir := Vector3(signf(jugador.global_position.x - global_position.x), 0.0, 0.0)
		if dir.x == 0.0:
			dir.x = 1.0
		jugador.recibir_retroceso(dir, 6.0)


func recibir_golpe(cuanto: int) -> void:
	if estado == Estado.MUERTO:
		return
	vida -= cuanto
	if vida <= 0:
		_morir()


func recibir_retroceso(direccion: Vector3, fuerza: float) -> void:
	velocidad_retroceso = direccion * fuerza


func _morir() -> void:
	estado = Estado.MUERTO
	remove_from_group("enemigos")
	if jugador != null:
		var salud_pj := jugador.get_node_or_null("Salud")
		if salud_pj != null:
			if salud_pj.has_method("agregar_obolos"):
				salud_pj.agregar_obolos(obolos_recompensa)
			if salud_pj.has_method("agregar_sangre"):
				salud_pj.agregar_sangre(sangre_recompensa)

	var dur_muerte := 0.35
	if anim != null and anim.has_animation("die"):
		anim.play("die")
		dur_muerte = maxf(anim.get_animation("die").length, 0.2)
	await get_tree().create_timer(dur_muerte).timeout
	if is_inside_tree():
		queue_free()


func _distancia_jugador() -> float:
	if jugador == null:
		return INF
	return Vector2(jugador.global_position.x - global_position.x, jugador.global_position.z - global_position.z).length()


func _reproducir_si_existe(candidatos: Array[String]) -> void:
	if anim == null:
		return
	for nombre in candidatos:
		if anim.has_animation(nombre):
			if anim.current_animation != nombre or not anim.is_playing():
				anim.play(nombre)
			return
