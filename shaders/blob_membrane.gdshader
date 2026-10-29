shader_type spatial;
render_mode cull_back;
#include "res://shaders/blob_surface_circulation.gdshaderinc"
uniform bool tissue_enabled = true;
uniform float translucency = .5;
varying vec3 tissue_position;
void vertex() {
	tissue_position = VERTEX;
	VERTEX=deform_vertex(VERTEX,CUSTOM1,CUSTOM2,CUSTOM0);
	NORMAL=deform_normal(tissue_position,NORMAL,CUSTOM1,CUSTOM2);
}
#include "res://shaders/blob_tissue_fields.gdshaderinc"
void fragment() {
	float wrinkles = sin(tissue_position.y * 38.0 + sin(tissue_position.x * 9.0)) * .5 + .5;
	ALBEDO = sample_tissue_color(COLOR.rgb,tissue_position);
	ROUGHNESS = .68;
	CLEARCOAT=tissue_enabled?.06:0.0;
	CLEARCOAT_ROUGHNESS=.3;
	SPECULAR = .3;
	BACKLIGHT = COLOR.rgb * .13 * translucency;
	if (!tissue_enabled) { ALBEDO=vec3(.36,.32,.26); ROUGHNESS=.86; BACKLIGHT=vec3(0.0); }
}
