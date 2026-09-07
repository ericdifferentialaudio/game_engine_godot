## Runtime graphics quality tiers for the Forward+ renderer.
##
## Applies viewport-level settings (scaling, AA) and Environment-level settings
## (GI, SSR, SSAO, volumetrics) on the current WorldEnvironment. Called from a
## settings menu or on startup from user://settings.cfg.
class_name RenderSettings
extends RefCounted

enum Tier { LOW, MEDIUM, HIGH, ULTRA }

const TIERS := {
	Tier.LOW: {
		"scaling": Viewport.SCALING_3D_MODE_FSR2, "scale": 0.59, "taa": false, "msaa": Viewport.MSAA_DISABLED,
		"sdfgi": false, "ssr": false, "ssao": false, "ssil": false, "volumetric_fog": false, "glow": true,
		"shadow_size": 2048, "shadow_quality": 1,
	},
	Tier.MEDIUM: {
		"scaling": Viewport.SCALING_3D_MODE_FSR2, "scale": 0.77, "taa": false, "msaa": Viewport.MSAA_DISABLED,
		"sdfgi": true, "ssr": false, "ssao": true, "ssil": false, "volumetric_fog": true, "glow": true,
		"shadow_size": 4096, "shadow_quality": 2,
	},
	Tier.HIGH: {
		"scaling": Viewport.SCALING_3D_MODE_BILINEAR, "scale": 1.0, "taa": true, "msaa": Viewport.MSAA_DISABLED,
		"sdfgi": true, "ssr": true, "ssao": true, "ssil": false, "volumetric_fog": true, "glow": true,
		"shadow_size": 8192, "shadow_quality": 3,
	},
	Tier.ULTRA: {
		"scaling": Viewport.SCALING_3D_MODE_BILINEAR, "scale": 1.0, "taa": true, "msaa": Viewport.MSAA_2X,
		"sdfgi": true, "ssr": true, "ssao": true, "ssil": true, "volumetric_fog": true, "glow": true,
		"shadow_size": 16384, "shadow_quality": 5,
	},
}


static func apply(tier: Tier, viewport: Viewport, env: Environment) -> void:
	var t: Dictionary = TIERS[tier]
	viewport.scaling_3d_mode = t["scaling"]
	viewport.scaling_3d_scale = t["scale"]
	viewport.use_taa = t["taa"]
	viewport.msaa_3d = t["msaa"]
	RenderingServer.directional_shadow_atlas_set_size(t["shadow_size"], true)
	ProjectSettings.set_setting("rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality", t["shadow_quality"])
	if env:
		env.sdfgi_enabled = t["sdfgi"]
		env.ssr_enabled = t["ssr"]
		env.ssao_enabled = t["ssao"]
		env.ssil_enabled = t["ssil"]
		env.volumetric_fog_enabled = t["volumetric_fog"]
		env.glow_enabled = t["glow"]


static func tier_from_string(s: String) -> Tier:
	match s.to_lower():
		"low": return Tier.LOW
		"medium": return Tier.MEDIUM
		"ultra": return Tier.ULTRA
		_: return Tier.HIGH
