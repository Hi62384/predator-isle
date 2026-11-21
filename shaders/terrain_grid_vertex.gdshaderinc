// One texel per emitted vertex. No bilinear reconstruction across a collision diagonal.
uniform bool terrain_grid_enabled=false;
uniform sampler2D terrain_grid_payload:filter_nearest,repeat_disable;
uniform int terrain_grid_rows=17;
uniform float terrain_grid_scale=0.3333333333333333;
vec4 terrain_grid_value(ivec2 vertex_index,int band){
 return texelFetch(terrain_grid_payload,vertex_index+ivec2(0,terrain_grid_rows*band),0);
}
