shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 shallow_color : source_color = vec3(0.055, 0.43, 0.48);
uniform vec3 deep_color : source_color = vec3(0.018, 0.12, 0.24);
uniform float wave_height = 1.0;
uniform float wave_speed = 1.0;
uniform float water_roughness = 0.18;

varying vec3 world_position;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float wave_a = sin((world.x + TIME * wave_speed * 7.0) * 0.055) * 0.18 * wave_height;
	float wave_b = sin((world.z - TIME * wave_speed * 5.0) * 0.073) * 0.13 * wave_height;
	VERTEX.y += wave_a + wave_b;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_position.xz;
	float wave_x = cos((p.x + TIME * wave_speed * 7.0) * 0.055) * 0.010 * wave_height;
	float wave_z = cos((p.y - TIME * wave_speed * 5.0) * 0.073) * 0.009 * wave_height;
	// Analytically filter waves once their phase is subpixel. Unfiltered
	// cosine normals produced the repeating distant water stripe pattern.
	wave_x *= exp2(-pow(fwidth(p.x)*0.055,2.0));
	wave_z *= exp2(-pow(fwidth(p.y)*0.073,2.0));
	NORMAL_MAP = vec3(0.5 + wave_x, 0.5 + wave_z, 1.0);
	NORMAL_MAP_DEPTH = 1.6;
	float fresnel = pow(1.0 - max(dot(NORMAL, VIEW), 0.0), 3.0);
	ALBEDO = mix(shallow_color, deep_color, 0.42 + fresnel * 0.38);
	ROUGHNESS = water_roughness;
	SPECULAR = 0.35;
	// Opaque water writes depth and avoids drawing kilometres of underwater
	// terrain through a full-screen transparency pass.
}
