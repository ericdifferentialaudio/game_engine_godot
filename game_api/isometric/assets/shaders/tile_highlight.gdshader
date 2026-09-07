// Pulsing highlight for selected / reachable tiles (apply to Polygon2D).
shader_type canvas_item;

uniform vec4 tint : source_color = vec4(0.3, 0.7, 1.0, 0.35);
uniform float pulse_speed = 2.0;
uniform float pulse_amount : hint_range(0.0, 1.0) = 0.25;

void fragment() {
	float p = 1.0 - pulse_amount + pulse_amount * (0.5 + 0.5 * sin(TIME * pulse_speed));
	COLOR = vec4(tint.rgb, tint.a * p) * COLOR.a;
}
