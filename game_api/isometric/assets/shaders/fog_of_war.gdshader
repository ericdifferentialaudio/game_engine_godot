// Fog-of-war overlay for a full-screen or per-tile ColorRect/Polygon2D.
// unexplored -> opaque dark; explored -> desaturated dim; visible -> clear.
// Drive `level` per instance (0 = unexplored, 1 = explored, 2 = visible).
shader_type canvas_item;

uniform float level : hint_range(0.0, 2.0) = 0.0;
uniform vec4 unexplored_color : source_color = vec4(0.02, 0.02, 0.05, 0.95);
uniform vec4 explored_color : source_color = vec4(0.0, 0.0, 0.0, 0.45);

void fragment() {
	vec4 base = COLOR;
	if (level < 0.5) {
		COLOR = unexplored_color * base.a;
	} else if (level < 1.5) {
		COLOR = explored_color * base.a;
	} else {
		COLOR = vec4(0.0);
	}
}
