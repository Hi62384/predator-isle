// One texel per emitted vertex. No bilinear reconstruction across a collision diagonal.
uniform bool terrain_grid_enabled=false;
uniform sampler2D terrain_grid_payload:filter_nearest,repeat_disable;
uniform int terrain_grid_rows=17;
uniform float terrain_grid_scale=0.3333333333333333;
// Exact +0.0 control banks need no texture fetch. Default 15 preserves
// legacy meshes/materials that do not supply the per-page specialization.
uniform int terrain_grid_control_mask=15;
vec4 terrain_grid_value(ivec2 vertex_index,int band){
 return texelFetch(terrain_grid_payload,vertex_index+ivec2(0,terrain_grid_rows*band),0);
}
// Shared by the production spatial shader and a real-renderer parity fixture.
// All per-bank tests are uniform across a patch, so the GPU can skip reads.
vec4 terrain_grid_control(ivec2 vertex_index,int bank){
 if((terrain_grid_control_mask & (1<<bank))==0)return vec4(0.0);
 return terrain_grid_value(vertex_index,3+bank);
}
