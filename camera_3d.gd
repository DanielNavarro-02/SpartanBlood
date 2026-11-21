extends Camera3D
class_name CamaraSeguidora   # permite que otros scripts "vean" esta cámara por su nombre

@export var objetivo: Node3D
@export var distancia = Vector3(0, 5, 12)
@export var suavizado = 5.0
@export var limite_min = Vector2(-21, -10)
@export var limite_max = Vector2(21, 10)

@export_group("Presentación de zonas")
@export var margen_zona = 1.1       # 1.1 = deja 10% de aire alrededor de la zona
@export var tiempo_viaje = 1.2      # segundos que tarda en alejarse a ver la zona
@export var tiempo_regreso = 1.0    # segundos que tarda en volver al personaje
@export var fov_zona = 75.0

var presentando = false             # true mientras se muestra una zona
var etiqueta: Label                 # el texto con el nombre de la zona


func _ready():
	top_level = true
	# La cámara debe seguir funcionando aunque el juego esté pausado
	process_mode = Node.PROCESS_MODE_ALWAYS
	var punto_mira = objetivo.global_position + Vector3(0, 3, 0)
	look_at_from_position(objetivo.global_position + distancia, punto_mira)
	crear_interfaz()


# Crea por código el texto del nombre (así no tienes que armar nada en la escena).
func crear_interfaz():
	var capa = CanvasLayer.new()
	add_child(capa)
	etiqueta = Label.new()
	etiqueta.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	etiqueta.offset_top = 50
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	etiqueta.add_theme_font_size_override("font_size", 64)
	etiqueta.add_theme_color_override("font_outline_color", Color.BLACK)
	etiqueta.add_theme_constant_override("outline_size", 14)
	etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	etiqueta.modulate.a = 0.0       # empieza invisible
	capa.add_child(etiqueta)


func _physics_process(delta):
	# Mientras se muestra una zona, el movimiento lo controla el tween, no este código
	if presentando:
		return
	var destino = objetivo.global_position + distancia
	global_position = global_position.lerp(destino, suavizado * delta)


# Calcula qué tan lejos debe estar la cámara (solo para cámara en perspectiva).
func distancia_para_ver(tamano: Vector3, angulo: float) -> float:
	var pantalla = get_viewport().get_visible_rect().size
	var aspecto = pantalla.x / pantalla.y
	var t = tan(deg_to_rad(angulo) / 2.0)
	var para_alto: float
	var para_ancho: float
	if keep_aspect == Camera3D.KEEP_HEIGHT:
		# el ángulo (fov) mide la altura
		para_alto = (tamano.y * 0.5) / t
		para_ancho = (tamano.x * 0.5) / (t * aspecto)
	else:
		# el ángulo (fov) mide el ancho
		para_ancho = (tamano.x * 0.5) / t
		para_alto = (tamano.y * 0.5) * aspecto / t
	return maxf(para_alto, para_ancho) * margen_zona + tamano.z * 0.5


# Muestra una zona completa con su nombre y luego vuelve al personaje.
# Si la cámara es ortogonal ajusta "size"; si es normal (perspectiva) ajusta "fov".
func mostrar_zona(centro: Vector3, tamano: Vector3, nombre: String, segundos: float = 3.0):
	if presentando:
		return
	presentando = true
	get_tree().paused = true
	etiqueta.text = nombre

	var ortogonal = projection == Camera3D.PROJECTION_ORTHOGONAL
	var pantalla = get_viewport().get_visible_rect().size
	var aspecto = pantalla.x / pantalla.y

	var propiedad: String        # cuál valor vamos a cambiar: "size" o "fov"
	var valor_original: float    # para devolverlo al final
	var valor_zona: float        # el valor que muestra toda la zona
	var destino_zona: Vector3

	if ortogonal:
		propiedad = "size"
		valor_original = size
		# size es la altura visible en metros: debe caber el alto y también el ancho
				# Según Keep Aspect, "size" mide la altura o el ancho de lo que se ve
		if keep_aspect == Camera3D.KEEP_HEIGHT:
			valor_zona = maxf(tamano.y, tamano.x / aspecto) * margen_zona
		else:
			valor_zona = maxf(tamano.x, tamano.y * aspecto) * margen_zona
		# En ortogonal la distancia no agranda nada, solo evita que se corte la imagen
		destino_zona = centro + global_basis.z * (tamano.z * 0.5 + distancia.z)
	else:
		propiedad = "fov"
		valor_original = fov
		valor_zona = fov_zona
		destino_zona = centro + global_basis.z * distancia_para_ver(tamano, fov_zona)

	var destino_vuelta = objetivo.global_position + distancia

	var t = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# 1) Se aleja y abre la vista (aparece el nombre a la mitad)
	t.tween_property(self, "global_position", destino_zona, tiempo_viaje)
	t.parallel().tween_property(self, propiedad, valor_zona, tiempo_viaje)
	t.parallel().tween_property(etiqueta, "modulate:a", 1.0, 0.6).set_delay(tiempo_viaje * 0.5)
	# 2) Se queda mirando
	t.tween_interval(segundos)
	# 3) Se va el nombre, vuelve al personaje y se restaura el zoom original
	t.tween_property(etiqueta, "modulate:a", 0.0, 0.5)
	t.tween_property(self, "global_position", destino_vuelta, tiempo_regreso)
	t.parallel().tween_property(self, propiedad, valor_original, tiempo_regreso)
	t.tween_callback(terminar_presentacion)


# Se llama al final: reanuda el juego y la cámara vuelve a seguir al jugador.
func terminar_presentacion():
	presentando = false
	get_tree().paused = false
	
