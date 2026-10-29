shader_type spatial;
render_mode cull_back;
#include "res://shaders/blob_surface_circulation.gdshaderinc"
uniform bool tissue_enabled = true;
uniform float roughness_scale = 1.0;
uniform float vein_visibility = 1.0;
uniform float microdetail = 0.6;
varying vec3 tissue_position;
varying vec4 tissue_masks;
varying vec4 anatomy_masks;
varying float debug_band;
varying float strain_heat;
vec4 decode_tissue(float category) {
	return vec4(exp(-pow((category-1.0)*2.5,2.0)), exp(-pow((category-3.0)*2.5,2.0)), exp(-pow((category-5.0)*2.5,2.0)), exp(-pow((category-8.0)*2.5,2.0)));
}
vec4 decode_anatomy(float c){return vec4(exp(-pow((c-2.0)*2.5,2.0)),exp(-pow((c-9.0)*2.5,2.0)),exp(-pow((c-4.0)*2.5,2.0)),exp(-pow((c-7.0)*2.5,2.0)));}
void vertex() {
	vec3 rest = VERTEX;
	tissue_position = rest;
	anatomy_masks=mix(decode_anatomy(UV.x),decode_anatomy(UV2.x),UV2.y);
	tissue_masks = mix(decode_tissue(UV.x), decode_tissue(UV2.x), UV2.y);
	debug_band = sin(atan(rest.z / body_radii.z, rest.y / body_radii.y) * 6.0) * 0.5 + 0.5;
	vec3 deformed=deform_vertex(rest,CUSTOM1,CUSTOM2,CUSTOM0);
	NORMAL=deform_normal(rest,NORMAL,CUSTOM1,CUSTOM2);
	strain_heat=0.0;
	if(debug_strain){
		float e=.005;
		strain_heat=max(abs(length(base_deform(rest+vec3(e,0,0))-base_deform(rest))/e-1.0),abs(length(base_deform(rest+vec3(0,e,0))-base_deform(rest))/e-1.0));
	}
	VERTEX = deformed;
}
#include "res://shaders/blob_tissue_fields.gdshaderinc"
void fragment() {
	vec3 p = tissue_position;
	float sac = tissue_masks.x;
	float root = tissue_masks.y;
	float membrane = tissue_masks.z;
	float cavity = tissue_masks.w;
	float grain = noise(p * 32.0);
	float mottles = noise(p * 5.0);
	float fibers = pow(0.5 + 0.5 * sin(p.y * 55.0 + noise(p * 8.0) * 5.0), 6.0);
	float veins = vein_visibility * (1.0 - smoothstep(0.01, 0.04, abs(noise(p * vec3(14.0, 5.0, 14.0)) - 0.5)));
	float pores=smoothstep(.35,.43,noise(p*72.0))*(1.0-smoothstep(.48,.55,noise(p*72.0)));
	float relief = grain * mix(0.14, 0.035, sac) + fibers * root * 0.35 + veins * sac * 0.1 + pores*anatomy_masks.x*.16 + fibers*anatomy_masks.y*.08;
	ALBEDO = COLOR.rgb;
	if (tissue_enabled) {
		ALBEDO = sample_tissue_color(ALBEDO,p);
		ALBEDO = mix(ALBEDO, ALBEDO * vec3(0.58, 0.34, 0.29), veins * sac * 0.12);
		vec3 dx = dFdx(VERTEX), dy = dFdy(VERTEX);
		vec3 r1 = cross(dy, NORMAL), r2 = cross(NORMAL, dx);
		float determinant = dot(dx, r1);
		vec3 gradient = microdetail * sign(determinant) * (dFdx(relief) * r1 + dFdy(relief) * r2);
		NORMAL = normalize(abs(determinant) * NORMAL - gradient * 0.006);
	}
	ROUGHNESS = tissue_enabled ? clamp((0.8 - UV.y * 0.08 - sac * 0.19 - cavity * 0.2 + root * 0.04 + anatomy_masks.x*.09 + anatomy_masks.y*.1 + grain * 0.04) * roughness_scale, 0.2, 0.94) : 0.8;
	CLEARCOAT=tissue_enabled ? clamp(sac*.1+membrane*.08+cavity*.14,0.0,.18) : 0.0;
	CLEARCOAT_ROUGHNESS=.4+root*.2;
	SPECULAR = 0.27;
	RIM = membrane * 0.3 + sac * 0.12;
	RIM_TINT = 0.4;
	BACKLIGHT = COLOR.rgb * membrane * 0.07;
	AO = 1.0 - cavity * 0.22;
	if (!tissue_enabled) { ALBEDO=vec3(.36,.32,.26); ROUGHNESS=.86; SPECULAR=.24; }
	if(debug_strain)ALBEDO=mix(vec3(.1,.6,.3),vec3(.9,.12,.05),clamp(strain_heat*2.0,0.0,1.0));
	if (debug_features) ALBEDO = .25+.65*fract(vec3(UV.x*.37,UV.x*.61,UV.x*.83));
	if (debug_circulation) ALBEDO = mix(vec3(0.12,0.23,0.15),vec3(0.85,0.48,0.12),smoothstep(0.45,0.55,debug_band));
}
