extends Camera3D

@export var objetivo: Node3D
@export var distancia = Vector3(0, 2, 12)

func _ready():
	top_level = true
	# Se orienta UNA sola vez, mirando al objetivo.
	look_at_from_position(objetivo.global_position + distancia,
			objetivo.global_position)

func _physics_process(delta):
	global_position = objetivo.global_position + distancia
	# Medida (bórrenla al terminar):
	if Engine.get_physics_frames() % 30 == 0:
		print("cámara ", global_position.snappedf(0.01))
