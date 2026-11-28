class_name EstelaEspada
extends MeshInstance3D
# ---------------------------------------------------------------------------
# ESTELA DE LA ESPADA
# Dibuja una cinta que sigue a la espada mientras corta, dejando una "cola"
# que se desvanece rápido. Funciona con cualquier animación o rig, porque solo
# necesita saber dónde están dos puntos de la espada:
#   - BaseEspada  (la empuñadura)   - PuntaEspada  (la punta)
# Colores:
#   - Blanco  = el golpe va por el aire (todavía no ha tocado a nadie)
#   - Rojo sangre = el golpe alcanzó a un enemigo
# ---------------------------------------------------------------------------

@export var base: Node3D                      # punto de la empuñadura (se busca solo si se llama "BaseEspada")
@export var punta: Node3D                     # punto de la punta (se busca solo si se llama "PuntaEspada")
@export var duracion_estela := 0.18           # segundos que tarda en desaparecer la cola
@export var color_aire := Color(1, 1, 1, 1)
@export var color_sangre := Color(0.85, 0.03, 0.06, 1)
@export var opacidad := 0.9

var activa := false                           # true = se está dibujando la estela (lo controla personaje.gd)
var _color := Color(1, 1, 1, 1)
var _puntos: Array = []                       # historial de posiciones: cada una guarda el momento, la base y la punta
var _malla := ImmediateMesh.new()


# Se ejecuta una vez al crearse: prepara el material y busca los puntos de la espada.
func _ready() -> void:
	top_level = true                          # dibuja en coordenadas del mundo, sin heredar el movimiento del personaje
	global_transform = Transform3D.IDENTITY
	mesh = _malla
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED          # no le afectan las luces
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA             # permite desvanecerse
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED                     # se ve por ambos lados
	mat.vertex_color_use_as_albedo = true                            # usa el color que le damos a cada punto
	material_override = mat
	_color = color_aire
	if base == null:
		base = get_parent().find_child("BaseEspada", true, false)
	if punta == null:
		punta = get_parent().find_child("PuntaEspada", true, false)
	_buscar_espada()   # si no hay puntos asignados, los crea solos sobre la espada del Rig


# Busca la espada que RigSegmentado cuelga de la mano ("Mano") y crea sobre ella dos puntos:
# BaseEspada (empuñadura) y PuntaEspada (punta). Mide la espada y toma su lado más largo.
func _buscar_espada() -> void:
	if base != null and punta != null:
		return
	var rig = get_parent().get_node_or_null("Rig")
	if rig == null:
		rig = get_parent().find_child("Rig", true, false)
	if rig == null or rig.get("_mano") == null:
		return
	var mano: Node3D = rig.get("_mano")
	if mano.get_parent() == null:
		return                                   # el rig todavía no le puso la espada
	var caja := AABB()
	var primera := true
	for m in mano.find_children("*", "MeshInstance3D", true, false):
		var t: Transform3D = mano.global_transform.affine_inverse() * (m as Node3D).global_transform
		var a: AABB = t * (m as MeshInstance3D).get_aabb()
		caja = a if primera else caja.merge(a)
		primera = false
	if primera:
		return
	# Eje más largo de la espada = su hoja.
	var eje := 0
	if caja.size.y > caja.size[eje]:
		eje = 1
	if caja.size.z > caja.size[eje]:
		eje = 2
	var centro := caja.get_center()
	var lo := centro
	var hi := centro
	lo[eje] = caja.position[eje]
	hi[eje] = caja.end[eje]
	# La punta es el extremo más lejos de la mano (la mano está en el origen de "Mano").
	var p_punta := hi if absf(hi[eje]) > absf(lo[eje]) else lo
	var p_base := lo if absf(hi[eje]) > absf(lo[eje]) else hi
	var mb := Marker3D.new()
	mb.name = "BaseEspada"
	mano.add_child(mb)
	mb.position = p_base
	var mp := Marker3D.new()
	mp.name = "PuntaEspada"
	mano.add_child(mp)
	mp.position = p_punta
	base = mb
	punta = mp


# Se ejecuta en cada cuadro: guarda la posición de la espada y redibuja la cinta.
func _process(_delta: float) -> void:
	if base == null or punta == null:
		_buscar_espada()                      # reintenta hasta que el rig haya creado la espada
	var ahora := Time.get_ticks_msec() / 1000.0
	if activa and base != null and punta != null:
		_puntos.append({"t": ahora, "b": base.global_position, "p": punta.global_position})
	# Borramos los puntos que ya son demasiado viejos (así la cola se va acortando).
	while _puntos.size() > 0 and ahora - float(_puntos[0]["t"]) > duracion_estela:
		_puntos.pop_front()
	_malla.clear_surfaces()
	if _puntos.size() < 2:
		return
	# Cinta: por cada momento guardado ponemos un vértice en la punta y otro en la base.
	_malla.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for pt in _puntos:
		var edad: float = (ahora - float(pt["t"])) / duracion_estela      # 0 = recién dibujado, 1 = a punto de desaparecer
		var c := _color
		c.a = (1.0 - edad) * opacidad
		_malla.surface_set_color(c)
		_malla.surface_add_vertex(pt["p"])                                 # punta: más visible
		var c2 := c
		c2.a = c.a * 0.3
		_malla.surface_set_color(c2)
		_malla.surface_add_vertex(pt["b"])                                 # base: más transparente
	_malla.surface_end()


# Empieza un golpe nuevo: la estela vuelve a ser blanca y se borra la anterior.
func reiniciar() -> void:
	_color = color_aire
	_puntos.clear()


# El golpe alcanzó a un enemigo: la estela pasa a rojo sangre.
func marcar_golpe() -> void:
	_color = color_sangre
