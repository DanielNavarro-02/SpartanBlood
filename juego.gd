extends Node
## Autoload "Juego": progreso de la partida y efectos compartidos (hit-stop, sacudida, partículas).
## Los flags sobreviven a reiniciar la escena cuando el jugador muere.

signal aviso(texto: String, color: Color)
signal jefe_actualizado(nombre: String, vida: float, maxima: float)
signal jefe_oculto
signal jugador_murio
signal botas_obtenidas
signal mapa_obtenido
signal abrir_tienda(npc: Node)

var tiene_dash: bool = false
var tiene_mapa: bool = false
var jefe_derrotado: bool = false
var ui_abierta: bool = false      # true mientras hay tienda o mapa abiertos (el jugador no actúa)

var _hs_id: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func avisar(texto: String, color: Color = Color(1.0, 0.85, 0.4)) -> void:
	aviso.emit(texto, color)


func obtener_botas() -> void:
	tiene_dash = true
	botas_obtenidas.emit()
	avisar("BOTAS DE HERMES\nAhora puedes hacer Dash (clic derecho / gatillo derecho)", Color(1.0, 0.85, 0.35))


func obtener_mapa() -> void:
	tiene_mapa = true
	mapa_obtenido.emit()
	avisar("MAPA DE LAS RUINAS\nPulsa M para consultarlo", Color(0.9, 0.8, 0.55))


# ------------------------------------------------------------------ tiempo
## Congela casi todo un instante: da peso a los golpes.
func hitstop(dur: float, escala: float = 0.05) -> void:
	if dur <= 0.0:
		return
	_hs_id += 1
	var mi_id: int = _hs_id
	Engine.time_scale = escala
	await get_tree().create_timer(dur, true, false, true).timeout
	if _hs_id == mi_id:
		Engine.time_scale = 1.0


func sacudir(intensidad: float, dur: float = 0.2) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam != null and cam.has_method("sacudir"):
		cam.sacudir(intensidad, dur)


# ------------------------------------------------------------------ efectos
func chispas(pos: Vector3, color: Color = Color(1.0, 0.8, 0.4), cantidad: int = 10, fuerza: float = 5.0) -> void:
	var escena := get_tree().current_scene
	if escena == null:
		return
	var p := CPUParticles3D.new()
	var m := SphereMesh.new()
	m.radius = 0.07
	m.height = 0.14
	m.radial_segments = 6
	m.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	m.material = mat
	p.mesh = m
	p.amount = cantidad
	p.lifetime = 0.45
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = fuerza * 0.5
	p.initial_velocity_max = fuerza
	p.gravity = Vector3(0, -12, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	escena.add_child(p)
	p.global_position = pos
	p.emitting = true
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)


func polvo(pos: Vector3) -> void:
	chispas(pos + Vector3(0, 0.1, 0), Color(0.7, 0.62, 0.5), 8, 2.5)


func texto_flotante(pos: Vector3, texto: String, color: Color = Color.WHITE, tam: int = 56) -> void:
	var escena := get_tree().current_scene
	if escena == null:
		return
	var l := Label3D.new()
	l.text = texto
	l.modulate = color
	l.font_size = tam
	l.pixel_size = 0.01
	l.outline_size = 12
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	escena.add_child(l)
	l.global_position = pos
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "global_position:y", pos.y + 1.6, 0.9).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.5)
	tw.chain().tween_callback(l.queue_free)
