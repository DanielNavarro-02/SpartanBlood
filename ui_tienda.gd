extends Control
## Diálogo + tienda del herrero. Pausa el juego mientras está abierta.

var _npc: Node
var _salud: Node
var _titulo: Label
var _dialogo: Label
var _obolos: Label
var _btn_comprar: Button
var _btn_salir: Button
var _tw: Tween


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centro)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(640, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.07, 0.05, 0.97)
	sb.border_color = Color(0.82, 0.62, 0.22)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", sb)
	centro.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)

	_titulo = Label.new()
	_titulo.add_theme_font_size_override("font_size", 30)
	_titulo.add_theme_color_override("font_color", Color(0.95, 0.75, 0.3))
	v.add_child(_titulo)

	_dialogo = Label.new()
	_dialogo.add_theme_font_size_override("font_size", 20)
	_dialogo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialogo.custom_minimum_size = Vector2(590, 120)
	v.add_child(_dialogo)

	_obolos = Label.new()
	_obolos.add_theme_font_size_override("font_size", 18)
	_obolos.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
	v.add_child(_obolos)

	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 14)
	v.add_child(fila)
	_btn_comprar = Button.new()
	_btn_comprar.custom_minimum_size = Vector2(320, 46)
	_btn_comprar.pressed.connect(_comprar)
	fila.add_child(_btn_comprar)
	_btn_salir = Button.new()
	_btn_salir.text = "Despedirse"
	_btn_salir.custom_minimum_size = Vector2(160, 46)
	_btn_salir.pressed.connect(_cerrar)
	fila.add_child(_btn_salir)


func abrir(npc: Node) -> void:
	_npc = npc
	var j = get_tree().get_first_node_in_group("jugador")
	_salud = j.get_node("Salud")
	_titulo.text = String(npc.nombre_npc) + " · Herrero"
	if Juego.tiene_mapa:
		_decir("El mapa ya es tuyo, guerrero. Pulsa M para desplegarlo. Que Hefesto guíe tu espada.")
	elif Juego.tiene_dash:
		_decir("¡Por los dioses, esas botas aladas! Rhaxos cayó… Pues bien, si vas a correr por estas ruinas, llévate también mi mapa: %d óbolos." % int(npc.precio_mapa))
	else:
		_decir("Bienvenido al campamento. Forjo y remiendo lo que la arena destroza. Conservo un mapa de estas ruinas, dibujado por quienes cayeron antes que tú. %d óbolos y es tuyo." % int(npc.precio_mapa))
	_refrescar()
	visible = true
	Juego.ui_abierta = true
	get_tree().paused = true
	_btn_comprar.grab_focus()


func _refrescar() -> void:
	_obolos.text = "Tus óbolos: %d" % int(_salud.obolos)
	if Juego.tiene_mapa:
		_btn_comprar.text = "Mapa comprado"
		_btn_comprar.disabled = true
	else:
		_btn_comprar.text = "Comprar Mapa de las Ruinas (%d óbolos)" % int(_npc.precio_mapa)
		_btn_comprar.disabled = false


func _decir(texto: String) -> void:
	_dialogo.text = texto
	_dialogo.visible_ratio = 0.0
	if _tw != null:
		_tw.kill()
	_tw = create_tween()
	_tw.tween_property(_dialogo, "visible_ratio", 1.0, maxf(texto.length() / 55.0, 0.4))


func _comprar() -> void:
	if Juego.tiene_mapa:
		return
	if _salud.gastar_obolos(int(_npc.precio_mapa)):
		Juego.obtener_mapa()
		_decir("Buena compra. Pulsa M para desplegarlo: verás tu posición, el campamento y la guarida de Rhaxos. Que Hefesto guíe tu espada.")
	else:
		_decir("Te faltan óbolos. Derrota a los esqueletos de la arena y vuelve cuando tengas %d." % int(_npc.precio_mapa))
	_refrescar()


func _cerrar() -> void:
	visible = false
	get_tree().paused = false
	await get_tree().process_frame
	Juego.ui_abierta = false


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_cerrar()
