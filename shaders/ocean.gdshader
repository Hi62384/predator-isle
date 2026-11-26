shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 shallow_color : source_color = vec3(0.055, 0.43, 0.48);
uniform vec3 deep_color : source_color = vec3(0.018, 0.12, 0.24);
uniform float wave_height = 1.0;
uniform float wave_speed = 1.0;
uniform float water_roughness = 0.18;

varying vec3 world_position;

void vertex() {
	// This ocean grid spans kilometres per quad. Keep its shoreline at sea level
    // and animate the small ripples in the fragment shader.
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

#include "res://shaders/cave_ocean_mask.gdshaderinc"
#include "res://shaders/water_ripples.gdshaderinc"
void fragment() {
    if(dry_cave_ground(world_position))discard;
	vec2 p = world_position.xz;
	vec2 ripple=water_ripples(p,TIME*wave_speed)*wave_height;
 NORMAL_MAP=vec3(vec2(.5)+.018*ripple,1.0);
 NORMAL_MAP_DEPTH=1.0;
	float fresnel = pow(1.0 - max(dot(NORMAL, VIEW), 0.0), 3.0);
	ALBEDO = mix(shallow_color, deep_color, 0.42 + fresnel * 0.38);
	ROUGHNESS = water_roughness;
	SPECULAR = 0.35;
	// Opaque water writes depth and avoids drawing kilometres of underwater
	// terrain through a full-screen transparency pass.
}
