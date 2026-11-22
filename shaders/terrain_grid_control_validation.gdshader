shader_type canvas_item;
render_mode unshaded,blend_disabled;
#include "res://shaders/terrain_grid_vertex.gdshaderinc"
uniform int validation_product=0;
void fragment(){
 ivec2 index=clamp(ivec2(floor(UV*2.0)),ivec2(0),ivec2(1));
 int bank=clamp(int(floor(fract(UV.x*2.0)*4.0)),0,3);
 if(validation_product==1)COLOR=terrain_grid_value(index,1);
 else if(validation_product==2)COLOR=terrain_grid_value(index,2);
 else COLOR=terrain_grid_control(index,bank);
}
