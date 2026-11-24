extends Node3D
## Herrero del campamento. Se acerca el jugador -> saluda; con [E] abre la tienda (vende el mapa).

@export var nombre_npc: String = "Brontes"
@export var precio_mapa: int = 10
@export var distancia_interaccion: float = 3.4

var _jugador: Node3D
var _prompt: Label3D
var _cerca: bool = false
var _saludo_t: float = 0.0
@onready var rig: RigSegmentado = $Rig


func _ready() -> void:
	add_to_group("npc")
	rig.process_mode = Node.PROCESS_MODE_ALWAYS     # sigue animado mientras la tienda pausa el juego
	rig.reproducir("idle")
	_prompt = Label3D.new()
	_prompt.text = "[E] Hablar"
	_prompt.font_size = 48
	_prompt.pixel_size = 0.008
	_prompt.outline_size = 10
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.no_depth_test = true
	_prompt.modulate = Color(1.0, 0.9, 0.55)
	_prompt.position = Vector3(0, 3.4, 0)
	_prompt.visible = false
	add_child(_prompt)


func _process(delta: float) -> void:
	if _jugador == null or not is_instance_valid(_jugador):
		_jugador = get_tree().get_first_node_in_group("jugador")
		return
	var dx: float = _jugador.global_position.x - global_position.x
	var dy: float = _jugador.global_position.y - global_position.y
	var cerca: bool = absf(dx) < distancia_interaccion and absf(dy) < 3.0
	if cerca != _cerca:
		_cerca = cerca
		if cerca:
			rig.reproducir("saludo", -1.0, 0.2)
			_saludo_t = 1.8
		else:
			rig.reproducir("idle", -1.0, 0.3)
	if cerca:
		rotation.y = -PI / 2.0 * signf(dx)
		if _saludo_t > 0.0:
			_saludo_t -= delta
			if _saludo_t <= 0.0:
				rig.reproducir("hablar", -1.0, 0.25)
	_prompt.visible = cerca and not Juego.ui_abierta
	if cerca and not Juego.ui_abierta and Input.is_action_just_pressed("interactuar"):
		Juego.abrir_tienda.emit(self)
