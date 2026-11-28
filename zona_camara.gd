extends Area3D
class_name ZonaCamara

# Variable "static": pertenece al script y no a un nodo, por eso NO se borra
# cuando la escena se reinicia. Sirve para recordar que la presentación ya se vio.
static var intro_inicial_vista: bool = false

@export var camara: CamaraSeguidora
@export var nombre_zona = "Nueva zona"
@export var segundos_mostrando = 3.0
@export var es_zona_inicial = false
@export var una_sola_vez = true

var visitada = false
@onready var forma: CollisionShape3D = $CollisionShape3D


func _ready():
	add_to_group("zonas")
	body_entered.connect(_on_body_entered)
	if es_zona_inicial:
		visitada = true
		# Si la escena se reinició (el jugador murió), no se repite la presentación
		if intro_inicial_vista:
			return
		await get_tree().create_timer(0.3).timeout
		intro_inicial_vista = true
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
