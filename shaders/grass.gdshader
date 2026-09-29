// Grass clumps drawn through a MultiMesh. UV.y is 0 at the root and 1 at the tip.
shader_type spatial;
render_mode cull_disabled, diffuse_burley, world_vertex_coords;

uniform vec3 root_color : source_color = vec3(0.10, 0.16, 0.05);
uniform vec3 tip_color : source_color = vec3(0.45, 0.62, 0.20);
uniform vec3 dry_color : source_color = vec3(0.55, 0.52, 0.28);
uniform float wind_strength = 0.22;
uniform float wind_speed = 1.4;
uniform vec3 player_pos = vec3(0.0, -100.0, 0.0);
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 tip_glow : source_color = vec3(0.0);

varying float hgt;
varying float patch;

void vertex() {
	hgt = UV.y;
	vec3 wp = VERTEX;
	float big = texture(noise_tex, wp.xz * 0.03 + TIME * 0.02 * wind_speed).r;
	float gust = sin(TIME * wind_speed + wp.x * 0.35 + wp.z * 0.22) * 0.6 + sin(TIME * wind_speed * 2.3 + wp.x * 1.3) * 0.2;
	float bend = hgt * hgt * wind_strength * (0.4 + big * 1.2);
	VERTEX.x += gust * bend;
	VERTEX.z += gust * bend * 0.45;
	vec2 d = VERTEX.xz - player_pos.xz;
	float dl = length(d);
	float push = smoothstep(1.1, 0.0, dl) * hgt * hgt;
	VERTEX.xz += normalize(d + vec2(0.0001)) * push * 0.55;
	VERTEX.y -= push * 0.25;
	NORMAL = normalize(vec3(0.0, 1.0, 0.0) + (VERTEX - wp) * 0.4);
	patch = texture(noise_tex, wp.xz * 0.06).r;
}

void fragment() {
	vec3 tip = mix(tip_color, dry_color, smoothstep(0.55, 0.85, patch) * 0.8);
	vec3 c = mix(root_color, tip, smoothstep(0.0, 1.0, hgt)) * COLOR.rgb;
	ALBEDO = c;
	ROUGHNESS = 0.75;
	SPECULAR = 0.3;
	BACKLIGHT = c * 0.6 * hgt;
	AO = mix(0.35, 1.0, hgt);
	AO_LIGHT_AFFECT = 0.6;
	EMISSION = tip_glow * smoothstep(0.75, 1.0, hgt);
}
