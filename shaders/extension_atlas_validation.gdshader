shader_type canvas_item;
render_mode unshaded;
uniform sampler2D extension_payload:filter_linear,repeat_disable;
uniform int extension_active_mask=255;
uniform float chunk_size_metres=16.0;
varying vec3 forest_local_position;
#include "res://shaders/extension_atlas_lookup.gdshaderinc"
void vertex(){
 forest_local_position=vec3(UV.x*chunk_size_metres,0.0,UV.y*chunk_size_metres);
}
void fragment(){
 vec4 a,b;
 extension_weight_banks(a,b);
 COLOR=UV.x<0.5?a:b;
}
