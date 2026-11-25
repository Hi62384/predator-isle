shader_type canvas_item;
render_mode unshaded, blend_disabled;
#include "res://shaders/grassland_gpu_noise.gdshaderinc"
// Positions are already frequency-scaled and skewed using the canonical
// float arithmetic. Split seeds into exact uint16 words, never NaN bitcasts.
uniform sampler2D numeric_inputs : filter_nearest, repeat_disable;
uniform int sample_count=0;
uniform int sample_columns=256;
uniform int sample_rows=2;

vec4 numeric_bytes(float value){
 uint bits=floatBitsToUint(value);
 return vec4(float(bits&255u),float((bits>>8u)&255u),float((bits>>16u)&255u),float((bits>>24u)&255u))/255.0;
}
void fragment(){
 ivec2 pixel=ivec2(FRAGCOORD.xy);
 int index=pixel.y*sample_columns+pixel.x;
 if(index>=sample_count){COLOR=numeric_bytes(0.0);}
 else{
  vec4 p=texelFetch(numeric_inputs,pixel,0);
  vec4 cfg=texelFetch(numeric_inputs,pixel+ivec2(0,sample_rows),0);
  int seed=int(uint(p.z)|(uint(p.w)<<16u));
  float value=0.0,amplitude=cfg.z,x=p.x,z=p.y;
  for(int octave=0;octave<8;octave++){
   if(octave>=int(cfg.w))break;
   value+=grass_noise_simplex(seed,x,z)*amplitude;
   seed++;x*=cfg.y;z*=cfg.y;amplitude*=cfg.x;
  }
  COLOR=numeric_bytes(value);
 }
}
