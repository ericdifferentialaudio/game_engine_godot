// Faction-coloured outline for unit sprites (selected / hovered units).
shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(1.0, 0.85, 0.2, 1.0);
uniform float thickness : hint_range(0.0, 4.0) = 1.0;

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE * thickness;
	vec4 col = texture(TEXTURE, UV);
	float a = col.a;
	a = max(a, texture(TEXTURE, UV + vec2(px.x, 0.0)).a);
	a = max(a, texture(TEXTURE, UV - vec2(px.x, 0.0)).a);
	a = max(a, texture(TEXTURE, UV + vec2(0.0, px.y)).a);
	a = max(a, texture(TEXTURE, UV - vec2(0.0, px.y)).a);
	vec4 outline = vec4(outline_color.rgb, outline_color.a * a);
	COLOR = mix(outline, col, col.a) * MODULATE;
}
