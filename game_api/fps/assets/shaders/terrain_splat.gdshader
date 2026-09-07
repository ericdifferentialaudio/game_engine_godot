// 4-layer heightmap terrain splat shader (Forward+). Starter for exterior maps.
// Layers: grass (R), dirt (G), rock (B), snow/sand (A) from a splat mask.
// Uses triplanar sampling on steep slopes so cliffs don't stretch.
shader_type spatial;
render_mode cull_back, depth_draw_opaque, specular_schlick_ggx;

uniform sampler2D splat_mask : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D albedo_0 : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D albedo_1 : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D albedo_2 : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D albedo_3 : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_0 : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_1 : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_2 : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_3 : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D orm_0 : hint_default_white, filter_linear_mipmap_anisotropic;
uniform sampler2D orm_1 : hint_default_white, filter_linear_mipmap_anisotropic;
uniform sampler2D orm_2 : hint_default_white, filter_linear_mipmap_anisotropic;
uniform sampler2D orm_3 : hint_default_white, filter_linear_mipmap_anisotropic;

uniform float uv_scale : hint_range(0.01, 4.0) = 0.25;
uniform float slope_rock_start : hint_range(0.0, 1.0) = 0.55;
uniform float slope_rock_end : hint_range(0.0, 1.0) = 0.8;
uniform float far_fade_start = 200.0;
uniform float far_fade_end = 800.0;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec4 triplanar(sampler2D tex, vec3 p, vec3 n, float scale) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z);
	vec4 x = texture(tex, p.zy * scale);
	vec4 y = texture(tex, p.xz * scale);
	vec4 z = texture(tex, p.xy * scale);
	return x * w.x + y * w.y + z * w.z;
}

void fragment() {
	vec4 mask = texture(splat_mask, UV);
	float slope = 1.0 - clamp(world_normal.y, 0.0, 1.0);
	float rock_w = smoothstep(slope_rock_start, slope_rock_end, slope);
	// Steep slopes force rock regardless of painted mask.
	mask.b = max(mask.b, rock_w);
	float total = mask.r + mask.g + mask.b + mask.a + 1e-4;
	mask /= total;

	vec2 uv = world_pos.xz * uv_scale;
	vec3 a0 = texture(albedo_0, uv).rgb;
	vec3 a1 = texture(albedo_1, uv).rgb;
	vec3 a2 = triplanar(albedo_2, world_pos, world_normal, uv_scale).rgb;
	vec3 a3 = texture(albedo_3, uv).rgb;
	vec3 n0 = texture(normal_0, uv).rgb;
	vec3 n1 = texture(normal_1, uv).rgb;
	vec3 n2 = triplanar(normal_2, world_pos, world_normal, uv_scale).rgb;
	vec3 n3 = texture(normal_3, uv).rgb;
	vec3 o0 = texture(orm_0, uv).rgb;
	vec3 o1 = texture(orm_1, uv).rgb;
	vec3 o2 = triplanar(orm_2, world_pos, world_normal, uv_scale).rgb;
	vec3 o3 = texture(orm_3, uv).rgb;

	vec3 albedo = a0 * mask.r + a1 * mask.g + a2 * mask.b + a3 * mask.a;
	vec3 nrm = n0 * mask.r + n1 * mask.g + n2 * mask.b + n3 * mask.a;
	vec3 orm = o0 * mask.r + o1 * mask.g + o2 * mask.b + o3 * mask.a;

	// Fade detail normals in the distance to reduce shimmer.
	float dist = length(CAMERA_POSITION_WORLD - world_pos);
	float detail = 1.0 - smoothstep(far_fade_start, far_fade_end, dist);

	ALBEDO = albedo;
	NORMAL_MAP = mix(vec3(0.5, 0.5, 1.0), nrm, detail);
	NORMAL_MAP_DEPTH = 1.0;
	AO = orm.r;
	AO_LIGHT_AFFECT = 0.5;
	ROUGHNESS = orm.g;
	METALLIC = orm.b;
}
