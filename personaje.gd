extends CharacterBody3D
## Espartano jugable: movimiento 2.5D + sistema de combate.
##
## COMBATE
##  - Combo de 3 golpes (clic izq.): tajo, tajo ascendente y remate pesado (2 de daño).
##  - Buffer de entrada: si pulsas un poco antes de poder, el golpe sale solo.
##  - Golpe aéreo (tajo hacia abajo) si atacas en el aire.
##  - Cada golpe tiene fases: preparación -> ACTIVO (hace daño) -> recuperación (se puede cancelar encadenando).
##  - Impactos con hit-stop, sacudida de cámara, chispas y retroceso del enemigo.
##  - Dash (clic der.) con invulnerabilidad; solo tras conseguir las Botas de Hermes.
##  - Al recibir daño: aturdimiento corto, retroceso, parpadeo de invulnerabilidad.

enum Estado { QUIETO, CAMINAR, AIRE }
const RUIDO = [0.0, 2.0, 0.0]   # metros, en el mismo orden del enum

# ini/fin = ventana ACTIVA (fracción de la animación). cancela = desde cuándo se puede encadenar.
const ATAQUES := [
	{"clip": "ataque1", "dur": 0.46, "ini": 0.34, "fin": 0.58, "cancela": 0.62, "danio": 1,
	 "empuje": 5.0, "lunge": 3.0, "alcance": 2.4, "stop": 0.05, "shake": 0.06},
	{"clip": "ataque2", "dur": 0.46, "ini": 0.34, "fin": 0.58, "cancela": 0.64, "danio": 1,
	 "empuje": 5.5, "lunge": 3.5, "alcance": 2.5, "stop": 0.05, "shake": 0.07},
	{"clip": "ataque3", "dur": 0.78, "ini": 0.54, "fin": 0.72, "cancela": 2.0, "danio": 2,
	 "empuje": 10.0, "lunge": 5.5, "alcance": 3.0, "stop": 0.12, "shake": 0.22},
]
const ATAQUE_AIRE := {"clip": "ataque_aire", "dur": 0.42, "ini": 0.40, "fin": 0.75, "cancela": 2.0, "danio": 1,
	"empuje": 6.0, "lunge": 1.5, "alcance": 2.4, "stop": 0.06, "shake": 0.08}

@onready var salud = $Salud
@onready var rig: RigSegmentado = $Rig
@export var speed = 6.0
@export var tiempo_arranque = 0.15
@export var gravedad = 30.0
@export var altura_salto = 4.0
@export var fuerza_dash = 18.0
@export var duracion_dash = 0.22
@export var cooldown_dash = 0.6
@export var rango_ataque_jugador = 1.8   # (se conserva por compatibilidad; el alcance ahora va por golpe)
@export var danio_jugador = 1            # multiplicador del daño de cada golpe
@export var fuerza_empuje_jugador = 5.0  # (compatibilidad)
@export var tiempo_buffer = 0.22         # cuánto "recuerda" un clic adelantado
@export var ventana_combo = 0.4          # tiempo tras un golpe para seguir el combo
@export var slash_scene: PackedScene
@export var fuerza_amortiguacion_retroceso = 12.0

# Enchufes: otros scripts (las acciones del juego) cambian estas tres variables.
var multiplicador = 1.0     # 1 = rapidez normal, 0.5 = la mitad, 0 = quieto
var empuje = Vector3.ZERO   # velocidad extra en m/s (dash, retroceso)
var accion = ""             # "" = libre, "Atacar" o "dash"
var avance = 0.0
var tiempo_dash = 0.0
var tiempo_cooldown = 0.0
var direccion_dash = 1.0
var velocidad_retroceso = Vector3.ZERO

var estado = Estado.QUIETO
var ruido = 0.0
var coyote = 0.0            # tiempo de gracia para saltar

# Combate
var mirando: float = 1.0           # +1 derecha, -1 izquierda
var atacando := false
var ataque_actual: Dictionary = {}
var t_ataque := 0.0
var combo := 0
var t_combo := 0.0
var buffer_ataque := 0.0
var golpeados: Array = []
var lunge_vel := 0.0
var bloqueo := 0.0                 # aturdido / curándose: no puede actuar
var muerto := false
var dash_aereo_usado := false
var aviso_dash_t := 0.0
var _en_suelo_antes := true


func _ready():
	rotation.y = -PI / 2.0
	salud.jugador_muerto.connect(_morir)


func _physics_process(delta):
	var bloqueado: bool = Juego.ui_abierta or muerto
	velocidad_retroceso = velocidad_retroceso.move_toward(Vector3.ZERO, fuerza_amortiguacion_retroceso * delta)
	lunge_vel = move_toward(lunge_vel, 0.0, 28.0 * delta)
	bloqueo = maxf(bloqueo - delta, 0.0)
	buffer_ataque = maxf(buffer_ataque - delta, 0.0)
	aviso_dash_t = maxf(aviso_dash_t - delta, 0.0)
	t_combo = maxf(t_combo - delta, 0.0)
	if t_combo <= 0.0 and not atacando:
		combo = 0

	# Gravedad y coyote
	if is_on_floor():
		coyote = 0.10
		dash_aereo_usado = false
	else:
		coyote -= delta
		velocity.y -= gravedad * delta

	var libre: bool = not bloqueado and bloqueo <= 0.0

	if libre:
		if Input.is_action_just_pressed("curarse"):
			_curar()
		if Input.is_action_just_pressed("saltar") and coyote > 0.0 and (not atacando or t_ataque > 0.7):
			velocity.y = sqrt(2 * gravedad * altura_salto)
			coyote = 0.0
			if atacando:
				_terminar_ataque(false)
		if Input.is_action_just_pressed("Atacar"):
			buffer_ataque = tiempo_buffer
		if buffer_ataque > 0.0 and _puede_atacar():
			_iniciar_ataque()
		if Input.is_action_just_pressed("dash"):
			_intentar_dash()

	# Fase activa del ataque
	if atacando:
		t_ataque += delta / float(ataque_actual["dur"])
		if t_ataque >= float(ataque_actual["ini"]) and t_ataque <= float(ataque_actual["fin"]):
			_aplicar_golpes()
		if t_ataque >= 1.0:
			_terminar_ataque(true)

	# Dash
	tiempo_cooldown = maxf(tiempo_cooldown - delta, 0.0)
	tiempo_dash = maxf(tiempo_dash - delta, 0.0)
	if tiempo_dash > 0.0:
		empuje.x = direccion_dash * fuerza_dash
		velocity.y = 0.0
	else:
		empuje.x = 0.0
		if accion == "dash":
			accion = ""

	# Movimiento horizontal con arranque y frenado
	var lado := 0.0
	if libre:
		lado = Input.get_axis("move_left", "move_right")
	var mult: float = multiplicador * (0.3 if atacando else 1.0)
	var paso: float = float(speed) / float(tiempo_arranque) * delta
	avance = move_toward(avance, lado * speed * mult, paso)
	velocity.x = avance + empuje.x + velocidad_retroceso.x + lunge_vel

	if lado != 0.0 and not atacando and tiempo_dash <= 0.0:
		mirando = signf(lado)
	rotation.y = -PI / 2.0 * mirando

	move_and_slide()

	if is_on_floor() and not _en_suelo_antes and velocity.y < 0.5:
		Juego.polvo(global_position)
	_en_suelo_antes = is_on_floor()

	# Estado, ruido y animación
	estado = elegir_estado()
	ruido = RUIDO[estado]
	animar()
	_prueba()


func _process(_delta):
	# Parpadeo mientras dura la invulnerabilidad tras recibir daño
	if salud.reloj > 0.001 and not muerto:
		rig.visible = int(Time.get_ticks_msec() / 70.0) % 2 == 0
	else:
		rig.visible = true


# ------------------------------------------------------------------ ataque
func _puede_atacar() -> bool:
	if tiempo_dash > 0.0:
		return false
	if not atacando:
		return true
	return t_ataque >= float(ataque_actual["cancela"])


func _iniciar_ataque() -> void:
	var aire := not is_on_floor()
	if aire:
		ataque_actual = ATAQUE_AIRE
	else:
		ataque_actual = ATAQUES[combo]
		combo = (combo + 1) % ATAQUES.size()
	var lado := Input.get_axis("move_left", "move_right")
	if lado != 0.0:
		mirando = signf(lado)
	atacando = true
	accion = "Atacar"
	t_ataque = 0.0
	golpeados.clear()
	buffer_ataque = 0.0
	lunge_vel = mirando * float(ataque_actual["lunge"])
	if aire:
		velocity.y = maxf(velocity.y, 1.0)
	rig.reproducir(String(ataque_actual["clip"]), float(ataque_actual["dur"]), 0.03)


func _terminar_ataque(natural: bool) -> void:
	atacando = false
	accion = ""
	t_ataque = 0.0
	if natural:
		t_combo = ventana_combo
	else:
		combo = 0


func _caja_ataque() -> AABB:
	var alc: float = float(ataque_actual["alcance"])
	var x0: float = global_position.x - 0.3 if mirando > 0.0 else global_position.x - alc
	return AABB(Vector3(x0, global_position.y - 0.2, -1.5), Vector3(alc + 0.3, 2.9, 3.0))


func _aplicar_golpes() -> void:
	var caja := _caja_ataque()
	for e in get_tree().get_nodes_in_group("enemigos"):
		if not is_instance_valid(e) or golpeados.has(e):
			continue
		var caja_e: AABB
		if e.has_method("caja_golpe"):
			caja_e = e.caja_golpe()
		else:
			caja_e = AABB(e.global_position + Vector3(-0.6, 0.0, -1.0), Vector3(1.2, 2.5, 2.0))
		if caja.intersects(caja_e):
			golpeados.append(e)
			_golpear(e, caja_e)


func _golpear(e: Node, caja_e: AABB) -> void:
	var d: float = float(ataque_actual["danio"]) * float(danio_jugador)
	if e.has_method("recibir_golpe"):
		e.recibir_golpe(d)
	if e.has_method("recibir_retroceso"):
		e.recibir_retroceso(Vector3(mirando, 0.0, 0.0), float(ataque_actual["empuje"]))
	var pos := Vector3(lerpf(global_position.x, caja_e.get_center().x, 0.75), global_position.y + 1.3, 0.0)
	var fuerte: bool = d >= 2.0
	Juego.chispas(pos, Color(1.0, 0.85, 0.5), 16 if fuerte else 9, 7.0 if fuerte else 5.0)
	Juego.hitstop(float(ataque_actual["stop"]))
	Juego.sacudir(float(ataque_actual["shake"]), 0.18)


# ------------------------------------------------------------------ dash
func _intentar_dash() -> void:
	if not Juego.tiene_dash:
		if aviso_dash_t <= 0.0:
			Juego.avisar("Necesitas las Botas de Hermes para hacer Dash", Color(0.9, 0.7, 0.4))
			aviso_dash_t = 3.0
		return
	if tiempo_cooldown > 0.0:
		return
	if not is_on_floor() and dash_aereo_usado:
		return
	if atacando:
		_terminar_ataque(false)
	var lado := Input.get_axis("move_left", "move_right")
	direccion_dash = signf(lado) if lado != 0.0 else mirando
	mirando = direccion_dash
	tiempo_dash = duracion_dash
	tiempo_cooldown = cooldown_dash
	accion = "dash"
	if not is_on_floor():
		dash_aereo_usado = true
	rig.reproducir("dash", duracion_dash, 0.03)
	Juego.polvo(global_position)
	Juego.sacudir(0.04, 0.1)


# ------------------------------------------------------------------ curar / daño / muerte
func _curar() -> void:
	if salud.curarse():
		rig.reproducir("curar", 0.5, 0.05)
		bloqueo = 0.4
		Juego.chispas(global_position + Vector3(0, 1.5, 0), Color(0.9, 0.15, 0.15), 12, 3.0)
		Juego.texto_flotante(global_position + Vector3(0, 3.0, 0.5), "+1", Color(1.0, 0.4, 0.4))


## Lo llaman enemigos y trampas. Devuelve true si el daño se aplicó (false: esquivado o invulnerable).
func recibir_dano(cantidad: int, direccion: Vector3 = Vector3.ZERO, fuerza: float = 6.0) -> bool:
	if muerto or tiempo_dash > 0.0:
		return false
	if not salud.recibir_golpe(cantidad):
		return false
	if muerto:
		return true
	if atacando:
		_terminar_ataque(false)
	combo = 0
	var dir := Vector3(signf(direccion.x) if absf(direccion.x) > 0.01 else -mirando, 0.0, 0.0)
	velocidad_retroceso = dir * fuerza
	lunge_vel = 0.0
	bloqueo = 0.28
	buffer_ataque = 0.0
	rig.reproducir("dano", 0.32, 0.03)
	rig.destello(Color(1.0, 0.2, 0.2), 0.18, 0.7)
	Juego.chispas(global_position + Vector3(0, 1.3, 0), Color(0.8, 0.1, 0.1), 10, 4.5)
	Juego.hitstop(0.09)
	Juego.sacudir(0.22, 0.25)
	return true


func _morir() -> void:
	muerto = true
	atacando = false
	accion = ""
	avance = 0.0
	rig.visible = true
	rig.reproducir("muerte", -1.0, 0.05)
	Juego.hitstop(0.18)
	Juego.sacudir(0.35, 0.5)
	Juego.jugador_murio.emit()


func recibir_retroceso(direccion: Vector3, fuerza: float):
	velocidad_retroceso = direccion * fuerza


# ------------------------------------------------------------------ estado y animación
func elegir_estado():
	if not is_on_floor():
		return Estado.AIRE
	if absf(velocity.x) < 0.1:
		return Estado.QUIETO
	return Estado.CAMINAR


func animar():
	if muerto or atacando or tiempo_dash > 0.0 or bloqueo > 0.0:
		return
	if not is_on_floor():
		rig.reproducir("salto" if velocity.y > 0.5 else "caida", -1.0, 0.08, false)
	elif absf(avance) > 0.3:
		rig.reproducir("correr", -1.0, 0.1, false)
		rig.velocidad(clampf(absf(avance) / speed, 0.6, 1.3))
	else:
		rig.reproducir("idle", -1.0, 0.15, false)


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
	t += " · animación " + str(rig.clip_actual)
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
