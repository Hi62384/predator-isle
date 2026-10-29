// Real source PBR, at most three active roles per pixel.
uniform sampler2DArray swamp_colors:source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2DArray swamp_normals:hint_normal,filter_linear_mipmap_anisotropic,repeat_enable;
uniform float swamp_mud=.8;
uniform float swamp_peat=.7;
uniform float swamp_organic=.8;
uniform float swamp_sediment=.65;
uniform float swamp_wetness=.9;
uniform float swamp_macro=.12;
uniform float swamp_shore_width=1.2;
uniform float swamp_metres=2.0;
uniform float swamp_normal_strength=.65;
uniform float swamp_gain=.9;
uniform float swamp_exposed_season=.35;
uniform float swamp_paths=.15;
uniform float swamp_flood_stage=0.0;
uniform int swamp_quality=3;
int swamp_shared_id(int id){return id==3?1:(id==4?2:(id==5?3:4));}
vec4 swamp_texel(int id,vec2 uv,vec2 dx,vec2 dy){
 if(id<3)return textureGrad(swamp_colors,vec3(uv,float(id)),dx,dy);
 return textureGrad(jungle_colors,vec3(uv,float(swamp_shared_id(id))),dx,dy);
}
vec2 swamp_normal_texel(int id,vec2 uv,vec2 dx,vec2 dy){
 if(id<3)return textureGrad(swamp_normals,vec3(uv,float(id)),dx,dy).rg;
 return textureGrad(jungle_normals,vec3(uv,float(swamp_shared_id(id))),dx,dy).rg;
}
vec4 swamp_average(int id){
 if(id<3)return textureLod(swamp_colors,vec3(0,0,float(id)),11.0);
 return textureLod(jungle_colors,vec3(0,0,float(swamp_shared_id(id))),11.0);
}
void swamp_projected(int id,vec2 uv,vec2 world_uv,vec2 dx,vec2 dy,float fine,out vec4 surface,out vec3 t){
 // Texture phase uses local coordinates + wrapped chunk origin. Only the broad
 // anti-repeat selector uses world UV: no quarter-metre texel quantization at
 // multi-million-metre saved-world starts, and no chunk-local noise resets.
 float k=field(world_uv*.09+vec2(63.7,11.3))*8.0;
 float index=floor(k),blend=smoothstep(.1,.9,fract(k));
 vec2 a=uv+sin(vec2(3,7)*index)*19.0,b=uv+sin(vec2(3,7)*(index+1.0))*19.0;
 surface=mix(swamp_texel(id,a,dx,dy),swamp_texel(id,b,dx,dy),blend);
 t=vec3(0,0,1);
 if(fine>.001){t=normalize(mix(unpack_normal(swamp_normal_texel(id,a,dx,dy)),unpack_normal(swamp_normal_texel(id,b,dx,dy)),blend));t.xy/=max(t.z,.35);}
}
void swamp_sample(int id,float metres,vec3 dx,vec3 dy,vec3 projection,vec3 n,float fine,out vec4 surface,out vec3 gradient){
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
 if(projection.x>.002){vec4 s;vec3 t;swamp_projected(id,vec2(p.z,-p.y*sign(n.x)),vec2(wp.z,-wp.y*sign(n.x)),vec2(dx.z,-dx.y*sign(n.x)),vec2(dy.z,-dy.y*sign(n.x)),fine,s,t);surface+=s*projection.x;gradient+=vec3(0,-t.y*sign(n.x),t.x)*projection.x;}
 if(projection.y>.002){vec4 s;vec3 t;swamp_projected(id,vec2(p.x,-p.z*sign(n.y)),vec2(wp.x,-wp.z*sign(n.y)),vec2(dx.x,-dx.z*sign(n.y)),vec2(dy.x,-dy.z*sign(n.y)),fine,s,t);surface+=s*projection.y;gradient+=vec3(t.x,0,-t.y*sign(n.y))*projection.y;}
 if(projection.z>.002){vec4 s;vec3 t;swamp_projected(id,vec2(p.x,p.y*sign(n.z)),vec2(wp.x,wp.y*sign(n.z)),vec2(dx.x,dx.y*sign(n.z)),vec2(dy.x,dy.y*sign(n.z)),fine,s,t);surface+=s*projection.z;gradient+=vec3(t.x,t.y*sign(n.z),0)*projection.z;}
}


void shade_swamp(vec3 n,vec3 dx,vec3 dy,vec3 projection,float fine,out vec3 color,out float rough,out vec3 gradient,out vec3 materials,out vec3 masks){
 float relative=world_position.y-swamp_water_level-swamp_flood_stage*swamp_control.z;
 float wet=clamp(max(swamp_control.x,1.0-smoothstep(-.2,swamp_shore_width*2.0,relative))*swamp_wetness,0.0,1.0);
 float submerged=1.0-smoothstep(-.15,.15,relative);
 float shore=1.0-smoothstep(0.0,swamp_shore_width,abs(relative));
 float sediment=clamp(swamp_hydro.x*swamp_sediment+swamp_hydro.y*.35,0.0,.95);
 float peat=swamp_control.y*swamp_peat*(1.0-sediment*.6);
 float rock=clamp(swamp_land.z+smoothstep(.15,.5,1.0-n.y)*swamp_land.z,0.0,1.0);
 float path=0.0;
 if(relative>.3 && n.y>.94 && swamp_paths>.001){
  vec2 wear=ground_trail(world_position.xz,600.0,1.8,max(length(dx.xz),length(dy.xz)),1.4);
  path=(wear.x+wear.y*.12)*swamp_paths*smoothstep(.3,1.1,relative);
 }
 float w[7];
 w[0]=swamp_mud*(wet*.65+shore*.4+swamp_hydro.z*.3)*(1.0-peat)*(1.0-sediment*.65);
 w[1]=sediment*(.4+wet*.6)+submerged*.3;
 w[2]=peat*(.65+wet*.35);
 w[3]=swamp_organic*(1.0-submerged)*(.25+smoothstep(.1,2.0,relative))*(1.0-peat);
 w[4]=swamp_exposed_season*swamp_hydro.z*smoothstep(.4,1.8,relative)*(1.0-wet);
 w[5]=swamp_hydro.y*sediment*(1.0-wet*.7)*.35+rock*.2+path*.2;
 w[6]=rock*1.8;
 w[0]+=path*.6;
 int ids[3];float selected[3];float total=0.0;
 for(int k=0;k<3;k++){int best=0;for(int j=1;j<7;j++){if(w[j]>w[best])best=j;}ids[k]=best;selected[k]=w[best];w[best]=-1.0;}
 float cutoff=0.0;for(int j=0;j<7;j++)cutoff=max(cutoff,w[j]);
 for(int k=0;k<3;k++){if(k>=swamp_quality)selected[k]=0.0;else selected[k]=max(selected[k]-cutoff,0.0);total+=selected[k];}
 if(total<.00001){selected[0]=1.0;total=1.0;}
 color=vec3(0);rough=0.0;gradient=vec3(0);materials=vec3(0);
 for(int k=0;k<3;k++){
  float amount=selected[k]/total;if(amount<.003)continue;
  int id=ids[k];float metres=swamp_metres*(id==6?3.0:(id==5?.6:1.0));
  vec4 s=swamp_average(id);vec3 g=vec3(0);
  float detail=1.0-smoothstep(100.0,500.0,view_distance);
  if(detail>.003){vec4 near_s;swamp_sample(id,metres,dx,dy,projection,n,fine,near_s,g);s=mix(s,near_s,detail);g*=detail;}
  // Source textures retain structure; wetness alters their response, not a uniform gloss.
  float absorption=mix(1.0,.55,wet*(id==6?.45:1.0));
  s.rgb*=absorption*swamp_gain;
  // Decomposed organic scan keeps its own fibrous structure and earthy hue.
  if(id==2)s.rgb*=vec3(.62,.52,.44);
  s.a=mix(s.a,max(.18,s.a*.48),wet*(id==0?.9:(id==1?.75:.5)));
  color+=s.rgb*amount;rough+=s.a*amount;gradient+=g*amount*swamp_normal_strength*(1.0-wet*.25);
  materials+=id_color(id)*amount;
 }
 float broad=1.0+swamp_macro*(swamp_land.x*.25+swamp_land.y*.4-swamp_hydro.z*.3-swamp_control.y*.3);
 color*=broad;rough=clamp(rough,.16,1.0);
 masks=vec3(wet,shore,path);
}
vec3 swamp_debug(vec3 n,vec3 mapped,vec3 materials,vec3 masks){
 float relative=world_position.y-swamp_water_level-swamp_flood_stage*swamp_control.z;
 if(debug_view==140)return id_color(int(round(swamp_ecology.x*14.0)));
 if(debug_view==141)return vec3(clamp(world_position.y/30.0,0.0,1.0));
 if(debug_view==142)return vec3(clamp(swamp_water_level/20.0,0.0,1.0));
 if(debug_view==143)return vec3(clamp(relative*.2+.5,0.0,1.0));
 if(debug_view==144)return vec3(clamp(-relative/5.0,0.0,1.0));
 if(debug_view==145)return vec3(swamp_hydro.y,swamp_hydro.z,swamp_ecology.z);
 if(debug_view==146)return vec3(swamp_hydro.z);
 if(debug_view==147)return vec3(swamp_hydro.y);
 if(debug_view==148)return vec3(swamp_land.x);
 if(debug_view==149)return vec3(masks.x);
 if(debug_view==150)return vec3(masks.x*(1.0-swamp_control.y));
 if(debug_view==151)return vec3(swamp_control.y);
 if(debug_view==152)return vec3(swamp_hydro.x);
 if(debug_view==153)return vec3(masks.y);
 if(debug_view==154)return vec3(swamp_land.y);
 if(debug_view==155)return id_color(int(chunk_lod));
 if(debug_view==156){vec2 e=min(forest_local_position.xz,vec2(chunk_size_metres)-forest_local_position.xz);return vec3(1.0-smoothstep(0.0,2.0,min(e.x,e.y)));}
 if(debug_view==157)return materials;
 if(debug_view==158)return mapped*.5+.5;
 return vec3(masks.z);
}
