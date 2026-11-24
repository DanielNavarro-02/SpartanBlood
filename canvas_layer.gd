
extends CanvasLayer

@export var personaje: NodePath

@export_group("Imagenes de vida")
@export var vida_llena: Texture2D
@export var vida_vacia: Texture2D
@export var tamano_vida: Vector2 = Vector2(30, 30)

@export_group("Imagenes de sangre")
@export var sangre_llena: Texture2D
@export var sangre_media: Texture2D
@export var sangre_vacia: Texture2D
@export var tamano_sangre: Vector2 = Vector2(60, 60)

@export_group("Obolos")
@export var imagen_obolo: Texture2D
@export var tamano_obolo: Vector2 = Vector2(30, 30)
@export var tamano_texto: int = 22

@onready var salud = get_node(personaje)
@onready var contenedor_vida = $Margen/Interfaz/Vida
@onready var imagen_sangre = $Margen/Interfaz/Sangre
@onready var icono_obolo = $Margen/Interfaz/Obolos/Icono
@onready var texto_obolos = $Margen/Interfaz/Obolos/Cantidad


func _ready():
	icono_obolo.texture = imagen_obolo
	
	icono_obolo.custom_minimum_size = tamano_obolo
	icono_obolo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icono_obolo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	imagen_sangre.custom_minimum_size = tamano_sangre
	imagen_sangre.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	imagen_sangre.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	texto_obolos.add_theme_color_override("font_color", Color.WHITE)
	texto_obolos.add_theme_font_size_override("font_size", tamano_texto)
	
	actualizar_vida(salud.vida, salud.vida_maxima)
	actualizar_sangre(salud.sangre, salud.sangre_maxima)
	actualizar_obolos(salud.obolos)
	
	salud.vida_cambiada.connect(actualizar_vida)
	salud.sangre_cambiada.connect(actualizar_sangre)
	salud.obolos_cambiados.connect(actualizar_obolos)

func actualizar_sangre(actual, maxima):
	if actual <= 0:
		imagen_sangre.texture = sangre_vacia
	elif actual == 1:
		imagen_sangre.texture = sangre_media
	else:
		imagen_sangre.texture = sangre_llena

func actualizar_vida(actual, maxima):
	for hijo in contenedor_vida.get_children():
		hijo.queue_free()
	
	for i in range(maxima):
		var icono = TextureRect.new()
		
		icono.texture = vida_llena if i < actual else vida_vacia
		icono.custom_minimum_size = tamano_vida
		icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		
		contenedor_vida.add_child(icono)

func actualizar_obolos(actual):
	texto_obolos.text = str(actual)
