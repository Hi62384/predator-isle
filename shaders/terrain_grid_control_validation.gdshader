shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/terrain_grid_vertex.gdshaderinc"
void fragment(){
 ivec2 index=ivec2(0,0);
 vec4 a=terrain_grid_control(index,0);
 vec4 b=terrain_grid_control(index,1);
 vec4 c=terrain_grid_control(index,2);
 vec4 d=terrain_grid_control(index,3);
 COLOR=UV.x<0.5?vec4(a.x,b.x,c.x,1.0):vec4(d.x,a.y,b.y,1.0);
}
