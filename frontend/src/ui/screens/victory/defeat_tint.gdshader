shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform float impact : hint_range(0.0, 1.0) = 0.0;
uniform vec3 grade_color = vec3(1.0, 0.39, 0.54);
uniform vec3 edge_color = vec3(0.44, 0.025, 0.17);
uniform vec3 impact_color = vec3(0.35, 0.12, 0.12);

void fragment() {
	vec3 scene = texture(screen_texture, SCREEN_UV).rgb;
	float lightness = dot(scene, vec3(0.299, 0.587, 0.114));
	vec3 tinted = grade_color * lightness;
	vec3 grade = mix(scene, tinted, amount * 0.72);
	float edge = pow(max(abs(UV.x - 0.5) * 2.0, abs(UV.y - 0.5) * 2.0), 9.0);
	grade *= 1.0 - amount * 0.32;
	grade = mix(grade, edge_color, edge * amount * 0.8);
	grade += impact_color * impact;
	COLOR = vec4(grade, 1.0);
}
