shader_type canvas_item;

uniform float intensidad : hint_range(0.0, 0.6) = 0.25;
uniform float velocidad : hint_range(0.1, 3.0) = 1.0;

void fragment() {
	vec4 color = COLOR;

	float azul = smoothstep(
		0.08, 0.25, color.b - color.r
	);

	float violeta = smoothstep(
		0.08, 0.25, min(color.r, color.b) - color.g
	);

	float oro = smoothstep(
		0.12, 0.35, min(color.r, color.g) - color.b
	);

	float luminosidad = max(color.r, max(color.g, color.b));
	float zonas_claras = smoothstep(0.35, 0.75, luminosidad);

	float fase = UV.x * 24.0 + UV.y * 17.0;
	float pulso = 0.5 + 0.5 * sin(TIME * velocidad * 1.6 + fase);

	float destello = pow(
		0.5 + 0.5 * sin(TIME * velocidad * 2.2 + fase * 3.0),
		18.0
	);

	float cristales = max(azul, violeta) * zonas_claras;
	float monedas = oro * zonas_claras;

	vec3 brillo_cristales = color.rgb * cristales * pulso;
	vec3 brillo_monedas = vec3(1.0, 0.85, 0.4) * monedas * destello;

	color.rgb += (brillo_cristales + brillo_monedas) * intensidad;
	COLOR = color;
}