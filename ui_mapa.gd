extends Control
## Mapa de las ruinas (se desbloquea comprándolo al herrero). Tecla M.
## Se dibuja leyendo el GridMap real del nivel: las cavernas (huecos) en pergamino y la roca en oscuro.

var _tex: ImageTexture
var _min: Vector2i = Vector2i.ZERO
var _max: Vector2i = Vector2i.ZERO
var _abierto: bool = false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("mapa") and Juego.tiene_mapa:
		get_viewport().set_input_as_handled()
		if _abierto:
			_cerrar()
		elif not Juego.ui_abierta and not _presentando():
			_abrir()
	elif _abierto and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_cerrar()


func _presentando() -> bool:
	var cam := get_viewport().get_camera_3d()
	return cam is CamaraSeguidora and cam.presentando


func _construir_textura() -> void:
	var grid := get_tree().current_scene.find_child("GridMap", true, false) as GridMap
	if grid == null:
		return
	var celdas: Array = grid.get_used_cells()
	if celdas.is_empty():
		return
	_min = Vector2i(1000000, 1000000)
	_max = Vector2i(-1000000, -1000000)
	for c in celdas:
		_min.x = mini(_min.x, c.x)
		_min.y = mini(_min.y, c.y)
		_max.x = maxi(_max.x, c.x)
		_max.y = maxi(_max.y, c.y)
	var img := Image.create(_max.x - _min.x + 1, _max.y - _min.y + 1, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.83, 0.74, 0.55))
	var roca := Color(0.14, 0.1, 0.08)
	for c in celdas:
		if c.z == 0:                                   # capa por donde camina el jugador
			img.set_pixel(c.x - _min.x, _max.y - c.y, roca)
	_tex = ImageTexture.create_from_image(img)


func _abrir() -> void:
	if _tex == null:
		_construir_textura()
	if _tex == null:
		Juego.avisar("No se pudo leer el mapa del nivel", Color(1, 0.4, 0.4))
		return
	_abierto = true
	visible = true
	Juego.ui_abierta = true
	get_tree().paused = true


func _cerrar() -> void:
	_abierto = false
	visible = false
	get_tree().paused = false
	await get_tree().process_frame
	Juego.ui_abierta = false


func _process(_delta: float) -> void:
	if _abierto:
		queue_redraw()


func _area() -> Rect2:
	var margen := 60.0
	var ancho := size.x - margen * 2.0
	var alto := size.y - margen * 2.0
	var iw: float = float(_tex.get_width())
	var ih: float = float(_tex.get_height())
	var esc: float = minf(ancho / iw, alto / ih)
	var sz := Vector2(iw * esc, ih * esc)
	return Rect2((size - sz) / 2.0, sz)


func _a_pantalla(x: float, y: float, area: Rect2, esc: float) -> Vector2:
	return Vector2(area.position.x + (x - float(_min.x)) * esc,
		area.position.y + (float(_max.y + 1) - y) * esc)


func _draw() -> void:
	if not _abierto or _tex == null:
		return
	var fuente: Font = ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.82))
	var area := _area()
	var esc: float = area.size.x / float(_tex.get_width())
	draw_texture_rect(_tex, area, false)
	draw_rect(area, Color(0.9, 0.72, 0.35), false, 3.0)
	draw_string(fuente, Vector2(area.position.x, area.position.y - 18), "MAPA DE LAS RUINAS   ·   [M] cerrar",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.95, 0.8, 0.45))

	# Zonas (las mismas que usa la cámara)
	for z in get_tree().get_nodes_in_group("zonas"):
		var forma := z.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if forma == null or not (forma.shape is BoxShape3D):
			continue
		var tam: Vector3 = (forma.shape as BoxShape3D).size * forma.global_basis.get_scale().abs()
		var c: Vector3 = forma.global_position
		var origen := _a_pantalla(c.x - tam.x / 2.0, c.y + tam.y / 2.0, area, esc)
		var r := Rect2(origen, Vector2(tam.x * esc, tam.y * esc))
		draw_rect(r, Color(1.0, 0.9, 0.5, 0.9), false, 1.5)
		var nombre: String = String(z.get("nombre_zona")) if z.get("nombre_zona") != null else ""
		if nombre != "":
			draw_string(fuente, r.position + Vector2(6, 18), nombre, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1.0, 0.95, 0.7))

	# Herrero / campamento
	for n in get_tree().get_nodes_in_group("npc"):
		var p := _a_pantalla(n.global_position.x, n.global_position.y + 1.0, area, esc)
		draw_rect(Rect2(p - Vector2(6, 6), Vector2(12, 12)), Color(0.95, 0.75, 0.2))
		draw_string(fuente, p + Vector2(10, 5), "Herrero", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 0.9, 0.5))

	# Guarida de Rhaxos
	if not Juego.jefe_derrotado:
		for j in get_tree().get_nodes_in_group("jefe"):
			var p2 := _a_pantalla(j.global_position.x, j.global_position.y + 3.0, area, esc)
			draw_colored_polygon(PackedVector2Array([p2 + Vector2(0, -9), p2 + Vector2(9, 0), p2 + Vector2(0, 9), p2 + Vector2(-9, 0)]), Color(0.85, 0.12, 0.08))
			draw_string(fuente, p2 + Vector2(12, 5), "Rhaxos", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 0.6, 0.5))

	# Jugador (parpadea)
	var jug := get_tree().get_first_node_in_group("jugador")
	if jug != null:
		var pj := _a_pantalla(jug.global_position.x, jug.global_position.y + 1.0, area, esc)
		var pulso: float = 0.6 + 0.4 * sin(Time.get_ticks_msec() / 160.0)
		draw_circle(pj, 8.0 * pulso + 3.0, Color(0.2, 0.9, 1.0, 0.9))
		draw_circle(pj, 3.0, Color.WHITE)
		draw_string(fuente, pj + Vector2(12, 5), "Tú", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.7, 1.0, 1.0))
