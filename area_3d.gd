extends Area3D

@export var luz_exterior: DirectionalLight3D 
@export var world_environment: WorldEnvironment 

#@group("Ajustes de Transición")
@export var tiempo_transicion: float = 1.5
@export var energia_exterior_atenuada: float = 0.1 # Nivel de luz que quedará en el interior

#@group("Efecto Antorcha (Aura)")
@export var velocidad_parpadeo: float = 15.0 # Qué tan rápido cambia la llama
@export var energia_base_antorcha: float = 1.2 # Brillo promedio de la antorcha
@export var fluctuacion_antorcha: float = 0.25 # Qué tanto varía el brillo (arriba/abajo)

var luz_pj_referencia: Light3D = null
var efecto_antorcha_activo: bool = false
var tiempo_acumulado: float = 0.0

func _process(delta: float) -> void:
	# Si el jugador está dentro, hacemos que la luz fluctúe como una antorcha
	if efecto_antorcha_activo and luz_pj_referencia:
		tiempo_acumulado += delta * velocidad_parpadeo
		# Usamos una combinación de senos para que el parpadeo no sea un patrón repetitivo simple
		var ruido = sin(tiempo_acumulado) * cos(tiempo_acumulado * 0.7) + sin(tiempo_acumulado * 1.5)
		luz_pj_referencia.light_energy = energia_base_antorcha + (ruido * fluctuacion_antorcha)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("jugador"):
		# 1. Guardar referencia de la luz y activar efecto antorcha
		var luz_pj = body.get_node_or_null("Aura")
		if luz_pj is Light3D:
			luz_pj_referencia = luz_pj
			luz_pj_referencia.visible = true
			efecto_antorcha_activo = true
		
		# 2. Atenuar la luz del exterior suavemente (sin apagarla)
		if luz_exterior:
			var tween_luz = create_tween()
			tween_luz.tween_property(luz_exterior, "light_energy", energia_exterior_atenuada, tiempo_transicion)
		
		# 3. Atenuar el WorldEnvironment en sintonía con la luz exterior
		if world_environment and world_environment.environment:
			var tween_env = create_tween()
			tween_env.tween_property(world_environment.environment, "bg_energy_multiplier", energia_exterior_atenuada, tiempo_transicion)
