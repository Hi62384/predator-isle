shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 shallow_color : source_color = vec3(0.055, 0.43, 0.48);
uniform vec3 deep_color : source_color = vec3(0.018, 0.12, 0.24);
uniform float wave_height = 1.0;
uniform float wave_speed = 1.0;
uniform float water_roughness = 0.18;
uniform sampler2D coast_depth : hint_depth_texture,repeat_disable,filter_nearest;
uniform float coast_foam_strength=.7;
uniform bool coast_foam_debug=false;

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

	// Same ocean/wave model; the opt-in coastal variant reads opaque terrain
	// depth. Compatibility has [-1,1] NDC z; do not use the Vulkan shortcut.
	float raw_depth=textureLod(coast_depth,SCREEN_UV,0.0).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc=vec3(SCREEN_UV,raw_depth)*2.0-1.0;
#else
	vec3 ndc=vec3(SCREEN_UV*2.0-1.0,raw_depth);
#endif
	vec4 ground_view=INV_PROJECTION_MATRIX*vec4(ndc,1.0);ground_view/=ground_view.w;
	vec3 ground_world=(INV_VIEW_MATRIX*vec4(ground_view.xyz,1.0)).xyz;
	float water_depth=max(world_position.y-ground_world.y,0.0);
	ALBEDO=mix(shallow_color,deep_color,clamp(smoothstep(1.5,25.0,water_depth)*.7+fresnel*.25,0.0,1.0));
	// Screen-depth derivatives amplify finite depth-buffer precision into
	// checker-shaped exposure masks. Keep wash energy spatially smooth instead.
	float exposure=.65+.15*sin(p.x*.0009+p.y*.0007);
	float wash=clamp(.55+ripple.x*.5,0.0,1.0);
	float patches=.65+.35*sin(p.x*.021-p.y*.017+sin(p.y*.037)*1.2);
	float foam=exp(-water_depth*.9)*smoothstep(.35,.85,wash)*patches*exposure*coast_foam_strength;
	foam*=1.0-smoothstep(3500.0,8000.0,length(VERTEX));
	ALBEDO=mix(ALBEDO,vec3(.76,.83,.8),clamp(foam,0.0,.75));
	ROUGHNESS = mix(water_roughness,.65,foam);
	SPECULAR = 0.35;
	// Force post-opaque scheduling so the sampled depth is TERRAIN, not this
	// ocean's own prepass. Alpha remains one: no global translucent ocean.
	ALPHA=1.0;
	if(coast_foam_debug){ALBEDO=vec3(0);EMISSION=vec3(0,0,4);SPECULAR=0.0;}
	// Original ocean.gdshader is unchanged; this coastal variant keeps its waves.
}
