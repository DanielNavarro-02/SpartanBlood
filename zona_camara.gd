extends Area3D
class_name ZonaCamara

@export var camara: CamaraSeguidora          # arrastra aquí tu cámara
@export var nombre_zona = "Campamento Subterráneo"       # el texto que se muestra
@export var segundos_mostrando = 3.0
@export var es_zona_inicial = false          # márcalo SOLO en la Arena de Gladiadores
@export var una_sola_vez = true              # si es false, se repite cada vez que entres

var visitada = false
@onready var forma: CollisionShape3D = $CollisionShape3D


func _ready():
	add_to_group("zonas")
	body_entered.connect(_on_body_entered)
	if es_zona_inicial:
		# Se marca como visitada ya, para que no se repita cuando el jugador
		# (que nace dentro de la zona) active la señal de entrada.
		visitada = true
		# Pequeña espera para que la escena termine de cargar
		await get_tree().create_timer(0.3).timeout
		presentar()


# Se ejecuta solo cuando algo entra en la caja.
func _on_body_entered(body: Node3D):
	if not body.is_in_group("jugador"):
		return
	if una_sola_vez and visitada:
		return
	visitada = true
	presentar()


# Toma el tamaño de la caja y se lo pasa a la cámara.
func presentar():
	var caja = forma.shape as BoxShape3D
	var tamano = caja.size * forma.global_basis.get_scale().abs()
	camara.mostrar_zona(forma.global_position, tamano, nombre_zona, segundos_mostrando)
