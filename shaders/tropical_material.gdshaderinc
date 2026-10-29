// Dedicated open-tropical palette. Existing CC0 PBR arrays are shared, not duplicated.
uniform float tropical_lush=.8;
uniform float tropical_red_soil=.65;
uniform float tropical_rock_exposure=.7;
uniform float tropical_wetness=.65;
uniform float tropical_weathering=.5;
uniform float tropical_macro=.16;
uniform float tropical_patches=.4;
uniform float tropical_paths=.3;
uniform float tropical_ground_metres=2.0;
uniform float tropical_rock_metres=6.0;
uniform float tropical_normal_strength=.8;
uniform float tropical_gain=.7;
uniform int tropical_quality=3;
vec4 tropical_texel(int id,vec2 uv,vec2 dx,vec2 dy){
 if(id<3)return textureGrad(savanna_colors,vec3(uv,id==0?2.0:(id==1?1.0:3.0)),dx,dy);
 if(id==3 || id==6)return textureGrad(jungle_colors,vec3(uv,id==3?1.0:5.0),dx,dy);
 if(id==4)return textureGrad(swamp_colors,vec3(uv,1.0),dx,dy);
 return textureGrad(mountain_colors,vec3(uv,id==5?0.0:1.0),dx,dy);
}
vec2 tropical_normal_texel(int id,vec2 uv,vec2 dx,vec2 dy){
 if(id<3)return textureGrad(savanna_normals,vec3(uv,id==0?2.0:(id==1?1.0:3.0)),dx,dy).rg;
 if(id==3 || id==6)return textureGrad(jungle_normals,vec3(uv,id==3?1.0:5.0),dx,dy).rg;
 if(id==4)return textureGrad(swamp_normals,vec3(uv,1.0),dx,dy).rg;
 return textureGrad(mountain_normals,vec3(uv,id==5?0.0:1.0),dx,dy).rg;
}
vec4 tropical_average(int id){
 if(id<3)return textureLod(savanna_colors,vec3(.5,.5,id==0?2.0:(id==1?1.0:3.0)),11.0);
 if(id==3 || id==6)return textureLod(jungle_colors,vec3(.5,.5,id==3?1.0:5.0),11.0);
 if(id==4)return textureLod(swamp_colors,vec3(.5,.5,1.0),11.0);
 return textureLod(mountain_colors,vec3(.5,.5,id==5?0.0:1.0),11.0);
}
void tropical_projected(int id,vec2 uv,vec2 world_uv,vec2 dx,vec2 dy,float fine,out vec4 s,out vec3 t){
 float k=field(world_uv*.09+vec2(19.3,67.1))*8.0,index=floor(k),blend=smoothstep(.1,.9,fract(k));
 vec2 a=uv+sin(vec2(3,7)*index)*19.0,b=uv+sin(vec2(3,7)*(index+1.0))*19.0;
 s=mix(tropical_texel(id,a,dx,dy),tropical_texel(id,b,dx,dy),blend);t=vec3(0,0,1);
 if(fine>.001){t=normalize(mix(unpack_normal(tropical_normal_texel(id,a,dx,dy)),unpack_normal(tropical_normal_texel(id,b,dx,dy)),blend));t.xy/=max(t.z,.35);}
}
void tropical_sample(int id,float metres,vec3 dx,vec3 dy,vec3 projection,vec3 n,float fine,out vec4 surface,out vec3 gradient){
 metres=max(round(metres*4.0)*.25,.25);int period=int(round(metres*4.0));
 ivec3 q=ivec3(round(forest_origin*4.0)),r=abs(q)%ivec3(period);
 if(q.x<0 && r.x>0)r.x=period-r.x;
 if(q.y<0 && r.y>0)r.y=period-r.y;
 if(q.z<0 && r.z>0)r.z=period-r.z;
 vec3 p=forest_local_position/metres+vec3(r)*.25/metres,wp=world_position/metres;dx/=metres;dy/=metres;
 surface=vec4(0);gradient=vec3(0);
 if(projection.x>.002){vec4 s;vec3 t;tropical_projected(id,vec2(p.z,-p.y*sign(n.x)),vec2(wp.z,-wp.y*sign(n.x)),vec2(dx.z,-dx.y*sign(n.x)),vec2(dy.z,-dy.y*sign(n.x)),fine,s,t);surface+=s*projection.x;gradient+=vec3(0,-t.y*sign(n.x),t.x)*projection.x;}
 if(projection.y>.002){vec4 s;vec3 t;tropical_projected(id,vec2(p.x,-p.z*sign(n.y)),vec2(wp.x,-wp.z*sign(n.y)),vec2(dx.x,-dx.z*sign(n.y)),vec2(dy.x,-dy.z*sign(n.y)),fine,s,t);surface+=s*projection.y;gradient+=vec3(t.x,0,-t.y*sign(n.y))*projection.y;}
 if(projection.z>.002){vec4 s;vec3 t;tropical_projected(id,vec2(p.x,p.y*sign(n.z)),vec2(wp.x,wp.y*sign(n.z)),vec2(dx.x,dx.y*sign(n.z)),vec2(dy.x,dy.y*sign(n.z)),fine,s,t);surface+=s*projection.z;gradient+=vec3(t.x,t.y*sign(n.z),0)*projection.z;}
}
void shade_tropical(vec3 n,vec3 dx,vec3 dy,vec3 projection,float fine,out vec3 color,out float rough,out vec3 gradient,out vec3 materials,out vec3 masks){
 float slope=1.0-clamp(n.y,0.0,1.0),region=tropical_control.z*15.0;
 float volcanic=1.0-smoothstep(.5,1.5,abs(region-9.0)),lime=1.0-smoothstep(.5,1.5,abs(region-10.0));
 float rocky=clamp((1.0-smoothstep(.5,1.8,abs(region-4.0)))+volcanic*.5+lime*.7,0.0,1.0);
 float relative=world_position.y-swamp_water_level;
 float bank=1.0-smoothstep(.5,3.0,abs(relative));
 float wet=clamp(tropical_control.y*tropical_wetness+bank*.45,0.0,1.0);
 float rock=clamp((smoothstep(.055,.4,slope)*.8+geology_control.x*.8+rocky*.15-geology_control.z*.15)*tropical_rock_exposure,0.0,1.0);
 float meso=ground_field(world_position.xz/95.0+vec2(31,79));
 float bare=clamp(.08+slope*.9+geology_control.y*.6+volcanic*.22+(meso-.4)*tropical_patches*(.3+slope+geology_control.y)+bank*.7,0.0,.9);
 float path=0.0;
 if(n.y>.94 && relative>2.0 && tropical_paths>.001){vec2 trail=ground_trail(world_position.xz,1100.0,2.0,max(length(dx.xz),length(dy.xz)),1.3);path=(trail.x+trail.y*.12)*tropical_paths*(1.0-smoothstep(.03,.12,slope))*(1.0-bank);}
 bare=clamp(bare+path*.8,0.0,1.0);
 float red=tropical_red_soil*clamp(volcanic+slope*.7+(1.0-smoothstep(.5,1.7,abs(region-15.0)))*.5,0.0,1.0);
 float w[8];
 w[0]=(1.0-rock)*(1.0-bare)*tropical_lush;
 w[1]=(1.0-rock)*bare*(1.0-red)*(1.0-wet*.5);
 w[2]=(1.0-rock)*bare*red;
 w[3]=(1.0-rock)*(bare*.4+path*.3)*wet;
 float alluvial=clamp((1.0-smoothstep(.5,1.7,abs(region-6.0)))+(1.0-smoothstep(.5,1.7,abs(region-8.0))),0.0,1.0);
 w[4]=bank*(1.0-rock)*(.18+alluvial*.4);
 w[5]=rock*(1.0-wet*tropical_weathering);
 w[6]=rock*wet*tropical_weathering;
 w[7]=(rock*(1.0-rock)*.55+bank*.2+path*.35)*(1.0-wet*.4);
 int ids[3];float selected[3],total=0.0;
 for(int k=0;k<3;k++){int best=0;for(int j=1;j<8;j++){if(w[j]>w[best])best=j;}ids[k]=best;selected[k]=w[best];w[best]=-1.0;}
 float cutoff=0.0;for(int j=0;j<8;j++)cutoff=max(cutoff,w[j]);
 for(int k=0;k<3;k++){selected[k]=k>=tropical_quality?0.0:max(selected[k]-cutoff,0.0);total+=selected[k];}
 if(total<.00001){selected[0]=1.0;total=1.0;}
 color=vec3(0);rough=0.0;gradient=vec3(0);materials=vec3(0);
 for(int k=0;k<3;k++){
  float amount=selected[k]/total;if(amount<.003)continue;
  int id=ids[k];bool bedrock=id==5 || id==6;float metres=bedrock?tropical_rock_metres:tropical_ground_metres;
  vec4 s=tropical_average(id);vec3 g=vec3(0);
  float detail=1.0-smoothstep(bedrock?1200.0:150.0,bedrock?5000.0:750.0,view_distance);
  if(detail>.003){vec4 sampled;tropical_sample(id,metres,dx,dy,projection,n,fine,sampled,g);s=mix(s,sampled,detail);g*=detail;}
  if(bedrock){float macro=1.0-smoothstep(6000.0,18000.0,view_distance);if(macro>.003){vec4 big;vec3 ignored;tropical_sample(id,metres*12.0,dx,dy,projection,n,0.0,big,ignored);s=mix(s,big,macro*.25);}s.rgb*=mix(vec3(1.0),vec3(.6,.64,.62),volcanic*.65);s.rgb=mix(s.rgb,s.rgb*vec3(1.2,1.17,1.04),lime*.5);}
  s.rgb*=tropical_gain*(1.0-wet*.14);s.a=mix(s.a,max(.48,s.a*.8),wet*.6);
  color+=s.rgb*amount;rough+=s.a*amount;gradient+=g*amount*tropical_normal_strength;materials+=id_color(id)*amount;
 }
 if(tropical_normal_strength>.001 && rock>.25 && enable_ambient_cliff_normals && fine>.001){vec3 a,b,ai,bi;float ac,bc;ambient_band(true,dx,dy,n,projection,a,ac,ai);ambient_band(false,dx,dy,n,projection,b,bc,bi);gradient+=(a*.25+b*.3)*rock*tropical_normal_strength;}
 color*=1.0+tropical_macro*(wet*.25-slope*.2+(meso-.5)*.2);rough=clamp(rough,.48,1.0);masks=vec3(rock,wet,path);
}
vec3 tropical_debug(vec3 n,vec3 mapped,vec3 materials,vec3 masks){
 if(debug_view==220)return id_color(int(round(tropical_control.z*15.0)));
 if(debug_view==221)return vec3(tropical_control.x);
 if(debug_view==222)return vec3(tropical_control.y);
 if(debug_view==223)return vec3(clamp(world_position.y/1400.0,0.0,1.0));
 if(debug_view==224)return vec3(1.0-n.y);
 if(debug_view==225)return vec3(masks.x);
 if(debug_view==226)return vec3(masks.y,clamp((swamp_water_level-world_position.y)/8.0,0.0,1.0),masks.z);
 if(debug_view==227)return materials;
 if(debug_view==228)return mapped*.5+.5;
 return id_color(int(chunk_lod));
}
