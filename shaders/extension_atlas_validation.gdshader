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
 // Render all eight channels as opaque RGB; relying on the source alpha
 // would incorrectly turn single-family test cases transparent.
 vec3 sample=UV.x<0.25?a.rgb:(UV.x<0.5?vec3(a.a):(UV.x<0.75?b.rgb:vec3(b.a)));
 COLOR=vec4(sample,1.0);
}
