extends CanvasLayer
## Interfaz extra: avisos, barra del jefe, pantalla de derrota, inventario, tienda y mapa.
## Se construye por código; escucha las señales del autoload Juego.

var _toast: Label
var _cola: Array = []
var _toast_activo: bool = false
var _jefe_panel: Control
var _jefe_nombre: Label
var _jefe_fantasma: ColorRect
var _jefe_barra: ColorRect
var _ratio: float = 1.0
var _ratio_fantasma: float = 1.0
var _muerte: ColorRect
var _muerte_label: Label
var _inv: Label
var _tienda: Control
var _mapa: Control
const ANCHO_BARRA := 700.0


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_crear_toast()
	_crear_barra_jefe()
	_crear_muerte()
	_crear_inventario()
	_tienda = preload("res://ui_tienda.gd").new()
	add_child(_tienda)
	_mapa = preload("res://ui_mapa.gd").new()
	add_child(_mapa)
	Juego.aviso.connect(_on_aviso)
	Juego.jefe_actualizado.connect(_on_jefe)
	Juego.jefe_oculto.connect(func(): _jefe_panel.visible = false)
	Juego.jugador_murio.connect(_on_muerte)
	Juego.botas_obtenidas.connect(_refrescar_inv)
	Juego.mapa_obtenido.connect(_refrescar_inv)
	Juego.abrir_tienda.connect(func(npc): _tienda.abrir(npc))
	Juego.ui_abierta = false
	_refrescar_inv()


func _label(tam: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	l.add_theme_constant_override("outline_size", 6)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _crear_toast() -> void:
	_toast = _label(30)
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.offset_left = -450
	_toast.offset_right = 450
	_toast.offset_top = 90
	_toast.offset_bottom = 190
	_toast.modulate.a = 0.0
	add_child(_toast)


func _crear_barra_jefe() -> void:
	_jefe_panel = Control.new()
	_jefe_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_jefe_panel.offset_left = -ANCHO_BARRA / 2.0
	_jefe_panel.offset_right = ANCHO_BARRA / 2.0
	_jefe_panel.offset_top = -92
	_jefe_panel.offset_bottom = -30
	_jefe_panel.visible = false
	_jefe_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_jefe_panel)
	_jefe_nombre = _label(24)
	_jefe_nombre.position = Vector2(0, 0)
	_jefe_nombre.size = Vector2(ANCHO_BARRA, 30)
	_jefe_panel.add_child(_jefe_nombre)
	var fondo := ColorRect.new()
	fondo.color = Color(0, 0, 0, 0.75)
	fondo.position = Vector2(-4, 30)
	fondo.size = Vector2(ANCHO_BARRA + 8, 24)
	_jefe_panel.add_child(fondo)
	_jefe_fantasma = ColorRect.new()
	_jefe_fantasma.color = Color(0.95, 0.85, 0.65)
	_jefe_fantasma.position = Vector2(0, 34)
	_jefe_fantasma.size = Vector2(ANCHO_BARRA, 16)
	_jefe_panel.add_child(_jefe_fantasma)
	_jefe_barra = ColorRect.new()
	_jefe_barra.color = Color(0.78, 0.1, 0.08)
	_jefe_barra.position = Vector2(0, 34)
	_jefe_barra.size = Vector2(ANCHO_BARRA, 16)
	_jefe_panel.add_child(_jefe_barra)


func _crear_muerte() -> void:
	_muerte = ColorRect.new()
	_muerte.color = Color(0, 0, 0, 0)
	_muerte.set_anchors_preset(Control.PRESET_FULL_RECT)
	_muerte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_muerte)
	_muerte_label = _label(72)
	_muerte_label.text = "HAS CAÍDO"
	_muerte_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_muerte_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_muerte_label.add_theme_color_override("font_color", Color(0.85, 0.15, 0.1))
	_muerte_label.modulate.a = 0.0
	add_child(_muerte_label)


func _crear_inventario() -> void:
	_inv = _label(20)
	_inv.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_inv.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_inv.offset_left = -420
	_inv.offset_right = -16
	_inv.offset_top = 14
	_inv.offset_bottom = 80
	add_child(_inv)


func _refrescar_inv() -> void:
	var t := ""
	if Juego.tiene_dash:
		t += "Botas de Hermes · Dash (clic der.)\n"
	if Juego.tiene_mapa:
		t += "Mapa · [M]"
	_inv.text = t


func _on_aviso(texto: String, color: Color) -> void:
	_cola.append([texto, color])
	if not _toast_activo:
		_procesar_cola()


func _procesar_cola() -> void:
	_toast_activo = true
	while _cola.size() > 0:
		var m: Array = _cola.pop_front()
		_toast.text = String(m[0])
		_toast.add_theme_color_override("font_color", m[1])
		_toast.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(_toast, "modulate:a", 1.0, 0.25)
		tw.tween_interval(2.8)
		tw.tween_property(_toast, "modulate:a", 0.0, 0.5)
		await tw.finished
	_toast_activo = false


func _on_jefe(nombre: String, vida: float, maxima: float) -> void:
	_jefe_panel.visible = true
	_jefe_nombre.text = nombre
	_ratio = clampf(vida / maxima, 0.0, 1.0)


func _on_muerte() -> void:
	await get_tree().create_timer(1.2, true, false, true).timeout
	var tw := create_tween()
	tw.tween_property(_muerte, "color:a", 0.85, 0.8)
	tw.parallel().tween_property(_muerte_label, "modulate:a", 1.0, 0.8)
	await tw.finished
	await get_tree().create_timer(1.8, true, false, true).timeout
	Engine.time_scale = 1.0
	get_tree().paused = false
	Juego.ui_abierta = false
	get_tree().reload_current_scene()


func _process(delta: float) -> void:
	if _jefe_panel.visible:
		_ratio_fantasma = move_toward(_ratio_fantasma, _ratio, 0.35 * delta)
		if _ratio_fantasma < _ratio:
			_ratio_fantasma = _ratio
		_jefe_barra.size.x = ANCHO_BARRA * _ratio
		_jefe_fantasma.size.x = ANCHO_BARRA * _ratio_fantasma
