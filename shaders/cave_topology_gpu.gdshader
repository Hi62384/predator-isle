shader_type canvas_item;
render_mode unshaded, blend_disabled;
// The intermediate RGBA8 texture is exact IEEE-754 SDF bytes. Read it
// directly on the GPU; only packed tetrahedron cases cross back to CPU.
uniform sampler2D lattice_values : filter_nearest, repeat_disable;
uniform int lattice_row=33;
uniform int sample_columns=256;
uniform int sample_count=0;

float scalar_at(int i){
 vec4 rgba=texelFetch(lattice_values,ivec2(i%sample_columns,i/sample_columns),0);
 uvec4 b=uvec4(round(rgba*255.0));
 return uintBitsToFloat(b.x|(b.y<<8u)|(b.z<<16u)|(b.w<<24u));
}
vec4 numeric_bytes(float value){
 uint bits=floatBitsToUint(value);
 return vec4(float(bits&255u),float((bits>>8u)&255u),float((bits>>16u)&255u),float((bits>>24u)&255u))/255.0;
}
int tetra(int mask,ivec4 corners){
 return ((mask>>corners.x)&1)|(((mask>>corners.y)&1)<<1)|
        (((mask>>corners.z)&1)<<2)|(((mask>>corners.w)&1)<<3);
}
float cases_at(int index){
 int n=lattice_row-1;
 ivec3 c=ivec3(index%n,index/n%n,index/(n*n));
 // Force exact CPU boundary/frontier values, irrespective of GPU precision.
 if(any(equal(c,ivec3(0)))||any(equal(c,ivec3(n-1))))return 16777216.0;
 int row=lattice_row,plane=row*row,start=c.x+row*c.y+plane*c.z;
 int offsets[8]=int[](0,1,1+row,row,plane,1+plane,1+row+plane,row+plane);
 int mask=0;
 for(int i=0;i<8;i++){
  float v=scalar_at(start+offsets[i]);
  if(v==5.0||abs(v)<=.25||!(v>=-1000000.0&&v<=1000000.0))return 16777216.0;
  if(v<0.0)mask|=1<<i;
 }
 int packed=tetra(mask,ivec4(0,5,1,6))|
  (tetra(mask,ivec4(0,1,2,6))<<4)|(tetra(mask,ivec4(0,2,3,6))<<8)|
  (tetra(mask,ivec4(0,3,7,6))<<12)|(tetra(mask,ivec4(0,7,4,6))<<16)|
  (tetra(mask,ivec4(0,4,5,6))<<20);
 return float(packed);
}
void fragment(){
 ivec2 p=ivec2(FRAGCOORD.xy);
 int index=p.x+p.y*sample_columns;
 COLOR=numeric_bytes(index<sample_count?cases_at(index):0.0);
}
