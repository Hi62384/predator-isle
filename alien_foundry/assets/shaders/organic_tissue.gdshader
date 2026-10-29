shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_back;

// One coherent, tunable biology, not random colors per body part.
// A negative tissue_index consumes the SDF's smoothly interpolated region mask.
uniform float tissue_index = -1.0;
uniform float edge_tissue_index = -1.0;
uniform vec2 module_half_extent = vec2(0.5,0.7);
uniform vec2 module_center = vec2(0.0);
uniform int module_transition_axis = -1;
uniform vec2 module_transition_range = vec2(-0.3,-0.1);
uniform bool module_transition_toward_low = true;
uniform float module_contact_occlusion = 1.0;
uniform float creature_wetness = 1.0;
uniform float roughness_bias = 0.0;
// Default-off controlled comparison; no extra field or global glossy coat.
uniform float localized_moisture_strength : hint_range(0.0,1.0) = 0.0;
// Opt-in complete Blob candidate; the ordinary material path stays unchanged.
// These hues share the existing bind atlas and anatomical masks, not node IDs.
uniform bool porous_sac_profile = false;
uniform vec4 colony_olive_color : source_color = vec4(0.43,0.425,0.29,1.0);
uniform vec4 colony_strain_color : source_color = vec4(0.47,0.32,0.345,1.0);
uniform vec4 colony_vascular_color : source_color = vec4(0.31,0.225,0.27,1.0);
uniform bool use_surface_context = false;
uniform float texture_scale = 1.0;
uniform float detail_strength : hint_range(0.0, 1.5) = 0.7;
uniform float seed_offset = 0.0;
uniform vec4 primary_color : source_color = vec4(0.61, 0.53, 0.44, 1.0);
uniform vec4 secondary_color : source_color = vec4(0.33, 0.24, 0.20, 1.0);
uniform vec4 pale_color : source_color = vec4(0.76, 0.69, 0.57, 1.0);
uniform mat4 tissue_transform = mat4(1.0);
uniform bool use_bind_coordinates = false;
uniform bool use_curve_uv = false;
uniform bool use_authored_fibre_uv = false;
uniform bool use_macro_occlusion = false;
uniform bool use_vascular_field = false;
uniform sampler2D vascular_field : filter_linear_mipmap, repeat_enable;
uniform bool use_tissue_atlas = false;
uniform sampler2D tissue_tone : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tissue_relief : filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool use_structural_atlas = false;
uniform sampler2D tissue_structure : filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 tissue_position;
varying vec3 tissue_flow;
varying vec4 region;
varying vec3 biological_color;
varying vec4 biological_response;
varying vec3 biological_flags;
varying vec2 biological_layers;
varying vec4 biological_identity;
varying vec3 curve_coordinate;
varying float macro_occlusion;
varying vec4 surface_context;

vec3 tissue_color(float index) {
	if (index < 0.5) { return mix(primary_color.rgb,pale_color.rgb,0.10); }
	if (index < 1.5) { return mix(secondary_color.rgb,primary_color.rgb,0.12) * vec3(1.02,0.98,0.93); }
	if (index < 2.5) {
		if (porous_sac_profile) { return mix(colony_strain_color.rgb,secondary_color.rgb,0.16); }
		return mix(secondary_color.rgb,primary_color.rgb,0.25) * vec3(1.13,0.84,0.87);
	}
	if (index < 3.5) { return mix(primary_color.rgb * 0.34,secondary_color.rgb * 0.75,0.57); }
	if (index < 4.5) { return mix(pale_color.rgb,primary_color.rgb,0.14); }
	if (index < 5.5) { return mix(primary_color.rgb,pale_color.rgb,0.29); }
	if (index < 6.5) { return mix(primary_color.rgb,secondary_color.rgb,0.31) * vec3(0.87,0.84,0.77); }
	return mix(pale_color.rgb*0.70,primary_color.rgb*0.40,0.40);
}
// roughness, height gain, fibrous grain, wetness
vec4 tissue_response(float index) {
	if (index < 0.5) { return vec4(0.43,0.62,0.22,0.58); }
	if (index < 1.5) { return vec4(0.47,0.96,0.92,0.40); }
	if (index < 2.5) { return vec4(0.39,0.78,1.00,0.74); }
	if (index < 3.5) { return vec4(0.37,0.59,0.34,0.35); }
	if (index < 4.5) { return vec4(0.53,0.34,0.15,0.14); }
	if (index < 5.5) { return vec4(0.26,0.22,0.54,0.63); }
	if (index < 6.5) { return vec4(0.17,0.12,0.07,1.00); }
	return vec4(0.21,0.21,0.10,0.33);
}
void vertex() {
	surface_context=use_surface_context ? clamp(CUSTOM3,vec4(0.0),vec4(1.0)) : vec4(0.0,0.0,0.0,1.0);
	macro_occlusion=use_macro_occlusion ? clamp(CUSTOM2.r,0.25,1.0) : 1.0;
	// Skinned VERTEX/TANGENT already contain the animated pose. Untransformed
	// custom channels retain material coordinates so the texture does not swim.
	vec3 material_position = use_bind_coordinates ? CUSTOM0.xyz : VERTEX;
	vec3 material_flow = use_bind_coordinates ? CUSTOM1.xyz : vec3(0.0,1.0,0.0);
	tissue_position = (tissue_transform * vec4(material_position, 1.0)).xyz;
	tissue_flow = mat3(tissue_transform) * material_flow;
	region = COLOR;
	// Sine/cosine encode periodic ring coordinates only, not a stripe field.
	curve_coordinate=vec3(cos(UV.x*6.2831853),sin(UV.x*6.2831853),UV.y);
	if (use_authored_fibre_uv) { curve_coordinate=vec3(UV,0.0); }
	// Imported modules do not carry the volume's semantic COLOR masks. Their
	// default white attribute must not suppress all pores/folds as "protected".
	if (tissue_index >= 0.0) { region=vec4(0.0,0.5,0.0,0.0); }
	// Decode categorical IDs BEFORE raster interpolation. Interpolating IDs
	// themselves would invent chitin between flesh (0) and slime (6).
	float first = tissue_index < 0.0 ? round(clamp(COLOR.r*7.0,0.0,7.0)) : tissue_index;
	float second = tissue_index < 0.0 ? round(clamp(UV2.x*7.0,0.0,7.0)) : tissue_index;
	float amount = tissue_index < 0.0 ? clamp(UV2.y,0.0,1.0) : 0.0;
	biological_color = mix(tissue_color(first),tissue_color(second),amount);
	biological_response = mix(tissue_response(first),tissue_response(second),amount);
	vec3 flag_a = vec3(float(abs(first-3.0)<0.1),float(abs(first-7.0)<0.1),float(abs(first-5.0)<0.1));
	vec3 flag_b = vec3(float(abs(second-3.0)<0.1),float(abs(second-7.0)<0.1),float(abs(second-5.0)<0.1));
	biological_flags = mix(flag_a,flag_b,amount);
	vec2 layer_a=vec2(float(first>0.5 && first<2.5),float(first<0.5 || abs(first-5.0)<0.1 || abs(first-6.0)<0.1));
	vec2 layer_b=vec2(float(second>0.5 && second<2.5),float(second<0.5 || abs(second-5.0)<0.1 || abs(second-6.0)<0.1));
	biological_layers=mix(layer_a,layer_b,amount);
	vec4 identity_a=vec4(float(abs(first-1.0)<0.1),float(abs(first-2.0)<0.1),float(abs(first-4.0)<0.1),float(abs(first-6.0)<0.1));
	vec4 identity_b=vec4(float(abs(second-1.0)<0.1),float(abs(second-2.0)<0.1),float(abs(second-4.0)<0.1),float(abs(second-6.0)<0.1));
	biological_identity=mix(identity_a,identity_b,amount);
	if (edge_tissue_index >= 0.0 && tissue_index >= 0.0) {
		float rim = smoothstep(0.42,0.94,length((VERTEX.xy-module_center)/max(module_half_extent,vec2(0.001))));
		if (module_transition_axis >= 0 && module_transition_axis <= 2) {
			float axial=VERTEX.x;
			if (module_transition_axis == 1) { axial=VERTEX.y; }
			if (module_transition_axis == 2) { axial=VERTEX.z; }
			rim=smoothstep(module_transition_range.x,module_transition_range.y,axial);
			if (module_transition_toward_low) { rim=1.0-rim; }
		}
		macro_occlusion*=mix(1.0,module_contact_occlusion,rim);
		surface_context.x=max(surface_context.x,rim);
		biological_color = mix(biological_color,tissue_color(edge_tissue_index),rim);
		biological_response = mix(biological_response,tissue_response(edge_tissue_index),rim);
		vec3 edge_flags = vec3(float(abs(edge_tissue_index-3.0)<0.1),float(abs(edge_tissue_index-7.0)<0.1),float(abs(edge_tissue_index-5.0)<0.1));
		biological_flags = mix(biological_flags,edge_flags,rim);
		vec2 edge_layers=vec2(float(edge_tissue_index>0.5 && edge_tissue_index<2.5),float(edge_tissue_index<0.5 || abs(edge_tissue_index-5.0)<0.1 || abs(edge_tissue_index-6.0)<0.1));
		biological_layers=mix(biological_layers,edge_layers,rim);
		vec4 edge_identity=vec4(float(abs(edge_tissue_index-1.0)<0.1),float(abs(edge_tissue_index-2.0)<0.1),float(abs(edge_tissue_index-4.0)<0.1),float(abs(edge_tissue_index-6.0)<0.1));
		biological_identity=mix(biological_identity,edge_identity,rim);
	}
}
void fragment() {
	vec3 p=tissue_position*texture_scale;
	vec3 bind_normal=abs(normalize(cross(dFdx(p),dFdy(p))+vec3(0.000001)));
	vec3 projection=pow(bind_normal,vec3(4.0));
	projection/=max(dot(projection,vec3(1.0)),0.0001);
	vec4 tone=vec4(0.5,0.0,0.0,0.5);
	vec4 relief=vec4(0.5,0.0,0.3,0.0);
	// Two bounded, mip-filtered structured fields. Continuous rest coordinates
	// are shared across modules and the host; no varying-frame phase or sine.
	if (use_tissue_atlas) {
		vec3 q=p*0.56;
		tone=texture(tissue_tone,q.yz)*projection.x;
		tone+=texture(tissue_tone,q.xz+vec2(0.31,0.47))*projection.y;
		tone+=texture(tissue_tone,q.xy+vec2(0.63,0.19))*projection.z;
		if (!use_curve_uv && !use_authored_fibre_uv) {
			relief=texture(tissue_relief,q.zy)*projection.x;
			relief+=texture(tissue_relief,q.xz+vec2(0.31,0.47))*projection.y;
			relief+=texture(tissue_relief,q.xy+vec2(0.63,0.19))*projection.z;
		}
	} else if (use_vascular_field) {
		vec3 v=texture(vascular_field,p.yz*0.56).rgb*projection.x;
		v+=texture(vascular_field,p.xz*0.56+vec2(0.31,0.47)).rgb*projection.y;
		v+=texture(vascular_field,p.xy*0.56+vec2(0.63,0.19)).rgb*projection.z;
		tone.gb=v.rg;
	}
	// Exact sweep coordinates make local striation follow a bent anatomical
	// centerline. Their ring coordinate is interpolated on the circle, avoiding
	// the long interpolation across the shared ring seam.
	if (use_authored_fibre_uv && use_tissue_atlas) {
		// Explicit anatomical charts: U transverse, V physical longitudinal
		// distance. Unlike sweep UVs these charts do not wrap through atan.
		relief=texture(tissue_relief,vec2(curve_coordinate.x,curve_coordinate.y*texture_scale*0.56));
	} else if (use_curve_uv && use_tissue_atlas) {
		vec2 curve_uv=vec2(atan(curve_coordinate.y,curve_coordinate.x)/6.2831853+0.5,curve_coordinate.z*0.56);
		relief=texture(tissue_relief,curve_uv);
	}
	vec4 response=biological_response;
	float hard=clamp(biological_flags.x+biological_flags.y,0.0,1.0);
	float soft=clamp(biological_layers.y+biological_layers.x*0.8,0.0,1.0);
	float joint=clamp(region.a,0.0,1.0);
	float attachment=surface_context.x;
	float growth=surface_context.y;
	float thickness=surface_context.w;
	float crease=relief.g*(0.10+joint*1.35+attachment*0.70+response.z*0.28)*(1.0-region.b*0.6);
	float pigment=clamp(tone.r,0.0,1.0);
	float exposure=smoothstep(0.32,0.76,relief.b)*biological_layers.x;
	if (use_surface_context) { exposure*=0.25+surface_context.z*0.95; }
	float wet=clamp(smoothstep(0.23,0.78,tone.a)*creature_wetness+attachment*0.12,0.0,1.0);
	float vascular=soft*float(use_vascular_field)*(1.0-hard)*(1.0-biological_identity.z);
	float root_tissue=biological_identity.x;
	float muscle=biological_identity.y;
	float bone=biological_identity.z;
	float slime=biological_identity.w;
	vec4 structure=vec4(0.0,0.0,0.5,0.0);
	if (use_structural_atlas && hard+bone > 0.015) {
		vec3 q=p*0.77;
		structure=texture(tissue_structure,q.zy)*projection.x;
		structure+=texture(tissue_structure,q.xz+vec2(0.31,0.47))*projection.y;
		structure+=texture(tissue_structure,q.xy+vec2(0.63,0.19))*projection.z;
	}
	vec3 blush=mix(primary_color.rgb*vec3(1.08,0.79,0.78),secondary_color.rgb,0.15);
	vec3 ivory=mix(primary_color.rgb,pale_color.rgb,0.48);
	vec3 base=biological_color;
	float sac_skin=clamp(biological_layers.y-biological_flags.z,0.0,1.0)*(1.0-hard)*(1.0-bone);
	if (porous_sac_profile) {
		// Quiet amber-to-olive pigment shares one continuous organism-space
		// field. Swollen sacs are not assigned unrelated flat colors per node.
		float olive_amount=clamp((pigment-0.28)*1.15,0.0,0.58);
		vec3 sac_color=mix(primary_color.rgb,colony_olive_color.rgb,olive_amount);
		base=mix(base,sac_color,sac_skin*0.84);
		blush=colony_strain_color.rgb;
	}
	// Broad melanin is restrained. Stronger variation belongs to real tissue
	// exposure, creases and vascular neighborhoods, not arbitrary cow spots.
	float pigment_gain=mix(0.16,0.045,clamp(hard+bone,0.0,1.0));
	vec3 color=base*(1.0+(pigment-0.5)*pigment_gain);
	color=mix(color,blush,soft*((1.0-pigment)*0.08+attachment*0.12+joint*0.055+growth*0.065));
	// Carrier-derived recess tint is restrained and follows the bind tissue.
	// AO still supplies illumination occlusion; this is biological discoloration.
	float recess=clamp(1.0-macro_occlusion,0.0,0.72);
	color=mix(color,mix(secondary_color.rgb,blush,0.25),recess*soft*0.21);
	float colony_strain=0.0;
	if (porous_sac_profile) {
		// Real carrier occlusion, insertion and relative thickness locate the
		// cool strain tissue. COLOR.g remains ordinary variation, NOT cavity ID.
		colony_strain=clamp(recess*1.05+attachment*0.42+(1.0-thickness)*0.24+joint*0.18+surface_context.z*0.18,0.0,0.88)*soft;
		color=mix(color,colony_strain_color.rgb,colony_strain*0.74);
		color=mix(color,colony_vascular_color.rgb,recess*soft*0.20);
	}
	color*=1.0+(region.g-0.5)*soft*0.035;
	vec3 fibre=mix(secondary_color.rgb,blush,0.28+muscle*0.20);
	fibre*=vec3(1.0+muscle*0.08,1.0-muscle*0.08,1.0-muscle*0.035);
	vec3 sheath=ivory*(0.92+pigment*0.10);
	float sheath_amount=(1.0-exposure)*(root_tissue*0.18+muscle*0.28);
	color=mix(color,sheath,sheath_amount);
	color=mix(color,fibre,exposure*(root_tissue*0.28+muscle*0.40));
	vec3 subdermal=mix(blush,secondary_color.rgb*vec3(0.90,0.85,1.04),0.28);
	if (porous_sac_profile) { subdermal=colony_vascular_color.rgb; }
	color=mix(color,subdermal,tone.b*vascular*0.44);
	color=mix(color,subdermal,tone.g*vascular*0.18);
	float fibre_height=max((relief.r-0.5)*4.5,0.0);
	color*=1.0-crease*(0.10+root_tissue*0.16)*detail_strength;
	color*=1.0-fibre_height*(root_tissue*0.12+muscle*0.10)*detail_strength;
	float plate=biological_flags.x;
	color*=1.0-structure.r*plate*0.23+structure.g*plate*0.07;
	color*=1.0+(structure.b-0.5)*bone*0.085;
	color=mix(color,pale_color.rgb,structure.a*biological_flags.y*0.16);
	float moist_anatomy=smoothstep(0.12,0.65,attachment*0.90+joint*0.65+recess*0.80+growth*0.10);
	float moist_field=smoothstep(0.43,0.87,tone.a);
	float moist_film=clamp(moist_field*(0.035+0.965*moist_anatomy)*creature_wetness,0.0,1.0);
	moist_film*=localized_moisture_strength*soft*(1.0-root_tissue*0.85)*(1.0-slime);
	if (porous_sac_profile) {
		// Anatomy determines coverage; the existing atlas modulates strength
		// rather than rejecting almost every patch with a high threshold.
		float moist_region=clamp(0.08+growth*0.34+attachment*0.45+recess*0.68+(1.0-thickness)*0.14,0.0,0.92);
		moist_film=moist_region*(0.48+wet*0.52)*soft*(1.0-root_tissue*0.78)*(1.0-bone)*(1.0-hard);
	}
	color*=1.0-moist_film*0.035;
	ALBEDO=max(color,vec3(0.01));
	ROUGHNESS=clamp(response.x+roughness_bias+0.09+structure.r*plate*0.10-structure.g*plate*0.045+(1.0-wet)*0.11-wet*response.w*0.23+crease*0.06+root_tissue*0.06,0.17,0.82);
	SPECULAR=mix(0.26,0.44,wet*response.w);
	ROUGHNESS=mix(ROUGHNESS,max(0.20,response.x*0.50),moist_film);
	SPECULAR=mix(SPECULAR,0.44,moist_film*0.75);
	if (porous_sac_profile) {
		ROUGHNESS=mix(ROUGHNESS,0.22,clamp(colony_strain*0.24+moist_film*0.42,0.0,0.6));
		SPECULAR=mix(SPECULAR,0.42,moist_film);
	}
	ANISOTROPY=response.z*0.30;
	METALLIC=biological_flags.y*0.045;
	BACKLIGHT=mix(base,blush,0.45)*(0.035+soft*(0.065+(1.0-thickness)*0.10)+biological_flags.z*0.20+slime*0.04+bone*0.025);
	AO=macro_occlusion*clamp(1.0-crease*0.12,0.80,1.0);
	float pore=relief.a*soft*(1.0-region.b*0.8)*(1.0-slime*0.85);
	// The relief red channel contains fibrils, not generic skin roughness.
	// Bare flesh must not inherit root/muscle corduroy. Its pores and short
	// anatomical creases remain independent, including on imported modules.
	float fibre_signal=max(relief.r-0.5+relief.a*0.045,0.0);
	float exposed_fascia=use_surface_context ? surface_context.z : 0.0;
	float fibre_gain=root_tissue*0.96+muscle*1.0+exposed_fascia*0.25*(1.0-biological_layers.x);
	float height=(fibre_signal*fibre_gain-crease*(0.025+root_tissue*0.045)+tone.g*vascular*0.065-pore*0.024+(structure.g*0.065-structure.r*0.045)*plate)*response.y*detail_strength;
	// Surface-gradient bump uses the deformed view-space metric, but samples
	// the preserved bind field. Filtered texture derivatives cannot swim.
	vec3 n=normalize(NORMAL);
	vec3 dpdx=dFdx(VERTEX);
	vec3 dpdy=dFdy(VERTEX);
	vec3 r1=cross(dpdy,n);
	vec3 r2=cross(n,dpdx);
	float determinant=dot(dpdx,r1);
	vec3 gradient=(dFdx(height)*r1+dFdy(height)*r2)/max(abs(determinant),0.0000001);
	gradient*=sign(determinant);
	gradient*=min(1.0,6.0/max(length(gradient),0.001));
	vec3 detailed_normal=normalize(n-gradient*0.045);
	vec3 facet_normal=normalize(cross(dpdx,dpdy));
	facet_normal*=sign(dot(facet_normal,n));
	NORMAL=normalize(mix(detailed_normal,facet_normal,biological_flags.y*0.78));
}
