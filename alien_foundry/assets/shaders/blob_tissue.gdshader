shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_back;

// Blob-only material direction. Existing deformation, rest coordinates and
// categorical tissue interpolation remain intact. None of these fields is an
// albedo texture: masks stay linear scalar data in every rendering backend.
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
uniform bool use_surface_context = false;
uniform float texture_scale = 1.0;
uniform float detail_strength : hint_range(0.0,1.5) = 0.7;
uniform float seed_offset = 0.0;
uniform vec4 primary_color : source_color = vec4(0.58,0.51,0.38,1.0);
uniform vec4 secondary_color : source_color = vec4(0.32,0.25,0.215,1.0);
uniform vec4 pale_color : source_color = vec4(0.73,0.67,0.55,1.0);
uniform vec4 colony_olive_color : source_color = vec4(0.45,0.455,0.325,1.0);
uniform vec4 colony_strain_color : source_color = vec4(0.48,0.345,0.355,1.0);
uniform vec4 colony_vascular_color : source_color = vec4(0.30,0.23,0.265,1.0);
uniform float blob_pigment_strength : hint_range(0.0,1.0) = 0.42;
uniform float blob_vascular_strength : hint_range(0.0,1.0) = 0.58;
uniform float blob_moisture_strength : hint_range(0.0,1.0) = 0.78;
uniform float blob_fibre_strength : hint_range(0.0,1.0) = 0.66;
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
    if (index < 0.5) { return mix(primary_color.rgb,pale_color.rgb,0.08); }
    if (index < 1.5) { return mix(secondary_color.rgb,primary_color.rgb,0.43); }
    if (index < 2.5) { return mix(colony_strain_color.rgb,primary_color.rgb,0.12); }
    if (index < 3.5) { return mix(secondary_color.rgb*0.66,primary_color.rgb*0.33,0.35); }
    if (index < 4.5) { return mix(pale_color.rgb,primary_color.rgb,0.14); }
    if (index < 5.5) { return mix(primary_color.rgb,pale_color.rgb,0.24); }
    if (index < 6.5) { return mix(primary_color.rgb,colony_olive_color.rgb,0.42); }
    return mix(pale_color.rgb*0.70,primary_color.rgb*0.40,0.40);
}
// Roughness, relief gain, fibrous grain and biological moisture potential.
vec4 tissue_response(float index) {
    if (index < 0.5) { return vec4(0.49,0.50,0.16,0.65); }
    if (index < 1.5) { return vec4(0.55,0.86,0.90,0.34); }
    if (index < 2.5) { return vec4(0.46,0.78,1.00,0.82); }
    if (index < 3.5) { return vec4(0.56,0.46,0.26,0.24); }
    if (index < 4.5) { return vec4(0.58,0.26,0.12,0.16); }
    if (index < 5.5) { return vec4(0.36,0.22,0.42,0.77); }
    if (index < 6.5) { return vec4(0.30,0.12,0.07,1.00); }
    return vec4(0.30,0.20,0.10,0.32);
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
    vec4 broad=vec4(0.5,0.0,0.0,0.5);
    vec4 relief=vec4(0.5,0.0,0.3,0.0);
    if (use_tissue_atlas) {
        vec3 q=p*0.56;
        tone=texture(tissue_tone,q.yz)*projection.x;
        tone+=texture(tissue_tone,q.xz+vec2(0.31,0.47))*projection.y;
        tone+=texture(tissue_tone,q.xy+vec2(0.63,0.19))*projection.z;
        // A separate low-frequency sample is pigment only. No frequency
        // subtraction, thresholded contour field, or copied source color.
        vec3 b=p*0.30+vec3(0.13,0.27,0.41);
        broad=texture(tissue_tone,b.yz,1.5)*projection.x;
        broad+=texture(tissue_tone,b.xz+vec2(0.31,0.47),1.5)*projection.y;
        broad+=texture(tissue_tone,b.xy+vec2(0.63,0.19),1.5)*projection.z;
        relief=texture(tissue_relief,q.zy)*projection.x;
        relief+=texture(tissue_relief,q.xz+vec2(0.31,0.47))*projection.y;
        relief+=texture(tissue_relief,q.xy+vec2(0.63,0.19))*projection.z;
        if (use_authored_fibre_uv) {
            relief=texture(tissue_relief,vec2(curve_coordinate.x,curve_coordinate.y*texture_scale*0.56));
        } else if (use_curve_uv) {
            vec2 curve_uv=vec2(atan(curve_coordinate.y,curve_coordinate.x)/6.2831853+0.5,curve_coordinate.z*0.56);
            relief=texture(tissue_relief,curve_uv);
        }
    } else if (use_vascular_field) {
        vec3 v=texture(vascular_field,p.yz*0.56).rgb*projection.x;
        v+=texture(vascular_field,p.xz*0.56+vec2(0.31,0.47)).rgb*projection.y;
        v+=texture(vascular_field,p.xy*0.56+vec2(0.63,0.19)).rgb*projection.z;
        tone.gb=v.rg;
    }
    vec4 response=biological_response;
    float hard=clamp(biological_flags.x+biological_flags.y,0.0,1.0);
    float root_tissue=biological_identity.x;
    float muscle=biological_identity.y;
    float bone=biological_identity.z;
    float slime=biological_identity.w;
    float soft=clamp(biological_layers.x+biological_layers.y,0.0,1.0)*(1.0-hard)*(1.0-bone);
    float sac_skin=clamp(biological_layers.y-biological_flags.z,0.0,1.0)*(1.0-hard)*(1.0-bone);
    float attachment=surface_context.x;
    float growth=surface_context.y;
    float exposed_fascia=surface_context.z;
    float thickness=surface_context.w;
    float joint=clamp(region.a,0.0,1.0);
    float protected_region=clamp(region.b,0.0,1.0);
    float recess=clamp(1.0-macro_occlusion,0.0,0.75);
    float pigment=clamp(broad.r,0.0,1.0);
    // Broad wet membranes meet dry stretched sacs without unrelated per-node
    // patches. Everything is a bounded mix of the same organism palette.
    vec3 base=biological_color;
    float olive=smoothstep(0.29,0.75,pigment)*blob_pigment_strength;
    base=mix(base,colony_olive_color.rgb,olive*sac_skin);
    float anatomical_strain=clamp(attachment*0.50+joint*0.24+recess*0.58+(1.0-thickness)*0.18+exposed_fascia*0.22,0.0,0.85);
    float strain=anatomical_strain*soft*(1.0-protected_region*0.38);
    vec3 color=mix(base,colony_strain_color.rgb,strain*0.66);
    // This low contrast term is broad pigment, never a synthetic cavity.
    color*=1.0+(pigment-0.5)*0.14*blob_pigment_strength;
    color*=1.0+(region.g-0.5)*soft*0.025;
    // Actual occlusion carries the recess tint. Outer sac surfaces remain
    // clean even if atlas veins or folds happen to cross them.
    float deep_recess=smoothstep(0.17,0.70,recess);
    vec3 recess_color=mix(secondary_color.rgb*0.53,colony_vascular_color.rgb*0.54,0.30);
    color=mix(color,recess_color,deep_recess*soft*0.58);
    float exposure=smoothstep(0.36,0.80,relief.b)*(0.22+exposed_fascia*0.78);
    vec3 fibre=mix(secondary_color.rgb,colony_strain_color.rgb,0.32+muscle*0.16);
    vec3 sheath=mix(primary_color.rgb,pale_color.rgb,0.55);
    color=mix(color,sheath,(1.0-exposure)*(root_tissue*0.19+muscle*0.13));
    color=mix(color,fibre,exposure*(root_tissue*0.20+muscle*0.28));
    // Sparse, explicit branching atlas vessels become visible chiefly in
    // insertion/strained tissue, rather than tracing every noise contour.
    float vessel_region=clamp(0.055+strain*0.78+exposed_fascia*0.22+muscle*0.28,0.0,0.85);
    float vascular=soft*float(use_vascular_field)*vessel_region*blob_vascular_strength;
    vascular*=1.0-protected_region*0.60;
    float vessel_core=smoothstep(0.06,0.60,tone.g);
    color=mix(color,colony_vascular_color.rgb,tone.b*vascular*0.17);
    color=mix(color,colony_vascular_color.rgb,vessel_core*vascular*0.38);
    float crease=relief.g*(joint*0.80+attachment*0.58+response.z*0.18)*(1.0-protected_region*0.75);
    // Most fibrous detail lives in normals, not dark tattoo-like albedo.
    color*=1.0-crease*(0.035+root_tissue*0.045)*detail_strength;
    float wet_field=smoothstep(0.25,0.77,broad.a);
    float moist_region=clamp(0.10+attachment*0.62+recess*0.58+joint*0.28+growth*0.18+(1.0-thickness)*0.18,0.0,0.95);
    float moist_film=clamp(moist_region*(0.58+wet_field*0.42)*creature_wetness*blob_moisture_strength,0.0,1.0)*soft;
    moist_film*=1.0-root_tissue*0.53;
    moist_film=max(moist_film,slime*0.46);
    color*=1.0-moist_film*0.025;
    ALBEDO=clamp(color,vec3(0.008),vec3(0.86));
    float dry_roughness=clamp(response.x+roughness_bias+(1.0-wet_field)*0.065+crease*0.035,0.28,0.82);
    ROUGHNESS=mix(dry_roughness,0.235,moist_film*0.88);
    SPECULAR=mix(0.27,0.44,clamp(moist_film+slime*0.15,0.0,1.0));
    ANISOTROPY=response.z*blob_fibre_strength*0.24;
    METALLIC=0.0;
    BACKLIGHT=mix(base,colony_strain_color.rgb,0.40)*(0.025+soft*(1.0-thickness)*0.055+biological_flags.z*0.07);
    AO=macro_occlusion*clamp(1.0-crease*0.10,0.88,1.0);
    float pore=relief.a*soft*(1.0-protected_region*0.85)*(1.0-slime*0.86);
    float fibre_signal=max(relief.r-0.5+relief.a*0.045,0.0);
    float fibre_gain=(root_tissue*0.83+muscle*0.94+exposed_fascia*0.23*(1.0-biological_layers.x))*blob_fibre_strength;
    float height=(fibre_signal*fibre_gain-crease*0.035+vessel_core*vascular*0.018-pore*0.018)*response.y*detail_strength;
    // Surface-gradient relief follows the posed surface while its samples use
    // preserved bind coordinates. Bone weights/tangents are not modified.
    vec3 n=normalize(NORMAL);
    vec3 dpdx=dFdx(VERTEX);
    vec3 dpdy=dFdy(VERTEX);
    vec3 r1=cross(dpdy,n);
    vec3 r2=cross(n,dpdx);
    float determinant=dot(dpdx,r1);
    vec3 gradient=(dFdx(height)*r1+dFdy(height)*r2)/max(abs(determinant),0.0000001);
    gradient*=sign(determinant);
    // Subpixel fibres and triplanar triangle-boundary derivatives must not
    // become chisel marks. Bound tangent slope to about 3.4 degrees of tilt;
    // authored geometry still supplies all silhouette-scale folds and ridges.
    gradient*=min(1.0,1.5/max(length(gradient),0.001));
    NORMAL=normalize(n-gradient*0.040);
}
