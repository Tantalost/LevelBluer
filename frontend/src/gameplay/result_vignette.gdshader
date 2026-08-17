shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform vec4 edge_color : source_color = vec4(0.37, 0.10, 0.10, 1.0);
uniform float center_alpha : hint_range(0.0, 1.0) = 0.22;
uniform float edge_alpha : hint_range(0.0, 1.0) = 0.94;

void fragment() {
	float d = distance(UV, vec2(0.5, 0.46));
	float a = mix(center_alpha, edge_alpha, smoothstep(0.10, 0.70, d));
	COLOR = vec4(edge_color.rgb, a);
}
