extends Node3D

@onready var anim = get_node_or_null("Modelo/AnimationPlayer")
@onready var prompt_label: Label3D = get_node_or_null("PromptLabel")

@export var precio_mapa: int = 10
@export var texto_comprar: String = "[E / Espacio] Comprar mapa (%d óbolos)"
@export var texto_sin_obolos: String = "Necesitas %d óbolos para el mapa"
@export var texto_comprado: String = "Mapa entregado"

var _jugador_cerca: Node3D = null


func _ready() -> void:
	if anim != null:
		for n in ["Idle", "idle"]:
			if anim.has_animation(n):
				anim.play(n)
				break
	_actualizar_texto()


func _process(_delta: float) -> void:
	if _jugador_cerca == null:
		return
	if Input.is_action_just_pressed("ui_accept") or Input.is_key_pressed(KEY_E):
		if Input.is_key_pressed(KEY_E) and not Input.is_action_just_pressed("ui_accept"):
			if _jugador_cerca.has_meta("_comprando_e") and _jugador_cerca.get_meta("_comprando_e"):
				return
			_jugador_cerca.set_meta("_comprando_e", true)
			_intentar_compra()
			await get_tree().create_timer(0.25).timeout
			if is_instance_valid(_jugador_cerca):
				_jugador_cerca.set_meta("_comprando_e", false)
		else:
			_intentar_compra()


func _intentar_compra() -> void:
	if _jugador_cerca == null:
		return
	if _jugador_cerca.get("tiene_mapa") == true:
		_actualizar_texto()
		return

	var salud := _jugador_cerca.get_node_or_null("Salud")
	if salud != null and salud.has_method("gastar_obolos"):
		if salud.gastar_obolos(precio_mapa):
			if _jugador_cerca.has_method("obtener_mapa"):
				_jugador_cerca.obtener_mapa()
			_actualizar_texto()
		else:
			if prompt_label != null:
				prompt_label.text = texto_sin_obolos % precio_mapa


func _actualizar_texto() -> void:
	if prompt_label == null:
		return
	if _jugador_cerca != null and _jugador_cerca.get("tiene_mapa") == true:
		prompt_label.text = texto_comprado
	else:
		prompt_label.text = texto_comprar % precio_mapa


func _on_zona_interaccion_body_entered(body: Node3D) -> void:
	if body.is_in_group("jugador"):
		_jugador_cerca = body
		_actualizar_texto()
		if prompt_label != null:
			prompt_label.visible = true


func _on_zona_interaccion_body_exited(body: Node3D) -> void:
	if body == _jugador_cerca:
		_jugador_cerca = null
		if prompt_label != null:
			prompt_label.visible = false
