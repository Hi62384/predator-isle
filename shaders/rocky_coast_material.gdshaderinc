// Coastal palette reuses photographed Mountain/Savanna scans, not recolored noise.
uniform float coast_wetness=.85;
uniform float coast_shingle=.75;
uniform float coast_gain=.6;
uniform float coast_rock_metres=5.0;
uniform float coast_normal_strength=.8;
uniform float coast_macro_strength=.5;
uniform float coast_salt=.35;
uniform int coast_quality=3;
void shade_coast(vec3 n,vec3 dx,vec3 dy,vec3 projection,float fine,out vec3 color,out float rough,out vec3 gradient,out vec3 mix_ids){
 float region=coast_control.y*15.0;
 float layered=clamp(1.0-smoothstep(.5,1.5,abs(region-8.0))+1.0-smoothstep(.5,1.5,abs(region)),0.0,1.0);
 float granite=1.0-smoothstep(.5,1.7,abs(region-7.0));
 float dark=1.0-smoothstep(.5,1.7,abs(region-9.0));
 float relative=world_position.y-water_level;
 float exposure=coast_control.z;
 float splash=1.0-smoothstep(1.5+exposure*2.0,4.0+exposure*7.0,relative);
 float wet=clamp(splash*coast_wetness*(.8+coast_sediment*.1),0.0,1.0);
 float sediment=coast_sediment*coast_shingle*(1.0-smoothstep(.1,.4,1.0-n.y));
 float w[5];w[0]=(1.0-layered)*(1.0-granite*.8)*(1.0-sediment);w[1]=layered*(1.0-sediment);w[2]=granite*.8*(1.0-sediment);w[3]=sediment*.6;w[4]=sediment*.4;
 int ids[3];float weights[3];float total=0.0;
 for(int k=0;k<3;k++){int best=0;for(int j=1;j<5;j++){if(w[j]>w[best])best=j;}ids[k]=best;weights[k]=w[best];w[best]=-1.0;}
 float cutoff=0.0;for(int j=0;j<5;j++)cutoff=max(cutoff,w[j]);
 for(int k=0;k<3;k++){weights[k]=k>=coast_quality?0.0:max(weights[k]-cutoff,0.0);total+=weights[k];}
 color=vec3(0);rough=0.0;gradient=vec3(0);mix_ids=vec3(0);
 for(int k=0;k<3;k++){
  float amount=weights[k]/max(total,.00001);if(amount<.003)continue;
  int id=ids[k];float metres=id<3?coast_rock_metres:2.0;
  vec4 s=mountain_average(id);vec3 g=vec3(0);
  float detail=1.0-smoothstep(id<3?700.0:100.0,id<3?4000.0:600.0,view_distance);
  if(detail>.003){vec4 base;mountain_sample(id,metres,dx,dy,projection,n,fine,base,g);s=mix(s,base,detail);g*=detail;}
  if(id<3){vec4 macro;vec3 ignored;mountain_sample(id,metres*18.0,dx,dy,projection,n,0.0,macro,ignored);s=mix(s,macro,coast_macro_strength*(1.0-smoothstep(6000.0,18000.0,view_distance)));}
  s.rgb*=coast_gain*mix(1.0,.48,dark)*(1.0-wet*.28);
  float salt=(1.0-splash)*exp(-max(relative,0.0)/35.0)*exposure*coast_salt;
  s.rgb=mix(s.rgb,s.rgb*1.12,salt);
  color+=s.rgb*amount;rough+=mix(s.a,max(.3,s.a*.62),wet)*amount;gradient+=g*amount*coast_normal_strength;mix_ids+=id_color(id)*amount;
 }
 if(debug_view!=7 && debug_view!=18 && coast_normal_strength>.001 && enable_ambient_cliff_normals && diagnostic_surface!=2){
  vec3 macro_g,meso_g,ids1,ids2;float c1,c2;
  ambient_band(true,dx,dy,n,projection,macro_g,c1,ids1);ambient_band(false,dx,dy,n,projection,meso_g,c2,ids2);
  gradient+=(macro_g*.45+meso_g*.4)*coast_normal_strength*(1.0-sediment*.7);
 }
 rough=clamp(rough,.3,.95);
}
vec3 coast_debug(vec3 n,vec3 mapped,vec3 mixture){
 float mode=float(debug_view-180),relative=world_position.y-water_level;
 if(mode==0.0 || mode==10.0)return id_color(int(round(coast_control.y*15.0)));
 if(mode==1.0)return vec3(coast_control.x);
 if(mode==2.0)return n*.5+.5;
 if(mode==3.0)return vec3(coast_control.z);
 if(mode==4.0)return vec3(smoothstep(.1,.5,1.0-n.y));
 if(mode==5.0)return vec3(clamp(relative/300.0,0.0,1.0));
 if(mode==6.0)return vec3(smoothstep(.1,.6,coast_control.x)*(1.0-smoothstep(40.0,250.0,relative)));
 if(mode==7.0 || mode==14.0)return vec3(coast_sediment);
 if(mode==8.0)return vec3((1.0-smoothstep(1.0,5.0,abs(relative)))*smoothstep(.7,.95,n.y));
 if(mode==9.0)return vec3(clamp(swamp_water_level-world_position.y,0.0,1.0));
 if(mode==11.0)return vec3(1.0-coast_sediment);
 if(mode==12.0)return vec3(1.0-smoothstep(1.0,4.0+coast_control.z*7.0,relative));
 if(mode==13.0)return vec3(1.0-smoothstep(0.0,4.0,abs(relative)));
 if(mode==15.0)return vec3(clamp(-relative/30.0,0.0,1.0));
 if(mode==16.0)return mixture;
 if(mode==17.0)return mapped*.5+.5;
 if(mode==18.0)return id_color(int(chunk_lod));
 vec2 edge=min(forest_local_position.xz,vec2(chunk_size_metres)-forest_local_position.xz);return vec3(1.0-smoothstep(0.0,2.0,min(edge.x,edge.y)));
}
