extends CharacterBody3D

enum Estado { QUIETO, CAMINAR, AIRE }
const RUIDO = [0.0, 2.0, 0.0]   # metros, en el mismo orden del enum

@export var speed = 6.0
@export var tiempo_arranque = 0.15
@export var gravedad = 30.0
@export var altura_salto = 4.0
@onready var anim = $Modelo/AnimationPlayer
@export var fuerza_dash = 18.0
@export var duracion_dash = 0.2
@export var cooldown_dash = 0.6

@export var slash_scene: PackedScene

# Enchufes: otros scripts (las acciones del juego) cambian estas tres variables.
var multiplicador = 1.0     # 1 = rapidez normal, 0.5 = la mitad, 0 = quieto
var empuje = Vector3.ZERO   # velocidad extra en m/s (dash, retroceso)
var accion = ""             # animación de la acción; "" = ninguna
var avance = 0.0
var tiempo_dash = 0.0
var tiempo_cooldown = 0.0
var direccion_dash = 1.0

var estado = Estado.QUIETO
var ruido = 0.0
var coyote = 0.0            # tiempo de gracia para saltar


func _physics_process(delta):
	# Gravedad y coyote
	if is_on_floor():
		coyote = 0.10
	else:
		coyote -= delta
		velocity.y -= gravedad * delta

	# Salto (permitido mientras coyote > 0)
	if Input.is_action_just_pressed("saltar") and coyote > 0:
		velocity.y = sqrt(2 * gravedad * altura_salto)
		coyote = 0.0   # evita saltar dos veces
		
	# Atacar
	if Input.is_action_just_pressed("Atacar") and accion == "":
		crear_slash()  # efecto
	
	# dash
	tiempo_cooldown = maxf(tiempo_cooldown - delta, 0.0)
	tiempo_dash = maxf(tiempo_dash - delta, 0.0)
	
	# activar el dash
	if Input.is_action_just_pressed("dash") and tiempo_cooldown <= 0:
		# decide la direccion
		if absf(avance) > 0.1:
			direccion_dash = sign(avance) # hacia donde se mueve
		else:
			direccion_dash = -sign(rotation.y) # hacia donde mira
			
		tiempo_dash = duracion_dash
		tiempo_cooldown = cooldown_dash
		accion = "dash"
		
	# Aplicar o quitar el empuje
	if tiempo_dash > 0.0:
		empuje.x = direccion_dash * fuerza_dash
	else:
		empuje.x = 0.0
		if accion == "dash":
			accion = ""

	# Movimiento horizontal con arranque y frenado
	var lado = Input.get_axis("move_left", "move_right")
	var paso = speed / tiempo_arranque * delta
	avance = move_toward(avance, lado * speed * multiplicador, paso)
	velocity.x = avance + empuje.x

	if lado != 0:
		rotation.y = -PI / 2 * sign(lado)   # mira hacia +X o hacia -X

	move_and_slide()

	# Estado, ruido y animación
	var antes = estado
	estado = elegir_estado()
	ruido = RUIDO[estado]
	if estado != antes:
		print("estado ", Estado.keys()[estado], " · ruido ", ruido, " m")
	animar()
	_prueba()
	
func crear_slash():
	if slash_scene == null:
		print("ERROR: slash_scene no está asignado")
		return
	
	var slash = slash_scene.instantiate()
	get_tree().current_scene.add_child(slash)
	
	# Dirección: +1 derecha, -1 izquierda
	var direccion = -sign(rotation.y)
	if direccion == 0:
		direccion = 1   # por si acaso
	
	# Posición delante del personaje
	slash.global_position = global_position + Vector3(direccion * 1.5, 1.1, 0)
	
	# Orientación segura para 2.5D
	slash.rotation_degrees = Vector3(0, 0, 0)  # limpio
	slash.scale = Vector3(direccion, 1, 1)     # solo volteamos en X
	
	# Activar partículas
	var particles = slash.get_node_or_null("GPUParticles3D")
	if particles:
		particles.emitting = true
		particles.restart()
		print("Slash creado en dirección: ", direccion)
	else:
		print("ERROR: No se encontró el nodo GPUParticles3D")

func elegir_estado():
	if not is_on_floor():
		return Estado.AIRE
	if absf(velocity.x) < 0.1:
		return Estado.QUIETO
	return Estado.CAMINAR


func animar():
	if accion != "":
		anim.play(accion)
		return
	match estado:
		Estado.QUIETO:
			anim.play("idle")
		Estado.CAMINAR:
			anim.play("walk")
		Estado.AIRE:
			anim.play("jump" if velocity.y > 0 else "fall")
	


# ---------------------------------------------------------------------------
# PRUEBAS AUTOMÁTICAS. No hace falta entender esta parte: en el Inspector del
# Personaje elijan "Prueba" (y, si la prueba usa una acción, escriban su nombre
# en "Accion Prueba"). Con F5 el personaje se mueve solo y escribe los números
# en el panel Output. La última línea de _physics_process() es _prueba().
# ---------------------------------------------------------------------------
@export_enum("Ninguna", "Avanzar 60 cuadros", "Avanzar 60 y soltar", "Avanzar y la acción desde el cuadro 30", "Mantener la acción 2 s", "Avanzar con la acción 60 cuadros", "Diagonal W+D 60 cuadros") var prueba = 0
@export var accion_prueba = ""
var _cuadro = 0
var _termino = false
var _y_max = 0.0
var _cuadro_max = 0


func _prueba():
	if prueba == 0 or _termino:
		return
	_cuadro += 1
	var avanzar = "move_right"
	var lado = "move_up"
	if _cuadro == 1:
		if prueba <= 3 or prueba == 5:
			_apretar(avanzar)
		if prueba == 4 or prueba == 5:
			_apretar(accion_prueba)
		if prueba == 6:
			_apretar(avanzar)
			_apretar(lado)
		return
	var n = _cuadro - 1
	if prueba == 3 and n == 30:
		_apretar(accion_prueba)
	if prueba == 2 and n == 60:
		Input.action_release(avanzar)
	var marcas = []
	if prueba == 1 or prueba == 5:
		marcas = [1, 2, 3, 5, 10, 15, 20, 30, 60]
	elif prueba == 2:
		marcas = [59, 60, 61, 62, 63, 65, 70, 80, 90]
	elif prueba == 3:
		marcas = [29, 30, 31, 32, 33, 35, 40, 45, 50, 60, 75, 90]
	elif prueba == 6:
		marcas = [1, 30, 60]
	else:
		marcas = [1, 15, 30, 45, 60, 75, 90, 105, 120, 135, 150]
	if n in marcas:
		print("[prueba] cuadro ", n, ": ", _resumen())
	_cambios(n)
	if global_position.y > _y_max + 0.0001:
		_y_max = global_position.y
		_cuadro_max = n
	if n == marcas[-1]:
		Input.action_release(avanzar)
		Input.action_release(lado)
		_soltar(accion_prueba)
		_termino = true
		if _y_max > 0.01:
			print("[prueba] altura máxima ", snappedf(_y_max, 0.01), " en el cuadro ", _cuadro_max)


func _resumen():
	var t = "posición " + str(global_position.snappedf(0.01))
	t += " · rapidez " + str(snappedf(absf(velocity.x), 0.01))
	t += " · y " + str(snappedf(global_position.y, 0.01))
	t += " · animación " + str(anim.current_animation)
	for nodo in _con_estado():
		t += " · " + str(nodo.name) + ".estado " + _nombre(nodo)
	return t


# Escribe el cuadro exacto en el que cambia cualquier variable "estado".
var _antes = {}


func _cambios(n):
	for nodo in _con_estado():
		var e = _nombre(nodo)
		if _antes.has(nodo) and _antes[nodo] != e:
			print("[prueba] cuadro ", n, ": ", nodo.name, ".estado cambia a ", e)
		_antes[nodo] = e


func _con_estado():
	var lista = []
	for nodo in [self] + get_children() + get_tree().get_nodes_in_group("probar"):
		if nodo.get_script() != null and "estado" in nodo:
			lista.append(nodo)
	return lista


func _nombre(nodo):
	var nombres = nodo.get_script().get_script_constant_map().get("Estado", {})
	for k in nombres:
		if nombres[k] == nodo.estado:
			return k
	return str(nodo.estado)


func _apretar(a):
	if a == "":
		print("[prueba] escriban el nombre de la acción en 'Accion Prueba'")
	elif not InputMap.has_action(a):
		print("[prueba] falta la acción '", a, "' en el Input Map")
	else:
		Input.action_press(a)


func _soltar(a):
	if a != "" and InputMap.has_action(a):
		Input.action_release(a)
