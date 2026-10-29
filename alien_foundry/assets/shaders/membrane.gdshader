shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled, diffuse_burley, specular_schlick_ggx;
uniform vec4 primary_color : source_color = vec4(0.61,0.53,0.44,1.0);
uniform vec4 secondary_color : source_color = vec4(0.33,0.24,0.20,1.0);
uniform vec4 pale_color : source_color = vec4(0.76,0.69,0.57,1.0);
uniform float texture_scale = 1.0;
uniform float seed_offset = 0.0;
uniform float detail_strength = 0.7;
uniform mat4 tissue_transform = mat4(1.0);
uniform bool use_bind_coordinates = false;
uniform bool use_surface_context = false;
uniform bool use_macro_occlusion = false;
uniform bool use_authored_fibre_uv = false;
uniform float creature_wetness = 1.0;
uniform float roughness_bias = 0.0;
uniform bool porous_sac_profile = false;
uniform vec4 colony_olive_color : source_color = vec4(0.43,0.425,0.29,1.0);
uniform vec4 colony_strain_color : source_color = vec4(0.47,0.32,0.345,1.0);
uniform vec4 colony_vascular_color : source_color = vec4(0.31,0.225,0.27,1.0);
varying vec4 surface_context;
varying float macro_occlusion;
varying vec2 fibre_coordinate;
uniform bool use_tissue_atlas = false;
uniform bool use_vascular_field = true;
uniform sampler2D tissue_tone : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tissue_relief : filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 p;
void vertex() {
	surface_context=use_surface_context ? clamp(CUSTOM3,vec4(0.0),vec4(1.0)) : vec4(0.0,0.0,0.0,1.0);
	macro_occlusion=use_macro_occlusion ? clamp(CUSTOM2.r,0.25,1.0) : 1.0;
	fibre_coordinate=UV;
	vec3 material_position=use_bind_coordinates ? CUSTOM0.xyz : VERTEX;
	p=(tissue_transform*vec4(material_position,1.0)).xyz*texture_scale;
}
void fragment() {
	vec3 bind_normal=abs(normalize(cross(dFdx(p),dFdy(p))+vec3(0.000001)));
	vec3 projection=pow(bind_normal,vec3(4.0));
	projection/=max(dot(projection,vec3(1.0)),0.0001);
	vec4 tone=vec4(0.5,0.0,0.0,0.5);
	vec4 relief=vec4(0.5,0.0,0.3,0.0);
	if (use_tissue_atlas) {
		vec3 q=p*0.56;
		tone=texture(tissue_tone,q.yz)*projection.x;
		tone+=texture(tissue_tone,q.xz+vec2(0.31,0.47))*projection.y;
		tone+=texture(tissue_tone,q.xy+vec2(0.63,0.19))*projection.z;
		if (use_authored_fibre_uv) {
			relief=texture(tissue_relief,vec2(fibre_coordinate.x,fibre_coordinate.y*texture_scale*0.56));
		} else {
			relief=texture(tissue_relief,q.yz)*projection.x;
			relief+=texture(tissue_relief,q.xz+vec2(0.31,0.47))*projection.y;
			relief+=texture(tissue_relief,q.xy+vec2(0.63,0.19))*projection.z;
		}
	}
	float pigment=clamp(tone.r,0.0,1.0);
	float vascular=float(use_vascular_field);
	float rim=pow(1.0-abs(dot(normalize(NORMAL),normalize(VIEW))),2.0);
	vec3 ivory=mix(primary_color.rgb,pale_color.rgb,0.24+pigment*0.22);
	vec3 blush=mix(primary_color.rgb*vec3(1.03,0.80,0.78),secondary_color.rgb,0.25);
	vec3 color=ivory*(0.96+pigment*0.08);
	color=mix(color,blush,(tone.b*0.46+tone.g*0.22)*vascular);
	if (porous_sac_profile) {
		ivory=mix(primary_color.rgb,pale_color.rgb,0.24);
		blush=colony_strain_color.rgb;
		color=mix(ivory,colony_olive_color.rgb,0.15+pigment*0.18);
		color=mix(color,blush,surface_context.x*0.42+(1.0-surface_context.w)*0.14);
		color=mix(color,colony_vascular_color.rgb,(tone.b*0.50+tone.g*0.30)*vascular);
	}
	ALBEDO=mix(color,blush,surface_context.x*0.12)*(1.0-relief.g*(0.04+surface_context.x*0.08));
	AO=macro_occlusion;
	ROUGHNESS=clamp(0.50+roughness_bias-tone.a*creature_wetness*0.20+relief.g*0.06,0.27,0.59);
	SPECULAR=0.35;
	BACKLIGHT=mix(ivory,blush,0.3)*(0.40+(1.0-surface_context.w)*0.16);
	ALPHA=clamp(0.59+tone.g*0.19*vascular+rim*0.28+relief.b*0.12,0.54,0.96);
	if (porous_sac_profile) {
		float thinness=1.0-surface_context.w;
		ROUGHNESS=clamp(0.40-tone.a*creature_wetness*0.17+relief.g*0.05,0.22,0.46);
		SPECULAR=0.40;
		BACKLIGHT=mix(ivory,blush,0.32)*(0.42+thinness*0.22);
		ALPHA=clamp(0.64-thinness*0.14+surface_context.x*0.16+tone.g*vascular*0.14+rim*0.18,0.48,0.95);
	}
	float height=((relief.r-0.5)*0.22+tone.g*vascular*0.055-relief.g*0.025)*detail_strength;
	vec3 n=normalize(NORMAL);
	vec3 dx=dFdx(VERTEX); vec3 dy=dFdy(VERTEX);
	vec3 r1=cross(dy,n); vec3 r2=cross(n,dx);
	float det=dot(dx,r1);
	vec3 gradient=(dFdx(height)*r1+dFdy(height)*r2)/max(abs(det),0.0000001)*sign(det);
	gradient*=min(1.0,6.0/max(length(gradient),0.001));
	NORMAL=normalize(n-gradient*0.025);
}
