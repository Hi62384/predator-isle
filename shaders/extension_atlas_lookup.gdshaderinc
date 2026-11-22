// Universal extension RGBA8 atlas sampler shared between terrain rendering
// and actual GPU parity checks. Strips 0..7 hold original family controls;
// native strips 8..9 encode four family weights per texel.
vec4 extension_texel(int id){
 ivec2 size=textureSize(extension_payload,0);
 float row=float(size.y);
 vec2 grid=clamp(forest_local_position.xz/chunk_size_metres,vec2(0),vec2(1))*(row-1.0);
 return textureLod(extension_payload,
  vec2((float(id)*row+grid.x+.5)/float(size.x),(grid.y+.5)/row),0.0);
}
void extension_weight_banks(out vec4 weights_a,out vec4 weights_b){
 weights_a=vec4(0);weights_b=vec4(0);
 ivec2 size=textureSize(extension_payload,0);
 if(size.x>=size.y*10){
  // Chunks with no active families in a half atlas have exact zero weights
  // there. Skip that full-screen RGBA8 texture fetch; single-family chunks
  // commonly require only one of the two packed weight strips.
  if((extension_active_mask & 15)!=0)weights_a=extension_texel(8);
  if((extension_active_mask & 240)!=0)weights_b=extension_texel(9);
 }else{
  // Reference/legacy atlases: eight family strips plus optional palette.
  for(int i=0;i<8;i++){
   if((extension_active_mask & (1<<i))==0)continue;
   float w=extension_texel(i).x;
   if(i<4)weights_a[i]=w;else weights_b[i-4]=w;
  }
 }
}
