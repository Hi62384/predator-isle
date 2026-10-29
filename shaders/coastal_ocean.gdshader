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
	float wash=.5+.5*sin(p.x*.071+p.y*.049-TIME*wave_speed*1.7);
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
