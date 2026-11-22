shader_type canvas_item;
render_mode unshaded;
uniform sampler2D extension_payload:filter_linear,repeat_disable;
uniform int extension_active_mask=255;
uniform float chunk_size_metres=16.0;
uniform int test_palette_slot=-1;
varying vec3 forest_local_position;
#include "res://shaders/extension_atlas_lookup.gdshaderinc"
void vertex(){
 forest_local_position=vec3(UV.x*chunk_size_metres,0.0,UV.y*chunk_size_metres);
}
void fragment(){
 // First half validates every family weight channel. The next quarters
 // validate all four material-control channels of each family, including
 // the control alpha that is not usable as the framebuffer opacity.
 if(test_palette_slot>=0 && UV.y>=.875){
  ivec2 size=textureSize(extension_payload,0);
  float row=float(size.y);
  vec2 grid=clamp(forest_local_position.xz/chunk_size_metres,vec2(0),vec2(1))*(row-1.0);
  vec4 palette=textureLod(extension_payload,
   vec2((float(test_palette_slot)*row+grid.x+.5)/float(size.x),(grid.y+.5)/row),0.0);
  COLOR=vec4(palette.rgb,1.0);
 }else if(UV.y>=.5){
  int family=int(clamp(floor(UV.x*8.0),0.0,7.0));
  vec4 controls=extension_texel(family);
  COLOR=UV.y<.75?vec4(controls.rgb,1.0):vec4(vec3(controls.a),1.0);
 }else{
  vec4 a,b;
  extension_weight_banks(a,b);
  vec3 sample=UV.x<0.25?a.rgb:(UV.x<0.5?vec3(a.a):(UV.x<0.75?b.rgb:vec3(b.a)));
  COLOR=vec4(sample,1.0);
 }
}
