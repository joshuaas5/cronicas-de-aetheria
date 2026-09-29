// Alpha-cut leaf cards. INSTANCE_CUSTOM.xyz carries the crown centre so the
// cards get soft, volumetric normals instead of flat quad lighting.
shader_type spatial;
render_mode cull_disabled, diffuse_burley, world_vertex_coords;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap;
uniform vec3 tint : source_color = vec3(1.0);
uniform float alpha_cut = 0.45;
uniform float wind_strength = 0.06;
uniform float translucency = 0.55;
uniform vec3 glow : source_color = vec3(0.0);
uniform float normal_bend = 0.75;

varying vec3 crown;

void vertex() {
	crown = INSTANCE_CUSTOM.xyz;
	vec3 wp = VERTEX;
	float t = TIME * 1.3;
	float sway = sin(t + wp.x * 0.45 + wp.y * 0.3) * 0.6 + sin(t * 2.1 + wp.z * 0.8) * 0.3;
	float flutter = sin(TIME * 6.0 + wp.x * 3.0 + wp.z * 2.0) * 0.15;
	VERTEX += vec3(sway, flutter * 0.4, sway * 0.5) * wind_strength * (0.5 + UV.y);
	vec3 outward = normalize(wp - crown + vec3(0.0, 0.35, 0.0));
	NORMAL = normalize(mix(NORMAL, outward, normal_bend));
}

void fragment() {
	vec4 tex = texture(albedo_tex, UV);
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	vec3 c = tex.rgb * tint * COLOR.rgb;
	ALBEDO = c;
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	NORMAL_MAP_DEPTH = 0.6;
	ROUGHNESS = 0.62;
	SPECULAR = 0.35;
	BACKLIGHT = c * translucency;
	EMISSION = glow * tex.a;
}
