// Four-layer terrain. Vertex COLOR holds the layer weights (r, g, b, a).
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D l0_alb : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D l0_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D l0_arm : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D l1_alb : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D l1_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D l1_arm : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D l2_alb : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D l2_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D l2_arm : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D l3_alb : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D l3_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D l3_arm : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec4 scales = vec4(0.25, 0.25, 0.25, 0.25); // tiles per meter
uniform vec3 tint0 : source_color = vec3(1.0);
uniform vec3 tint1 : source_color = vec3(1.0);
uniform vec3 tint2 : source_color = vec3(1.0);
uniform vec3 tint3 : source_color = vec3(1.0);
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float blend_sharpness = 6.0;
uniform vec3 glow_color : source_color = vec3(0.0);
uniform float glow_amount = 0.0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

vec2 rot(vec2 uv, float a) {
	float c = cos(a), s = sin(a);
	return mat2(vec2(c, -s), vec2(s, c)) * uv;
}

void fragment() {
	vec2 p = wpos.xz;
	float n = texture(noise_tex, p * 0.035).r;
	float n2 = texture(noise_tex, p * 0.21 + 7.3).r;
	vec2 u0 = rot(p, 0.3) * scales.x;
	vec2 u1 = rot(p, 1.1) * scales.y;
	vec2 u2 = rot(p, 2.0) * scales.z;
	vec2 u3 = rot(p, 2.7) * scales.w;
	vec3 a0 = texture(l0_alb, u0).rgb * tint0;
	vec3 a1 = texture(l1_alb, u1).rgb * tint1;
	vec3 a2 = texture(l2_alb, u2).rgb * tint2;
	vec3 a3 = texture(l3_alb, u3).rgb * tint3;
	// break up tiling with a large-scale brightness drift
	float drift = mix(0.82, 1.12, n);
	// height-aware blend using albedo luminance as a height proxy
	vec4 h = vec4(dot(a0, vec3(0.33)), dot(a1, vec3(0.33)), dot(a2, vec3(0.33)), dot(a3, vec3(0.33)));
	vec4 w = COLOR + (vec4(n2) - 0.5) * 0.35 + h * 0.35;
	w = max(w, 0.0);
	w = pow(w, vec4(blend_sharpness));
	w /= max(dot(w, vec4(1.0)), 0.0001);
	vec3 alb = a0 * w.x + a1 * w.y + a2 * w.z + a3 * w.w;
	vec3 nrm = texture(l0_nrm, u0).rgb * w.x + texture(l1_nrm, u1).rgb * w.y + texture(l2_nrm, u2).rgb * w.z + texture(l3_nrm, u3).rgb * w.w;
	vec3 arm = texture(l0_arm, u0).rgb * w.x + texture(l1_arm, u1).rgb * w.y + texture(l2_arm, u2).rgb * w.z + texture(l3_arm, u3).rgb * w.w;
	ALBEDO = alb * drift;
	NORMAL_MAP = nrm;
	NORMAL_MAP_DEPTH = 1.2;
	AO = arm.r;
	AO_LIGHT_AFFECT = 0.4;
	ROUGHNESS = clamp(arm.g, 0.35, 1.0);
	METALLIC = 0.0;
	if (glow_amount > 0.0) {
		float spots = smoothstep(0.78, 0.9, texture(noise_tex, p * 0.9).r) * w.x;
		EMISSION = glow_color * spots * glow_amount;
	}
}
