// One texel per emitted vertex. No bilinear reconstruction across a collision diagonal.
uniform bool terrain_grid_enabled=false;
uniform sampler2D terrain_grid_payload:filter_nearest,repeat_disable;
uniform int terrain_grid_rows=17;
uniform float terrain_grid_scale=0.3333333333333333;
// Exact +0.0 control banks need no texture fetch. Default 15 preserves
// legacy meshes/materials that do not supply the per-page specialization.
uniform int terrain_grid_control_mask=15;
// Quantized biome ownership can be constant for a complete patch. Preserve
// the legacy layout by default and omit that repeated band only when bound.
uniform bool terrain_grid_color_is_constant=false;
uniform vec4 terrain_grid_constant_color=vec4(0.0);
vec4 terrain_grid_value(ivec2 vertex_index,int band){
 if(terrain_grid_color_is_constant){
  if(band==1)return terrain_grid_constant_color;
  if(band>1)band--;
 }
 return texelFetch(terrain_grid_payload,vertex_index+ivec2(0,terrain_grid_rows*band),0);
}
// Shared by the production spatial shader and a real-renderer parity fixture.
// All per-bank tests are uniform across a patch, so the GPU can skip reads.
vec4 terrain_grid_control(ivec2 vertex_index,int bank){
 if((terrain_grid_control_mask & (1<<bank))==0)return vec4(0.0);
 // Packed RGBA32F pages contain just the active banks after bands 0..2.
 // For legacy seven-band pages, the default mask=15 retains offsets 3..6.
 int offset=3;
 if(bank>=1 && (terrain_grid_control_mask & 1)!=0)offset++;
 if(bank>=2 && (terrain_grid_control_mask & 2)!=0)offset++;
 if(bank>=3 && (terrain_grid_control_mask & 4)!=0)offset++;
 return terrain_grid_value(vertex_index,offset);
}
