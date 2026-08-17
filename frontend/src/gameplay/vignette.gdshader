shader_type canvas_item;
render_mode unshaded, blend_mix;

void fragment() {
	vec2 uv = UV;
	float d = distance(uv, vec2(0.5, 0.46));
	float a = smoothstep(0.32, 0.86, d);
	COLOR = vec4(0.03, 0.02, 0.07, a * 0.78);
}
