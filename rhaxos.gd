extends CharacterBody3D
## Rhaxos, guardián de las raíces: jefe final de la demo.
##
## Despierta cuando el jugador entra a su arena (después de la presentación de cámara).
## ATAQUES
##   Raíces  : marcas rojas en el suelo -> púas brotan de la tierra (esquiva moviéndote / dash).
##   Onda    : se inclina y aplasta; una onda recorre el suelo (SÁLTALA).
##   Lluvia  : frutos espinosos caen del follaje sobre marcas rojas.
## FASE 2 (menos de 50% de vida): más púas, ondas dobles, lluvia más densa y menos pausas.
## Al morir suelta las Botas de Hermes (dash).

enum E { DORMIDO, RUGIENDO, IDLE, ATACANDO, MUERTO }

@export var nombre_jefe: String = "RHAXOS · Guardián de las Raíces"
@export var vida_max: float = 40.0
@export var radio_despertar: float = 26.0
@export var limite_izq: float = -134.0        # límites de la arena (x) para las marcas
@export var limite_der: float = -99.0

var vida: float
var estado: int = E.DORMIDO
var fase: int = 1
var reloj: float = 0.0
var _ultimo: int = -1
var _contacto_t: float = 0.0
var jugador: Node3D = null
@onready var rig: RigSegmentado = $Rig


func _ready() -> void:
	vida = vida_max
	add_to_group("jefe")
	jugador = get_tree().get_first_node_in_group("jugador")
	if Juego.jefe_derrotado:
		# Ya lo venciste: no reaparece. Si no recogiste las botas, vuelven a estar aquí.
		if not Juego.tiene_dash:
			_soltar_botas.call_deferred(Vector3(0, 0.3, 0), Vector3.ZERO)
		queue_free()
		return
	rig.reproducir("idle")


# Caja con la que el jugador comprueba si lo alcanza (todo el tronco).
func caja_golpe() -> AABB:
	return AABB(global_position + Vector3(-2.4, 0.0, -1.5), Vector3(4.8, 7.0, 3.0))


func _suelo() -> float:
	return global_position.y


func _esperar(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _physics_process(delta: float) -> void:
	if estado == E.MUERTO:
		return
	if jugador == null or not is_instance_valid(jugador):
		jugador = get_tree().get_first_node_in_group("jugador")
		return
	match estado:
		E.DORMIDO:
			_vigilar()
		E.IDLE:
			if rig.clip_actual == "dano" and rig.terminado:
				rig.reproducir("idle", -1.0, 0.15)
			reloj -= delta
			if reloj <= 0.0 and not _jugador_muerto():
				_elegir_ataque()
	_contacto(delta)


func _jugador_muerto() -> bool:
	var s = jugador.get_node_or_null("Salud")
	return s != null and s.muerto


func _vigilar() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam is CamaraSeguidora and cam.presentando:
		return                                  # espera a que termine la presentación de la zona
	var d: Vector3 = jugador.global_position - global_position
	if absf(d.x) < radio_despertar and absf(d.y) < 14.0:
		_despertar()


func _despertar() -> void:
	estado = E.RUGIENDO
	rig.reproducir("rugido", 2.2, 0.15)
	Juego.sacudir(0.3, 1.2)
	Juego.jefe_actualizado.emit(nombre_jefe, vida, vida_max)
	await _esperar(2.2)
	if estado == E.MUERTO:
		return
	estado = E.IDLE
	reloj = 0.8
	rig.reproducir("idle", -1.0, 0.3)


# Daño por contacto: pegarse al tronco duele (el punto ideal es a 3-4.5 m).
func _contacto(delta: float) -> void:
	_contacto_t = maxf(_contacto_t - delta, 0.0)
	if estado == E.DORMIDO or estado == E.RUGIENDO or _contacto_t > 0.0:
		return
	var d: Vector3 = jugador.global_position - global_position
	if absf(d.x) < 2.8 and d.y < 7.0 and d.y > -1.0:
		_contacto_t = 0.9
		if jugador.has_method("recibir_dano"):
			jugador.recibir_dano(1, Vector3(signf(d.x) if absf(d.x) > 0.05 else 1.0, 0, 0), 9.0)


# ------------------------------------------------------------------ ataques
func _elegir_ataque() -> void:
	var opciones: Array = [0, 1, 2]
	opciones.erase(_ultimo)
	_ultimo = opciones[randi() % opciones.size()]
	estado = E.ATACANDO
	match _ultimo:
		0:
			_ataque_raices()
		1:
			_ataque_onda()
		_:
			_ataque_lluvia()


func _fin_ataque() -> void:
	if estado == E.MUERTO:
		return
	rig.reproducir("idle", -1.0, 0.3)
	estado = E.IDLE
	reloj = randf_range(1.0, 1.7) if fase == 1 else randf_range(0.4, 0.9)


func _ataque_raices() -> void:
	rig.reproducir("aviso", 0.9, 0.1)
	var offs: Array = [0.0, -3.5, 3.5, -7.0, 7.0]
	var n: int = 3 if fase == 1 else 5
	var px: float = jugador.global_position.x
	var xs: Array = []
	for i in range(n):
		xs.append(clampf(px + float(offs[i]), limite_izq, limite_der))
		_marca(xs[i], 1.0)
	await _esperar(0.9)
	if estado == E.MUERTO:
		return
	rig.reproducir("golpe", 0.5, 0.05)
	Juego.sacudir(0.25, 0.3)
	for x in xs:
		_pincho(x)
	await _esperar(1.1)
	if estado == E.MUERTO:
		return
	rig.reproducir("recuperar", 0.8, 0.1)
	await _esperar(0.8)
	_fin_ataque()


func _ataque_onda() -> void:
	rig.reproducir("aviso", 0.9, 0.1)
	await _esperar(0.9)
	if estado == E.MUERTO:
		return
	rig.reproducir("golpe", 0.5, 0.05)
	Juego.sacudir(0.35, 0.4)
	_onda(1.0)
	if fase == 2:
		_onda(-1.0)
		await _esperar(0.75)
		if estado == E.MUERTO:
			return
		Juego.sacudir(0.25, 0.3)
		_onda(1.0)
		await _esperar(0.5)
	else:
		await _esperar(0.7)
	if estado == E.MUERTO:
		return
	rig.reproducir("recuperar", 0.8, 0.1)
	await _esperar(0.8)
	_fin_ataque()


func _ataque_lluvia() -> void:
	rig.reproducir("lluvia", 1.4, 0.1)
	var n: int = 5 if fase == 1 else 9
	var px: float = jugador.global_position.x
	for i in range(n):
		var x: float = clampf(px + randf_range(-8.0, 8.0), limite_izq, limite_der)
		_marca(x, 1.1)
		_fruto(x)
		await _esperar(0.14)
		if estado == E.MUERTO:
			return
	await _esperar(1.2)
	_fin_ataque()


# ------------------------------------------------------------------ piezas de los ataques
func _material(color: Color, emision: Color, energia: float = 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	if energia > 0.0:
		m.emission_enabled = true
		m.emission = emision
		m.emission_energy_multiplier = energia
	return m


func _marca(x: float, dur: float) -> void:
	var mi := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = 0.9
	cil.bottom_radius = 0.9
	cil.height = 0.05
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1.0, 0.12, 0.05, 0.55)
	cil.material = m
	mi.mesh = cil
	get_parent().add_child(mi)
	mi.global_position = Vector3(x, _suelo() + 0.06, 0.0)
	var tw := mi.create_tween()
	tw.set_loops(int(dur / 0.2))
	tw.tween_property(m, "albedo_color:a", 0.15, 0.1)
	tw.tween_property(m, "albedo_color:a", 0.7, 0.1)
	get_tree().create_timer(dur).timeout.connect(mi.queue_free)


func _pincho(x: float) -> void:
	var p := Peligro.new()
	p.caja = Vector3(1.0, 3.0, 1.6)
	p.danio = 1
	p.retroceso = 8.0
	p.vida = 1.2
	p.activo_desde = 0.05
	p.activo_hasta = 0.7
	var visual := Node3D.new()
	var mi := MeshInstance3D.new()
	var cono := CylinderMesh.new()
	cono.top_radius = 0.0
	cono.bottom_radius = 0.55
	cono.height = 3.2
	cono.material = _material(Color(0.22, 0.12, 0.06), Color(1.0, 0.35, 0.05), 0.8)
	mi.mesh = cono
	mi.position = Vector3(0, 1.6, 0)
	visual.add_child(mi)
	p.add_child(visual)
	get_parent().add_child(p)
	p.global_position = Vector3(x, _suelo(), 0.0)
	visual.scale = Vector3(1, 0.05, 1)
	var tw := visual.create_tween()
	tw.tween_property(visual, "scale:y", 1.0, 0.1).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.6)
	tw.tween_property(visual, "scale:y", 0.02, 0.35)
	Juego.chispas(Vector3(x, _suelo() + 0.3, 0.0), Color(0.5, 0.35, 0.2), 10, 4.0)


func _onda(dir: float) -> void:
	var p := Peligro.new()
	p.caja = Vector3(1.6, 1.5, 2.0)
	p.danio = 1
	p.retroceso = 8.0
	p.vida = 3.4
	p.velocidad = Vector3(dir * 9.0, 0, 0)
	var mi := MeshInstance3D.new()
	var esf := SphereMesh.new()
	esf.radius = 0.8
	esf.height = 1.6
	esf.material = _material(Color(0.3, 0.17, 0.08), Color(1.0, 0.4, 0.05), 1.2)
	mi.mesh = esf
	mi.position = Vector3(0, 0.6, 0)
	mi.scale = Vector3(1.3, 0.9, 1.3)
	p.add_child(mi)
	var luz := OmniLight3D.new()
	luz.light_color = Color(1.0, 0.45, 0.1)
	luz.light_energy = 1.5
	luz.omni_range = 5.0
	luz.position = Vector3(0, 1.0, 0.5)
	p.add_child(luz)
	get_parent().add_child(p)
	p.global_position = Vector3(global_position.x + dir * 2.4, _suelo(), 0.0)


func _fruto(x: float) -> void:
	var p := Peligro.new()
	p.caja = Vector3(1.0, 1.0, 1.0)
	p.danio = 1
	p.retroceso = 6.0
	p.vida = 4.0
	p.gravedad = 22.0
	p.suelo_y = _suelo()
	p.destruir_al_tocar_suelo = true
	p.destruir_al_golpear = true
	p.al_suelo = func(pos: Vector3): Juego.chispas(pos + Vector3(0, 0.3, 0), Color(1.0, 0.45, 0.1), 14, 5.0)
	var mi := MeshInstance3D.new()
	var esf := SphereMesh.new()
	esf.radius = 0.5
	esf.height = 1.0
	esf.material = _material(Color(0.45, 0.05, 0.05), Color(1.0, 0.25, 0.05), 1.0)
	mi.mesh = esf
	mi.position = Vector3(0, 0.5, 0)
	p.add_child(mi)
	get_parent().add_child(p)
	p.global_position = Vector3(x, _suelo() + 13.0, 0.0)


# ------------------------------------------------------------------ recibir daño / morir
func recibir_golpe(cuanto) -> void:
	if estado == E.DORMIDO or estado == E.RUGIENDO or estado == E.MUERTO:
		return
	vida -= cuanto
	rig.destello(Color(1.0, 0.8, 0.5), 0.12, 0.55)
	Juego.texto_flotante(global_position + Vector3(randf_range(-1.5, 1.5), 6.5, 1.0), str(int(cuanto)), Color(1.0, 0.9, 0.5), 64)
	Juego.jefe_actualizado.emit(nombre_jefe, maxf(vida, 0.0), vida_max)
	if estado == E.IDLE:
		rig.reproducir("dano", 0.25, 0.03)
	if vida <= 0.0:
		_morir()
		return
	if fase == 1 and vida <= vida_max * 0.5:
		fase = 2
		rig.destello(Color(1.0, 0.4, 0.05), 0.5, 0.7)
		Juego.sacudir(0.3, 0.7)
		Juego.avisar("¡Rhaxos se enfurece!", Color(1.0, 0.45, 0.2))


func recibir_retroceso(_direccion: Vector3, _fuerza: float) -> void:
	pass                                        # es un árbol enorme: no se mueve


func _morir() -> void:
	estado = E.MUERTO
	remove_from_group("enemigos")
	collision_layer = 0
	Juego.jefe_oculto.emit()
	rig.quitar_resaltado()
	rig.reproducir("muerte", 2.6, 0.1)
	Juego.hitstop(1.2, 0.25)
	Juego.sacudir(0.5, 2.0)
	Juego.chispas(global_position + Vector3(0, 3.0, 0), Color(1.0, 0.45, 0.1), 40, 9.0)
	var salud = jugador.get_node_or_null("Salud")
	if salud != null:
		salud.agregar_obolos(30)
		salud.agregar_sangre(2)
	Juego.texto_flotante(global_position + Vector3(0, 7.5, 1.0), "+30 óbolos", Color(1.0, 0.85, 0.3), 70)
	await _esperar(2.6)
	Juego.jefe_derrotado = true
	_soltar_botas(Vector3(2.5, 6.0, 0.0), Vector3(3.5, 6.0, 0.0))
	rig.encoger(0.8)
	await _esperar(0.85)
	queue_free()


func _soltar_botas(desplazamiento: Vector3, impulso: Vector3) -> void:
	var b := BotasHermes.new()
	b.velocidad_inicial = impulso
	get_parent().add_child(b)
	b.global_position = global_position + desplazamiento
