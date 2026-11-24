class_name RigSegmentado
extends Node3D
## Anima modelos hechos de piezas rígidas (sin esqueleto) leyendo un JSON.
##
## 1. Instancia el FBX, lo orienta (frente hacia -Z), lo escala a "altura" y apoya los pies en y=0.
## 2. Crea pivotes (cadera, torso, brazos...) y cuelga las mallas de ellos.
## 3. Reproduce clips: keyframes con suavizado + osciladores senoidales.
##
## Claves de pose (grados): "torso", "cabeza", "brazo_a"... = rotación Euler (x,y,z).
##   "<clave>_p" = desplazamiento [adelante, arriba, lado] en % de la altura del modelo.
##   "<clave>_s" = escala (1 = normal).
## "_a" siempre es el lado cercano a la cámara y "_b" el lejano: así el arma queda
## visible aunque el personaje mire a la izquierda.

@export_file("*.json") var datos: String = ""
@export var altura_objetivo: float = 0.0   # 0 = usar la altura del JSON

var def: Dictionary = {}
var orient: Node3D
var pivotes: Dictionary = {}
var altura_modelo: float = 1.0
var clip_actual: String = ""
var terminado: bool = false      # un clip sin bucle llegó a su final
var progreso: float = 0.0        # 0..1 dentro del clip actual
var listo: bool = false

var _pos_base: Dictionary = {}
var _espejo: Dictionary = {}
var _lado: Dictionary = {}
var _mapa: Dictionary = {}       # "brazo_a" -> "brazo_R"
var _inv: Dictionary = {}        # "brazo_R" -> "brazo_a"
var _mano: Node3D
var _largo_brazo: float = 0.0
var _mallas: Array = []
var _vel: float = 1.0
var _pose_prev: Dictionary = {}
var _pose_actual: Dictionary = {}
var _mezcla: float = 1.0
var _mezcla_total: float = 0.1
var _mat_flash: StandardMaterial3D
var _tw_flash: Tween


func _ready() -> void:
	if datos == "":
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(datos))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("RigSegmentado: no se pudo leer " + datos)
		return
	def = parsed
	_preparar_clips()
	_construir()
	listo = true
	if def["clips"].has("idle"):
		reproducir("idle", -1.0, 0.0)


# ------------------------------------------------------------------ construcción
func _preparar_clips() -> void:
	for nombre in def["clips"].keys():
		var c: Dictionary = def["clips"][nombre]
		var nombres := {}
		for kf in c["keys"]:
			var p: Dictionary = kf["p"]
			for k in p.keys():
				var a: Array = p[k]
				p[k] = Vector3(a[0], a[1], a[2])
				nombres[k] = true
		c["_nombres"] = nombres.keys()


func _aabb_de(m: MeshInstance3D) -> AABB:
	var t: Transform3D = orient.global_transform.affine_inverse() * m.global_transform
	return t * m.get_aabb()


func _aabb_total(lista: Array) -> AABB:
	var caja := AABB()
	var primero := true
	for m in lista:
		var a: AABB = _aabb_de(m)
		if primero:
			caja = a
			primero = false
		else:
			caja = caja.merge(a)
	return caja


func _recoger(n: Node, salida: Dictionary) -> void:
	if n is MeshInstance3D:
		salida[String(n.name)] = n
	for h in n.get_children():
		_recoger(h, salida)


func _buscar(d: Dictionary, nombre: String) -> MeshInstance3D:
	if d.has(nombre):
		return d[nombre]
	for k in d.keys():
		if String(k).begins_with(nombre):
			return d[k]
	push_warning("RigSegmentado: no encuentro la malla '" + nombre + "'")
	return null


func _ancla(spec: Array, d: Dictionary) -> Vector3:
	var m: MeshInstance3D = _buscar(d, String(spec[0]))
	var a: AABB = _aabb_de(m)
	var modo: String = String(spec[1])
	var lo: Vector3 = a.position
	var hi: Vector3 = a.end
	var c: Vector3 = a.get_center()
	var x: float = c.x
	var y: float = c.y
	var z: float = c.z
	if modo.contains("t"):
		y = hi.y
	if modo.contains("b"):
		y = lo.y
	if modo.begins_with("i"):
		x = lo.x if absf(lo.x) < absf(hi.x) else hi.x
	if modo.begins_with("o"):
		x = hi.x if absf(lo.x) < absf(hi.x) else lo.x
	if not modo.contains("z"):
		z = 0.0
	var p := Vector3(x, y, z)
	if spec.size() > 2:
		var d3: Array = spec[2]
		p += Vector3(d3[0], d3[1], d3[2]) * altura_modelo / 100.0
	return p


func _construir() -> void:
	orient = Node3D.new()
	orient.name = "Orient"
	add_child(orient)
	var packed: PackedScene = load("res://modelos/" + String(def["modelo"]))
	var raiz: Node3D = packed.instantiate()
	orient.add_child(raiz)

	var por_nombre := {}
	_recoger(raiz, por_nombre)

	# 1) Orientación: el frente (ojos) debe quedar hacia -Z
	var ref: MeshInstance3D = _buscar(por_nombre, String(def["frente"]))
	var total: AABB = _aabb_total(por_nombre.values())
	if _aabb_de(ref).get_center().z > total.get_center().z:
		raiz.rotation.y = PI

	# 2) Escala y apoyo en el suelo
	total = _aabb_total(por_nombre.values())
	altura_modelo = total.size.y
	var y0: float = total.position.y
	if def.has("suelo") and def["suelo"] != null:
		y0 = _aabb_de(_buscar(por_nombre, String(def["suelo"]))).position.y
	var altura: float = altura_objetivo if altura_objetivo > 0.0 else float(def.get("altura", 2.0))
	var esc: float = altura / altura_modelo
	orient.scale = Vector3.ONE * esc
	orient.position.y = -y0 * esc

	if def.has("arma"):
		var aref: MeshInstance3D = _buscar(por_nombre, String(def["arma"]["brazo_ref"]))
		_largo_brazo = _aabb_de(aref).size.x

	# 3) Pivotes
	for p in def["pivotes"]:
		var id: String = String(p["id"])
		var pos: Vector3 = _ancla(p["ancla"], por_nombre)
		var piv := Node3D.new()
		piv.name = id
		orient.add_child(piv)
		piv.position = pos
		var rest: Node3D = null
		if p.get("colgar", false):
			rest = Node3D.new()
			rest.name = id + "_rest"
			piv.add_child(rest)
		for nombre in p.get("partes", []):
			var m: MeshInstance3D = _buscar(por_nombre, String(nombre))
			if m != null:
				m.reparent(rest if rest != null else piv, true)
		for nombre in p.get("fijas", []):
			var m2: MeshInstance3D = _buscar(por_nombre, String(nombre))
			if m2 != null:
				m2.reparent(piv, true)
		var padre: String = String(p.get("padre", ""))
		if padre != "":
			piv.reparent(pivotes[padre], true)
		pivotes[id] = piv
		_pos_base[id] = piv.position
		_lado[id] = 1.0 if pos.x >= 0.0 else -1.0
		if p.get("espejo", false):
			_espejo[id] = true
		if rest != null:
			# el brazo estaba en T: se deja colgando (se rota DESPUÉS de colgar las mallas)
			rest.rotation.z = deg_to_rad(-90.0 if pos.x > 0.0 else 90.0)

	# 4) Arma
	if def.has("arma"):
		var ad: Dictionary = def["arma"]
		var ps: PackedScene = load("res://modelos/" + String(ad["escena"]))
		_mano = Node3D.new()
		_mano.name = "Mano"
		_mano.add_child(ps.instantiate())
		var t: float = deg_to_rad(float(ad.get("inclinacion", 15.0)))
		_mano.basis = Basis(Vector3.RIGHT, t - PI / 2.0) * Basis(Vector3.UP, PI / 2.0)
		_mano.position = Vector3(0.0, -_largo_brazo * float(ad.get("largo", 0.88)), 0.0)

	_actualizar_lados()
	if _mano != null and _mano.get_parent() == null and pivotes.size() > 0:
		_colocar_arma()
	_mallas.clear()
	_registrar_mallas(orient)


func _registrar_mallas(n: Node) -> void:
	if n is MeshInstance3D:
		_mallas.append(n)
	for h in n.get_children():
		_registrar_mallas(h)


# ------------------------------------------------------------------ lados cercano / lejano
func _actualizar_lados() -> void:
	if not def.has("lados"):
		return
	var cambio := false
	var lados: Dictionary = def["lados"]
	for par in lados.keys():
		var ids: Array = lados[par]
		var l: Node3D = pivotes[ids[0]]
		var r: Node3D = pivotes[ids[1]]
		var dz: float = l.global_position.z - r.global_position.z
		var cerca: String = String(_mapa.get(par + "_a", ""))
		var nuevo: String = cerca
		if absf(dz) > 0.02 or cerca == "":
			nuevo = String(ids[0]) if dz > 0.0 else String(ids[1])
		if nuevo != cerca:
			var lejos: String = String(ids[1]) if nuevo == String(ids[0]) else String(ids[0])
			_mapa[par + "_a"] = nuevo
			_mapa[par + "_b"] = lejos
			_inv[nuevo] = par + "_a"
			_inv[lejos] = par + "_b"
			cambio = true
	if cambio and _mano != null:
		_colocar_arma()


func _colocar_arma() -> void:
	var id: String = String(_mapa.get(String(def["arma"]["mano"]), ""))
	if id == "" or not pivotes.has(id):
		return
	if _mano.get_parent() == null:
		pivotes[id].add_child(_mano)
		_mallas.clear()
		_registrar_mallas(orient)
	else:
		_mano.reparent(pivotes[id], false)


# ------------------------------------------------------------------ reproducción
func reproducir(nombre: String, duracion: float = -1.0, mezcla: float = 0.1, reiniciar: bool = true) -> void:
	if not listo or not def["clips"].has(nombre):
		return
	var c: Dictionary = def["clips"][nombre]
	if nombre == clip_actual and not reiniciar:
		if duracion > 0.0:
			_vel = float(c["dur"]) / duracion
		return
	_pose_prev = _pose_actual.duplicate()
	clip_actual = nombre
	progreso = 0.0
	terminado = false
	_mezcla = 0.0
	_mezcla_total = maxf(mezcla, 0.0001)
	_vel = 1.0 if duracion <= 0.0 else float(c["dur"]) / duracion


## Cambia la rapidez del clip en curso (p. ej. ciclo de carrera según la velocidad).
func velocidad(v: float) -> void:
	_vel = v


func tiene_clip(nombre: String) -> bool:
	return listo and def["clips"].has(nombre)


func _process(delta: float) -> void:
	if not listo:
		return
	_actualizar_lados()
	if clip_actual == "":
		return
	var c: Dictionary = def["clips"][clip_actual]
	progreso += delta * _vel / float(c["dur"])
	if c["loop"]:
		progreso = fposmod(progreso, 1.0)
	elif progreso >= 1.0:
		progreso = 1.0
		terminado = true
	var pose: Dictionary = _muestrear(c, progreso)
	if _mezcla < _mezcla_total:
		_mezcla += delta
		var w: float = clampf(_mezcla / _mezcla_total, 0.0, 1.0)
		pose = _mezclar(_pose_prev, pose, w * w * (3.0 - 2.0 * w))
	_pose_actual = pose
	_aplicar(pose)


func _def(k: String) -> Vector3:
	return Vector3.ONE if k.ends_with("_s") else Vector3.ZERO


func _ease(u: float, e: String) -> float:
	u = clampf(u, 0.0, 1.0)
	match e:
		"l":
			return u
		"i":
			return u * u * u
		"o":
			return 1.0 - pow(1.0 - u, 3.0)
	return u * u * (3.0 - 2.0 * u)


func _muestrear(c: Dictionary, tn: float) -> Dictionary:
	var pose := {}
	var keys: Array = c["keys"]
	if keys.size() > 0:
		var a: Dictionary = keys[0]
		var b: Dictionary = keys[0]
		var u: float = 0.0
		if tn >= float(keys[keys.size() - 1]["t"]):
			a = keys[keys.size() - 1]
			b = a
		elif tn > float(keys[0]["t"]):
			for i in range(keys.size() - 1):
				if tn <= float(keys[i + 1]["t"]):
					a = keys[i]
					b = keys[i + 1]
					var span: float = maxf(float(b["t"]) - float(a["t"]), 0.0001)
					u = _ease((tn - float(a["t"])) / span, String(a["e"]))
					break
		for k in c["_nombres"]:
			var va: Vector3 = a["p"].get(k, _def(k))
			var vb: Vector3 = b["p"].get(k, _def(k))
			pose[k] = va.lerp(vb, u)
	for o in c["osc"]:
		var k2: String = String(o[0])
		var ax: int = int(o[1])
		var v: Vector3 = pose.get(k2, _def(k2))
		v[ax] += float(o[5]) + float(o[2]) * sin(TAU * (float(o[3]) * tn + float(o[4])))
		pose[k2] = v
	return pose


func _mezclar(a: Dictionary, b: Dictionary, w: float) -> Dictionary:
	var salida := {}
	for k in a.keys():
		var vb: Vector3 = b.get(k, _def(String(k)))
		salida[k] = (a[k] as Vector3).lerp(vb, w)
	for k in b.keys():
		if not salida.has(k):
			var va: Vector3 = a.get(k, _def(String(k)))
			salida[k] = va.lerp(b[k], w)
	return salida


func _aplicar(pose: Dictionary) -> void:
	for id in pivotes.keys():
		var piv: Node3D = pivotes[id]
		var k: String = String(_inv.get(id, id))
		var r: Vector3 = pose.get(k, Vector3.ZERO)
		if _espejo.has(id):
			var s: float = _lado[id]
			r = Vector3(r.x, r.y * s, r.z * s)
		piv.rotation = Vector3(deg_to_rad(r.x), deg_to_rad(r.y), deg_to_rad(r.z))
		var off: Vector3 = pose.get(k + "_p", Vector3.ZERO)
		piv.position = _pos_base[id] + Vector3(off.z, off.y, -off.x) * altura_modelo * 0.01
		piv.scale = pose.get(k + "_s", Vector3.ONE)


# ------------------------------------------------------------------ efectos visuales
func _asegurar_flash() -> void:
	if _mat_flash == null:
		_mat_flash = StandardMaterial3D.new()
		_mat_flash.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat_flash.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat_flash.albedo_color = Color(1, 1, 1, 0)


## Destello que se apaga solo (impacto recibido).
func destello(color: Color = Color(1, 1, 1), dur: float = 0.12, intensidad: float = 0.8) -> void:
	if not listo:
		return
	_asegurar_flash()
	for m in _mallas:
		m.material_overlay = _mat_flash
	_mat_flash.albedo_color = Color(color.r, color.g, color.b, intensidad)
	if _tw_flash != null:
		_tw_flash.kill()
	_tw_flash = create_tween()
	_tw_flash.tween_property(_mat_flash, "albedo_color:a", 0.0, dur)
	_tw_flash.tween_callback(quitar_resaltado)


## Tinte fijo (aviso de ataque) hasta llamar a quitar_resaltado().
func resaltar(color: Color, intensidad: float = 0.3) -> void:
	if not listo:
		return
	_asegurar_flash()
	if _tw_flash != null:
		_tw_flash.kill()
	for m in _mallas:
		m.material_overlay = _mat_flash
	_mat_flash.albedo_color = Color(color.r, color.g, color.b, intensidad)


func quitar_resaltado() -> void:
	for m in _mallas:
		m.material_overlay = null


## Encoge el modelo hasta desaparecer (muerte).
func encoger(dur: float = 0.4) -> void:
	if orient == null:
		return
	var tw := create_tween()
	tw.tween_property(orient, "scale", orient.scale * 0.01, dur).set_ease(Tween.EASE_IN)
