extends Area3D

@export var luz_exterior: DirectionalLight3D 
@export var world_environment: WorldEnvironment 

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("jugador"):
		# 1. Encender la luz del personaje (Aura)
		var luz_pj = body.get_node_or_null("Aura")
		if luz_pj:
			luz_pj.visible = true
		
		# 2. Apagar la luz del exterior
		if luz_exterior:
			luz_exterior.visible = false
