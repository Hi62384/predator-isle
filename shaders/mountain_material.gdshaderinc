// Mountain-specific source selection; shared scans are not duplicated in new arrays.
uniform sampler2DArray mountain_colors:source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2DArray mountain_normals:hint_normal,filter_linear_mipmap_anisotropic,repeat_enable;
uniform float mountain_rock_exposure=.85;
uniform float mountain_geology_variation=.6;
uniform float mountain_soil=.55;
uniform float mountain_alpine=.65;
uniform float mountain_wetness=.6;
uniform float mountain_rock_metres=5.0;
uniform float mountain_ground_metres=2.0;
uniform float mountain_normal_strength=.8;
uniform float mountain_macro_strength=.38;
uniform float mountain_meso_strength=.45;
uniform float mountain_gain=.45;
uniform float mountain_paths=.1;
uniform float mountain_scree_cover=.75;
uniform int mountain_quality=3;
int mountain_local_id(int id){return id==0?0:(id==3?2:1);}
int mountain_savanna_id(int id){return id==1?6:(id==2?5:(id==5?1:4));}
vec4 mountain_texel(int id,vec2 uv,vec2 dx,vec2 dy){
 if(id==0 || id==3 || id==4)return textureGrad(mountain_colors,vec3(uv,float(mountain_local_id(id))),dx,dy);
 if(id==6 || id==7)return textureGrad(jungle_colors,vec3(uv,id==6?1.0:5.0),dx,dy);
 return textureGrad(savanna_colors,vec3(uv,float(mountain_savanna_id(id))),dx,dy);
}
vec2 mountain_normal_texel(int id,vec2 uv,vec2 dx,vec2 dy){
 if(id==0 || id==3 || id==4)return textureGrad(mountain_normals,vec3(uv,float(mountain_local_id(id))),dx,dy).rg;
 if(id==6 || id==7)return textureGrad(jungle_normals,vec3(uv,id==6?1.0:5.0),dx,dy).rg;
 return textureGrad(savanna_normals,vec3(uv,float(mountain_savanna_id(id))),dx,dy).rg;
}
vec4 mountain_average(int id){
 if(id==0 || id==3 || id==4)return textureLod(mountain_colors,vec3(.5,.5,float(mountain_local_id(id))),8.0);
 if(id==6 || id==7)return textureLod(jungle_colors,vec3(.5,.5,id==6?1.0:5.0),8.0);
 return textureLod(savanna_colors,vec3(.5,.5,float(mountain_savanna_id(id))),8.0);
}
void mountain_projected(int id,vec2 uv,vec2 world_uv,vec2 dx,vec2 dy,float fine,out vec4 surface,out vec3 t){
 // Texture phase uses local coordinates + wrapped chunk origin. Only the broad
 // anti-repeat selector uses world UV: no quarter-metre texel quantization at
 // multi-million-metre saved-world starts, and no chunk-local noise resets.
 float k=field(world_uv*.09+vec2(63.7,11.3))*8.0;
 float index=floor(k),blend=smoothstep(.1,.9,fract(k));
 vec2 a=uv+sin(vec2(3,7)*index)*19.0,b=uv+sin(vec2(3,7)*(index+1.0))*19.0;
 surface=mix(mountain_texel(id,a,dx,dy),mountain_texel(id,b,dx,dy),blend);
 t=vec3(0,0,1);
 if(fine>.001){t=normalize(mix(unpack_normal(mountain_normal_texel(id,a,dx,dy)),unpack_normal(mountain_normal_texel(id,b,dx,dy)),blend));t.xy/=max(t.z,.35);}
}
void mountain_sample(int id,float metres,vec3 dx,vec3 dy,vec3 projection,vec3 n,float fine,out vec4 surface,out vec3 gradient){
 // Quarter-metre repeats keep the origin remainder exactly representable at
 // the saved world's multi-million-metre integer chunk coordinates.
 metres=max(round(metres*4.0)*.25,.25);
 int quarter_period=int(round(metres*4.0));
 ivec3 q=ivec3(round(forest_origin*4.0));
 ivec3 period=ivec3(quarter_period);
 // GLSL signed remainder is not portable for negative operands. Divide only
 // positive magnitudes, then reflect the phase explicitly on negative axes.
 ivec3 r=abs(q)%period;
 if(q.x<0 && r.x>0)r.x=quarter_period-r.x;
 if(q.y<0 && r.y>0)r.y=quarter_period-r.y;
 if(q.z<0 && r.z>0)r.z=quarter_period-r.z;
 vec3 remainder=vec3(r)*.25;
 vec3 p=forest_local_position/metres+remainder/metres;
 vec3 wp=world_position/metres;dx/=metres;dy/=metres;
 surface=vec4(0);gradient=vec3(0);
 if(projection.x>.002){vec4 s;vec3 t;mountain_projected(id,vec2(p.z,-p.y*sign(n.x)),vec2(wp.z,-wp.y*sign(n.x)),vec2(dx.z,-dx.y*sign(n.x)),vec2(dy.z,-dy.y*sign(n.x)),fine,s,t);surface+=s*projection.x;gradient+=vec3(0,-t.y*sign(n.x),t.x)*projection.x;}
 if(projection.y>.002){vec4 s;vec3 t;mountain_projected(id,vec2(p.x,-p.z*sign(n.y)),vec2(wp.x,-wp.z*sign(n.y)),vec2(dx.x,-dx.z*sign(n.y)),vec2(dy.x,-dy.z*sign(n.y)),fine,s,t);surface+=s*projection.y;gradient+=vec3(t.x,0,-t.y*sign(n.y))*projection.y;}
 if(projection.z>.002){vec4 s;vec3 t;mountain_projected(id,vec2(p.x,p.y*sign(n.z)),vec2(wp.x,wp.y*sign(n.z)),vec2(dx.x,dx.y*sign(n.z)),vec2(dy.x,dy.y*sign(n.z)),fine,s,t);surface+=s*projection.z;gradient+=vec3(t.x,t.y*sign(n.z),0)*projection.z;}
}


void shade_mountain(vec3 n,vec3 dx,vec3 dy,vec3 projection,float fine,out vec3 color,out float rough,out vec3 gradient,out vec3 materials,out vec3 overlays){
 float slope=1.0-clamp(n.y,0.0,1.0);
 float ridge=mountain_shape.x,valley=mountain_geology.z;
 float rock=clamp(mountain_control.x*mountain_rock_exposure*.7+smoothstep(.08,.5,slope)*.7+ridge*.15-valley*.15,0.0,1.0);
 float scree=mountain_control.y*mountain_scree_cover*(1.0-smoothstep(.4,.7,slope))*(1.0-rock*.5);
 float relative=world_position.y-swamp_water_level;
 float wet=clamp(mountain_wet*mountain_wetness+(1.0-smoothstep(0.0,4.0,abs(relative)))*.6,0.0,1.0);
 float region=mountain_geology.x*15.0;
 float layered=clamp((1.0-smoothstep(.5,1.8,abs(region-6.0)))+(1.0-smoothstep(.5,1.4,abs(region-11.0))),0.0,1.0)*mountain_geology_variation;
 float granite=1.0-smoothstep(.5,1.7,abs(region-5.0));
 float meadow=mountain_alpine*valley*(1.0-rock)*(1.0-scree)*(1.0-smoothstep(1700.0,2400.0,world_position.y));
 float path=0.0;
 if(n.y>.92 && relative>1.0 && mountain_paths>.001){
  vec2 wear=ground_trail(world_position.xz,900.0,1.5,max(length(dx.xz),length(dy.xz)),1.5);
  path=(wear.x+wear.y*.12)*mountain_paths*valley;
 }
 float w[9];
 w[0]=rock*(1.0-layered)*(1.0-granite*.7);
 w[1]=rock*layered;w[2]=rock*granite*.7;
 w[3]=scree*(.4+mountain_geology.y*.5);w[4]=scree*(.6+mountain_shape.z*.4)+path*.4;
 w[5]=meadow;
 w[6]=mountain_soil*(1.0-rock)*(1.0-scree)*(.25+valley*.5)+path*.4;
 w[7]=wet*rock*valley*.3;
 w[8]=wet*valley*(1.0-rock)*.25;
 int ids[3];float selected[3];float total=0.0;
 for(int k=0;k<3;k++){int best=0;for(int j=1;j<9;j++){if(w[j]>w[best])best=j;}ids[k]=best;selected[k]=w[best];w[best]=-1.0;}
 float cutoff=0.0;for(int j=0;j<9;j++)cutoff=max(cutoff,w[j]);
 for(int k=0;k<3;k++){selected[k]=k>=mountain_quality?0.0:max(selected[k]-cutoff,0.0);total+=selected[k];}
 if(total<.00001){selected[0]=1.0;total=1.0;}
 color=vec3(0);rough=0.0;gradient=vec3(0);materials=vec3(0);overlays=vec3(0);
 for(int k=0;k<3;k++){
  float amount=selected[k]/total;if(amount<.003)continue;
  int id=ids[k];bool bedrock=id<3 || id==7;
  float metres=bedrock?mountain_rock_metres:mountain_ground_metres;
  if(id==3)metres*=.8;
  vec4 s=mountain_average(id);vec3 g=vec3(0);
  float detail=1.0-smoothstep(bedrock?1200.0:120.0,bedrock?5000.0:650.0,view_distance);
  if(detail>.003){vec4 sampled;mountain_sample(id,metres,dx,dy,projection,n,fine,sampled,g);s=mix(s,sampled,detail);g*=detail;}
  if(bedrock){
  float macro=1.0-smoothstep(6000.0,18000.0,view_distance);
   if(macro>.003){vec4 big;vec3 ignored;mountain_sample(id,metres*12.0,dx,dy,projection,n,0.0,big,ignored);s=mix(s,big,macro*.28);}
  }
  s.rgb*=mountain_gain*(1.0-wet*.18);
  s.a=mix(s.a,max(.3,s.a*.65),wet*.6);
  color+=s.rgb*amount;rough+=s.a*amount;gradient+=g*amount*mountain_normal_strength;
  materials+=id_color(id)*amount;
 }
 if(debug_view!=7 && debug_view!=18 && mountain_normal_strength>.001 && rock>.25 && enable_ambient_cliff_normals && diagnostic_surface!=2){
  vec3 macro_g,meso_g,macro_ids,meso_ids;float macro_c,meso_c;
  ambient_band(true,dx,dy,n,projection,macro_g,macro_c,macro_ids);
  ambient_band(false,dx,dy,n,projection,meso_g,meso_c,meso_ids);
  gradient+=(macro_g*mountain_macro_strength+meso_g*mountain_meso_strength)*rock*mountain_normal_strength;
  overlays=vec3(macro_c,meso_c,0);
 }
 color*=1.0+mountain_geology_variation*(mountain_shape.z*.08-ridge*.035+valley*.035);
 rough=clamp(rough,.35,1.0);
}
vec3 mountain_debug(vec3 n,vec3 mapped,vec3 materials,vec3 overlays){
 if(debug_view==160)return id_color(int(round(mountain_geology.x*15.0)));
 if(debug_view==161)return vec3(clamp(world_position.y/3000.0,0.0,1.0));
 if(debug_view==162)return vec3(mountain_shape.x);
 if(debug_view==163)return vec3(mountain_shape.y);
 if(debug_view==164)return vec3(mountain_shape.x*(1.0-mountain_shape.y));
 if(debug_view==165)return vec3(mountain_geology.z);
 if(debug_view==166)return vec3(mountain_geology.y);
 if(debug_view==167)return vec3(smoothstep(.12,.5,1.0-n.y));
 if(debug_view==168)return vec3(mountain_control.x);
 if(debug_view==169)return vec3(mountain_control.y);
 if(debug_view==170)return vec3(mountain_geology.x);
 if(debug_view==171)return vec3(mountain_shape.z);
 if(debug_view==172)return vec3(mountain_wet,clamp((swamp_water_level-world_position.y)/8.0,0.0,1.0),0);
 if(debug_view==173)return materials;
 if(debug_view==174)return mapped*.5+.5;
 if(debug_view==175)return id_color(int(chunk_lod));
 if(debug_view==176){vec2 e=min(forest_local_position.xz,vec2(chunk_size_metres)-forest_local_position.xz);return vec3(1.0-smoothstep(0.0,2.0,min(e.x,e.y)));}
 return overlays;
}
