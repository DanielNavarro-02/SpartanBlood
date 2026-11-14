shader_type spatial;

uniform vec3 color_bajo : source_color = vec3(0.05, 0.25, 0.5);
uniform float amplitud = 0.3;
uniform float longitud = 4.0;
uniform float periodo = 2.0;

float onda(float x, float t, float a, float l, float p) {
	return a * sin(TAU / l * x - TAU / p * t);
}

float pendiente(float x, float t, float a, float l, float p) {
	return a * (TAU / l) * cos(TAU / l * x - TAU / p * t);
}

void vertex() {
	float h = onda(VERTEX.x, TIME, amplitud, longitud, periodo);
	VERTEX.y += h;
}

void fragment() {
	ALBEDO = color_bajo;
	ROUGHNESS = 0.4;
}
