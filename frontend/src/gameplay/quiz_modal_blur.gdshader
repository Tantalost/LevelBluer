shader_type canvas_item;
render_mode unshaded;

// Screen-space box blur. textureLod() on hint_screen_texture is a no-op on
// gl_compatibility (this project's renderer), so we tap SCREEN_PIXEL_SIZE instead.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float blur_amount : hint_range(0.0, 5.0) = 2.0;

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE * blur_amount;
	vec4 color = texture(screen_texture, SCREEN_UV) * 4.0;
	color += texture(screen_texture, SCREEN_UV + vec2(-px.x, 0.0));
	color += texture(screen_texture, SCREEN_UV + vec2(px.x, 0.0));
	color += texture(screen_texture, SCREEN_UV + vec2(0.0, -px.y));
	color += texture(screen_texture, SCREEN_UV + vec2(0.0, px.y));
	color += texture(screen_texture, SCREEN_UV + vec2(-px.x, -px.y));
	color += texture(screen_texture, SCREEN_UV + vec2(px.x, -px.y));
	color += texture(screen_texture, SCREEN_UV + vec2(-px.x, px.y));
	color += texture(screen_texture, SCREEN_UV + vec2(px.x, px.y));
	color /= 12.0;
	COLOR = color * vec4(0.5, 0.5, 0.5, 1.0);
}
