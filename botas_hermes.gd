class_name BotasHermes
extends Area3D
## Botas aladas de Hermes: al recogerlas se desbloquea el DASH.
## Se construyen por código (no hay modelo): cuero, bordes dorados y alas luminosas.

var velocidad_inicial: Vector3 = Vector3.ZERO
var _vel: Vector3 = Vector3.ZERO
var _aterrizado: bool = false
var _visual: Node3D
var _t: float = 0.0
var _recogida: bool = false


func _ready() -> void:
	collision_mask = 1
	monitoring = true
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 1.7
	cs.shape = sh
	cs.position = Vector3(0, 1.0, 0)
	add_child(cs)
	body_entered.connect(_on_body_entered)
	_vel = velocidad_inicial
	_construir()


func _mat(color: Color, emision: Color, energia: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	if energia > 0.0:
		m.emission_enabled = true
		m.emission = emision
		m.emission_energy_multiplier = energia
	return m


func _caja(padre: Node3D, tam: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = tam
	bm.material = mat
	mi.mesh = bm
	mi.position = pos
	padre.add_child(mi)
	return mi


func _construir() -> void:
	_visual = Node3D.new()
	_visual.scale = Vector3.ONE * 1.5
	add_child(_visual)
	var cuero := _mat(Color(0.5, 0.3, 0.1), Color.BLACK, 0.0)
	var oro := _mat(Color(0.95, 0.75, 0.25), Color(1.0, 0.7, 0.2), 0.7)
	var ala := _mat(Color(1.0, 1.0, 0.95), Color(1.0, 0.95, 0.75), 1.6)
	for lado in [-1.0, 1.0]:
		var bota := Node3D.new()
		bota.position = Vector3(lado * 0.4, 0, 0)
		_visual.add_child(bota)
		_caja(bota, Vector3(0.45, 0.24, 0.95), Vector3(0, 0.12, -0.15), cuero)          # pie
		_caja(bota, Vector3(0.42, 0.7, 0.42), Vector3(0, 0.58, 0.12), cuero)            # caña
		_caja(bota, Vector3(0.5, 0.1, 0.5), Vector3(0, 0.95, 0.12), oro)                # borde
		_caja(bota, Vector3(0.47, 0.1, 0.35), Vector3(0, 0.27, -0.55), oro)             # puntera
		for i in range(3):                                                              # ala
			var a := _caja(bota, Vector3(0.04, 0.12, 0.62 - i * 0.12),
				Vector3(lado * 0.3, 0.55 + i * 0.13, 0.35 - i * 0.05), ala)
			a.rotation_degrees = Vector3(-(18 + i * 14), 0, lado * -12)

	var luz := OmniLight3D.new()
	luz.light_color = Color(1.0, 0.8, 0.3)
	luz.light_energy = 2.5
	luz.omni_range = 9.0
	luz.position = Vector3(0, 1.4, 0.8)
	add_child(luz)

	# Columna de luz para que se vea desde lejos
	var haz := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = 0.35
	cil.bottom_radius = 0.35
	cil.height = 16.0
	var mh := StandardMaterial3D.new()
	mh.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mh.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mh.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mh.albedo_color = Color(1.0, 0.8, 0.3, 0.16)
	cil.material = mh
	haz.mesh = cil
	haz.position = Vector3(0, 8.0, 0)
	add_child(haz)

	var p := CPUParticles3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.05
	sm.height = 0.1
	var mp := StandardMaterial3D.new()
	mp.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mp.albedo_color = Color(1.0, 0.9, 0.5)
	sm.material = mp
	p.mesh = sm
	p.amount = 14
	p.lifetime = 1.6
	p.direction = Vector3.UP
	p.spread = 25.0
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 1.4
	p.gravity = Vector3.ZERO
	p.position = Vector3(0, 0.5, 0)
	add_child(p)


func _physics_process(delta: float) -> void:
	if _aterrizado or _recogida:
		return
	_vel.y -= 20.0 * delta
	global_position += _vel * delta
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 0.4, 0), global_position + Vector3(0, -0.4, 0))
	var r: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	if not r.is_empty() and _vel.y < 0.0:
		global_position.y = r["position"].y
		_aterrizado = true
		Juego.polvo(global_position)
		Juego.sacudir(0.1, 0.2)


func _process(delta: float) -> void:
	_t += delta
	if _visual != null:
		_visual.position.y = 0.9 + sin(_t * 2.2) * 0.18
		_visual.rotation.y += delta * 1.4


func _on_body_entered(body: Node3D) -> void:
	if _recogida or not body.is_in_group("jugador"):
		return
	_recogida = true
	Juego.obtener_botas()
	Juego.chispas(global_position + Vector3(0, 1.2, 0), Color(1.0, 0.85, 0.35), 40, 8.0)
	Juego.sacudir(0.2, 0.4)
	var r = body.get_node_or_null("Rig")
	if r != null:
		r.destello(Color(1.0, 0.85, 0.3), 0.5, 0.7)
	queue_free()
