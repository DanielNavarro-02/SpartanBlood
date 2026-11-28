extends Node3D
class_name DirectorOleadas

signal oleada_iniciada(numero)
signal oleadas_completadas

@export var enemigo_escena: PackedScene     # arrastra aquí gladiador.tscn
@export var camara: CamaraSeguidora
@export var reja: Reja
@export var salud_jugador: Node             # el nodo "Salud" de Kael
@export var puntos_aparicion: Node3D        # nodo que contiene los Marker3D

@export_group("Oleadas")
@export var enemigos_por_oleada: Array[int] = [3, 4, 6]
@export var espera_inicial = 1.0            # segundos entre la presentación y la oleada 1
@export var segundos_entre_oleadas = 3.0
@export var pausa_entre_apariciones = 0.15  # segundos entre un enemigo y el siguiente

@export_group("Enemigos reforzados")
@export var vida_extra = 1.0                # se suma a la vida normal (3 → 4)
@export var recarga_enemigo = 0.8           # normal 1.2: menos espera = ataca más seguido
@export var aviso_enemigo = 0.4             # normal 0.5: avisa menos antes de golpear
@export var pueden_huir = false             # false = pelean hasta morir (no huyen herido)

@export_group("Destello de aparición")
@export var retardo_destello = 0.4          # segundos entre el destello y la aparición
@export var duracion_destello = 0.6
@export var usar_luz_destello = true        # apágalo si el juego se pone lento

@export_group("Muerte del jugador")
@export var reiniciar_al_morir = true       # bórralo si ya tienes otro reinicio
@export var segundos_antes_de_reiniciar = 3

var oleada_actual = 0
var vivos: Array = []             # enemigos de la oleada que siguen en pie
var combate_activo = false        # true cuando ya aparecieron todos y se está peleando
var etiqueta: Label
var tween_aviso: Tween


# Al empezar: crea el texto, conecta la muerte del jugador y decide cuándo arrancar.
func _ready():
	crear_interfaz()
	if reiniciar_al_morir and salud_jugador != null:
		salud_jugador.jugador_muerto.connect(_on_jugador_muerto)

	if ZonaCamara.intro_inicial_vista:
		# La escena se reinició: no hay presentación, se empieza directo
		await get_tree().create_timer(espera_inicial).timeout
		iniciar_oleada()
	else:
		# Primera vez: se espera a que la cámara termine de mostrar la Arena
		camara.presentacion_terminada.connect(_on_presentacion_terminada, CONNECT_ONE_SHOT)


# La cámara terminó de mostrar la Arena: arranca la primera oleada.
func _on_presentacion_terminada():
	await get_tree().create_timer(espera_inicial).timeout
	iniciar_oleada()


# Crea el texto grande ("Oleada 1 / 3") por código.
func crear_interfaz():
	var capa = CanvasLayer.new()
	add_child(capa)
	etiqueta = Label.new()
	etiqueta.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	etiqueta.offset_top = 140
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	etiqueta.add_theme_font_size_override("font_size", 52)
	etiqueta.add_theme_color_override("font_outline_color", Color.BLACK)
	etiqueta.add_theme_constant_override("outline_size", 12)
	etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	etiqueta.modulate.a = 0.0
	capa.add_child(etiqueta)


# Muestra un texto: aparece, se queda unos segundos y se desvanece.
func anunciar(texto: String, segundos: float):
	etiqueta.text = texto
	if tween_aviso != null:
		tween_aviso.kill()
	tween_aviso = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween_aviso.tween_property(etiqueta, "modulate:a", 1.0, 0.3)
	tween_aviso.tween_interval(segundos)
	tween_aviso.tween_property(etiqueta, "modulate:a", 0.0, 0.5)


# Empieza la siguiente oleada: anuncia, reparte los enemigos por los puntos y espera.
func iniciar_oleada():
	oleada_actual += 1
	var total = enemigos_por_oleada.size()
	var cantidad = enemigos_por_oleada[oleada_actual - 1]
	anunciar("Oleada %d / %d" % [oleada_actual, total], 2.0)
	oleada_iniciada.emit(oleada_actual)

	var puntos = puntos_aparicion.get_children()
	if puntos.is_empty():
		push_error("DirectorOleadas: no hay Marker3D dentro de los puntos de aparición")
		return
	puntos.shuffle()   # en cada oleada los enemigos salen por puntos distintos

	for i in cantidad:
		var punto: Node3D = puntos[i % puntos.size()]
		aparecer_enemigo(punto.global_position)
		await get_tree().create_timer(pausa_entre_apariciones).timeout

	# Se espera a que aparezca el último antes de empezar a contar muertes
	await get_tree().create_timer(retardo_destello + 0.1).timeout
	combate_activo = true


# Hace el destello y, un momento después, crea al gladiador en ese punto.
func aparecer_enemigo(posicion: Vector3):
	destello(posicion)
	await get_tree().create_timer(retardo_destello).timeout

	var e = enemigo_escena.instantiate()
	e.vida += vida_extra
	e.tiempo_recarga = recarga_enemigo
	e.tiempo_aviso = aviso_enemigo
	if not pueden_huir:
		e.vida_huida = 0.0
	add_child(e)
	e.global_position = posicion
	e.add_to_group("enemigos")   # para que el ataque de Kael lo encuentre
	vivos.append(e)


# Destello de luz dorada: una esfera que crece y se desvanece, con una luz opcional.
func destello(posicion: Vector3):
	var centro = posicion + Vector3(0, 1.0, 0)

	var esfera = MeshInstance3D.new()
	var malla = SphereMesh.new()
	malla.radius = 0.5
	malla.height = 1.0
	esfera.mesh = malla
	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 0.85, 0.5, 0.9)
	esfera.material_override = material
	add_child(esfera)
	esfera.global_position = centro
	esfera.scale = Vector3.ONE * 0.2

	var luz: OmniLight3D = null
	if usar_luz_destello:
		luz = OmniLight3D.new()
		luz.light_color = Color(1.0, 0.8, 0.5)
		luz.omni_range = 6.0
		luz.light_energy = 6.0
		luz.shadow_enabled = false
		add_child(luz)
		luz.global_position = centro

	var t = create_tween().set_parallel(true)
	t.tween_property(esfera, "scale", Vector3.ONE * 2.2, duracion_destello) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(material, "albedo_color:a", 0.0, duracion_destello)
	if luz != null:
		t.tween_property(luz, "light_energy", 0.0, duracion_destello)
	t.chain().tween_callback(func():
		esfera.queue_free()
		if luz != null:
			luz.queue_free())


# En cada cuadro de física revisa si ya murieron todos los enemigos de la oleada.
func _physics_process(_delta):
	if not combate_activo:
		return
	# Se quitan de la lista los que ya fueron eliminados
	vivos = vivos.filter(func(e): return is_instance_valid(e) and not e.is_queued_for_deletion())
	if vivos.is_empty():
		combate_activo = false
		oleada_terminada()


# Se llama cuando no queda ningún enemigo: abre la reja o prepara la siguiente oleada.
func oleada_terminada():
	if oleada_actual >= enemigos_por_oleada.size():
		anunciar("¡La reja se abre!", 3.0)
		oleadas_completadas.emit()
		# Centro de la reja (su origen está en el suelo, por eso se sube la mitad del alto)
		var centro_reja = reja.global_position + Vector3(0, reja.alto / 2.0, 0)
		# La cámara va a la reja, la abre al llegar y espera a que termine de abrirse + 1 s
		camara.mostrar_punto(centro_reja, reja.abrir, reja.duracion_apertura() + 1.0)
		return
	anunciar("Oleada superada", 2.0)
	await get_tree().create_timer(segundos_entre_oleadas).timeout
	iniciar_oleada()


# Kael murió: se espera un momento y se reinicia la escena completa.
func _on_jugador_muerto():
	await get_tree().create_timer(segundos_antes_de_reiniciar).timeout
	get_tree().reload_current_scene()
