class_name Peligro
extends Node3D
## Zona de daño temporal (púa, onda, fruto que cae). El origen es el CENTRO DE LA BASE de la caja.
## Compara su caja con la del jugador cada cuadro (sin depender de capas de colisión).

var caja: Vector3 = Vector3(1, 1, 1)
var danio: int = 1
var retroceso: float = 7.0
var vida: float = 2.0                 # segundos hasta desaparecer
var activo_desde: float = 0.0
var activo_hasta: float = 99.0
var velocidad: Vector3 = Vector3.ZERO
var gravedad: float = 0.0
var suelo_y: float = -99999.0
var destruir_al_tocar_suelo: bool = false
var destruir_al_golpear: bool = false
var al_suelo: Callable = Callable()   # recibe la posición donde toca el suelo
var _t: float = 0.0
var _jugador: Node3D


func _ready() -> void:
	_jugador = get_tree().get_first_node_in_group("jugador")


func _physics_process(delta: float) -> void:
	_t += delta
	if gravedad != 0.0:
		velocidad.y -= gravedad * delta
	global_position += velocidad * delta
	if destruir_al_tocar_suelo and global_position.y <= suelo_y:
		global_position.y = suelo_y
		if al_suelo.is_valid():
			al_suelo.call(global_position)
		queue_free()
		return
	if _t >= vida:
		queue_free()
		return
	if _t < activo_desde or _t > activo_hasta:
		return
	if _jugador == null or not is_instance_valid(_jugador):
		return
	var p: Vector3 = _jugador.global_position
	var c: Vector3 = global_position
	if absf(p.x - c.x) < caja.x * 0.5 + 0.35 and p.y < c.y + caja.y and p.y + 1.9 > c.y:
		var lado: float = signf(p.x - c.x) if absf(p.x - c.x) > 0.05 else 1.0
		if _jugador.has_method("recibir_dano"):
			var ok = _jugador.recibir_dano(danio, Vector3(lado, 0, 0), retroceso)
			if ok and destruir_al_golpear:
				queue_free()
