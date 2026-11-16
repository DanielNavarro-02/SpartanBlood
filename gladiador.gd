extends CharacterBody3D

enum Estado { ACERCARSE, AVISO, GOLPE, RECARGA, HUIR }

@export var rapidez = 2.0
@export var rango_ataque = 1.2
@export var tiempo_aviso = 0.5
@export var tiempo_recarga = 1.2
@export var alcance_golpe = 1.5
@export var danio = 1
@export var vida = 3.0
@export var vida_huida = 1.0
@export var danio_prueba = 1.0
@export var fuerza_amortiguacion_retroceso = 10.0

var estado = Estado.ACERCARSE
var reloj = 0.0
var jugador = null
var velocidad_retroceso = Vector3.ZERO
@onready var anim = $Modelo/AnimationPlayer


func _ready():
	jugador = get_tree().get_first_node_in_group("jugador")


func _physics_process(delta):
	velocidad_retroceso = velocidad_retroceso.move_toward(Vector3.ZERO, fuerza_amortiguacion_retroceso * delta)
	
	velocity += get_gravity() * delta
	reloj = maxf(reloj - delta, 0.0)


	var nuevo = decidir()
	if nuevo != estado:
		cambiar_a(nuevo)

	match estado:
		Estado.ACERCARSE:
			ir_a(jugador.global_position)
		Estado.AVISO:
			frenar("interact-right")
		Estado.GOLPE:
			frenar("attack-melee-right")
			golpear()
		Estado.RECARGA:
			frenar("idle")
		Estado.HUIR:
			# Huir es perseguir con la flecha al revés.
			var lejos = global_position - jugador.global_position
			ir_a(global_position + lejos)
			
	var velocidad_final = velocity
	velocidad_final.x += velocidad_retroceso.x
	velocidad_final.z += velocidad_retroceso.z
	velocity = velocidad_final

	move_and_slide()
	velocity.x -= velocidad_retroceso.x
	velocity.z -= velocidad_retroceso.z


func decidir():
	# Va primero: le gana a cualquier estado, también al AVISO.
	if vida <= vida_huida:
		return Estado.HUIR
	match estado:
		Estado.ACERCARSE:
			if distancia() <= rango_ataque:
				return Estado.AVISO
		Estado.AVISO:
			if reloj <= 0.001:
				return Estado.GOLPE
		Estado.GOLPE:
			return Estado.RECARGA
		Estado.RECARGA:
			if reloj <= 0.001:
				return Estado.ACERCARSE
	return estado


# Se llama igual que en la diana del Taller 8: el rayo ya la sabe usar.
func recibir_golpe(cuanto):
	vida -= cuanto
	print(name, " vida ", vida)
	if vida <= 0:
		print(name, " vencido")
		print("+5 óbolos")
		queue_free()
		
func recibir_retroceso(direccion: Vector3, fuerza: float):
	velocidad_retroceso = direccion * fuerza


func cambiar_a(nuevo):
	estado = nuevo
	print(name, " -> ", Estado.keys()[estado], " cuadro ",
			Engine.get_physics_frames(), " a ",
			snappedf(distancia(), 0.01), " m")
	if estado == Estado.AVISO:
		reloj = tiempo_aviso
	elif estado == Estado.RECARGA:
		reloj = tiempo_recarga


func golpear():
	if distancia() > alcance_golpe:
		print(name, " falla a ", snappedf(distancia(), 0.01), " m")
		return
		
	if jugador != null:
		var salud = jugador.get_node_or_null("Salud")
		if salud != null:
			salud.recibir_golpe(danio)
			
		var direccion_empuje = (jugador.global_position - global_position).normalized()
		direccion_empuje.y = 0.0 
		
		if jugador.has_method("recibir_retroceso"):
			jugador.recibir_retroceso(direccion_empuje, 6.0)


func ir_a(destino):
	var hacia = destino - global_position
	hacia.y = 0.0
	var dir = hacia.normalized()
	velocity.x = dir.x * rapidez
	velocity.z = dir.z * rapidez
	basis = Basis.looking_at(dir)
	anim.play("walk")


func frenar(animacion):
	velocity.x = 0.0
	velocity.z = 0.0
	anim.play(animacion)


func distancia():
	var p = jugador.global_position
	var o = global_position
	return Vector2(p.x - o.x, p.z - o.z).length()
