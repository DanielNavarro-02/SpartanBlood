shader_type spatial;
render_mode cull_disabled;   // se ve por los dos lados

uniform vec4 color : source_color = vec4(0.65, 0.08, 0.08, 1.0); // color de la tela
uniform sampler2D textura : source_color, hint_default_white;    // dibujo opcional (emblema)
uniform float ancho = 2.0;       // ancho de la tela en metros (igual que el Size del mesh)
uniform float fuerza = 0.3;      // qué tanto se mueve
uniform float velocidad = 2.5;   // qué tan rápido va la onda
uniform float ondas = 1.5;       // cuántas "olas" caben en la tela
uniform float desfase = 0.0;     // cambia este número en cada bandera para que no estén sincronizadas

// vertex() se ejecuta una vez por cada punto de la tela y decide dónde queda.
void vertex() {
	// UV.x vale 0 en el asta y 1 en la punta: el borde pegado al asta no se mueve
	float anclaje = UV.x;
	// Ráfaga: el viento sube y baja de fuerza lentamente
	float rafaga = 1.0 + 0.3 * sin(TIME * 0.6 + desfase);
	// Fase: avanza con el tiempo para que la onda viaje hacia la punta
	float fase = UV.x * ondas * TAU - TIME * velocidad + desfase;

	// Mueve la tela hacia adelante/atrás (profundidad) y un poco arriba/abajo.
	// El movimiento arriba/abajo es el que se nota desde la cámara lateral.
	VERTEX.z += sin(fase) * fuerza * anclaje * rafaga;
	VERTEX.y += cos(fase) * fuerza * 0.35 * anclaje * rafaga;

	// Inclina la normal según la onda, para que la luz dé claros y oscuros
	// y la tela se vea ondulada y no plana.
	float pendiente = cos(fase) * ondas * TAU / ancho * fuerza * anclaje * rafaga;
	NORMAL = normalize(vec3(-pendiente, 0.0, 1.0));
}

// fragment() decide el color de cada píxel.
void fragment() {
	ALBEDO = texture(textura, UV).rgb * color.rgb;
	ROUGHNESS = 1.0;   // la tela no brilla
}