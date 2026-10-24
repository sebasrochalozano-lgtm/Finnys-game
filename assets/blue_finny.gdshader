shader_type canvas_item;
varying vec4 sprite_tint;

void vertex() {
	sprite_tint = COLOR;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	// Change green scales while keeping horns, eyes and belly.
	float green_mask = smoothstep(0.06, 0.20, tex.g - max(tex.r, tex.b));
	vec3 blue = vec3(0.15, 0.52, 1.0) * tex.g;
	COLOR = vec4(mix(tex.rgb, blue, green_mask), tex.a) * sprite_tint;
}
