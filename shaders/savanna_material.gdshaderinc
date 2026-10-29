// Independent Savanna palette; stable source-scale PBR with <=3 active roles.
uniform sampler2DArray savanna_colors:source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2DArray savanna_normals:hint_normal,filter_linear_mipmap_anisotropic,repeat_enable;
uniform float savanna_season=.18;
uniform float savanna_gain=.85;
uniform float savanna_dry_cover=.85;
uniform float savanna_green_cover=.75;
uniform float savanna_red_soil=.6;
uniform float savanna_gravel=.55;
uniform float savanna_rocky_soil=.65;
uniform float savanna_patch=.4;
uniform float savanna_macro=.1;
uniform float savanna_ground_metres=3.0;
uniform float savanna_rock_metres=9.0;
uniform float savanna_normal_strength=.8;
uniform float savanna_rock_normal=.8;
uniform float savanna_path_frequency=.25;
uniform float savanna_path_width=2.5;
uniform float savanna_path_spacing=1000.0;
uniform float savanna_bedrock=.8;
uniform float savanna_rock_macro=.4;
uniform float savanna_rock_gain=.65;
uniform int savanna_quality=3;
int savanna_shared_id(int id){return id==8?6:(id==9?5:1);}
vec4 savanna_texel(int id,vec2 uv,vec2 dx,vec2 dy){
 if(id<8)return textureGrad(savanna_colors,vec3(uv,float(id)),dx,dy);
 return textureGrad(palette_color,vec3(uv,float(savanna_shared_id(id))),dx,dy);
}
vec2 savanna_normal_texel(int id,vec2 uv,vec2 dx,vec2 dy){
 if(id<8)return textureGrad(savanna_normals,vec3(uv,float(id)),dx,dy).rg;
 return textureGrad(palette_normal,vec3(uv,float(savanna_shared_id(id))),dx,dy).rg;
}
vec4 savanna_average(int id){
 if(id<8)return textureLod(savanna_colors,vec3(0,0,float(id)),11.0);
 return textureLod(palette_color,vec3(0,0,float(savanna_shared_id(id))),12.0);
}
void savanna_projected(int id,vec2 uv,vec2 world_uv,vec2 dx,vec2 dy,float fine,out vec4 surface,out vec3 t){
 // Texture phase uses local coordinates + wrapped chunk origin. Only the broad
 // anti-repeat selector uses world UV: no quarter-metre texel quantization at
 // multi-million-metre saved-world starts, and no chunk-local noise resets.
 float k=field(world_uv*.09+vec2(63.7,11.3))*8.0;
 float index=floor(k),blend=smoothstep(.1,.9,fract(k));
 vec2 a=uv+sin(vec2(3,7)*index)*19.0,b=uv+sin(vec2(3,7)*(index+1.0))*19.0;
 surface=mix(savanna_texel(id,a,dx,dy),savanna_texel(id,b,dx,dy),blend);
 t=vec3(0,0,1);
 if(fine>.001){t=normalize(mix(unpack_normal(savanna_normal_texel(id,a,dx,dy)),unpack_normal(savanna_normal_texel(id,b,dx,dy)),blend));t.xy/=max(t.z,.35);}
}
void savanna_sample(int id,float metres,vec3 dx,vec3 dy,vec3 projection,vec3 n,float fine,out vec4 surface,out vec3 gradient){
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
 if(projection.x>.002){vec4 s;vec3 t;savanna_projected(id,vec2(p.z,-p.y*sign(n.x)),vec2(wp.z,-wp.y*sign(n.x)),vec2(dx.z,-dx.y*sign(n.x)),vec2(dy.z,-dy.y*sign(n.x)),fine,s,t);surface+=s*projection.x;gradient+=vec3(0,-t.y*sign(n.x),t.x)*projection.x;}
 if(projection.y>.002){vec4 s;vec3 t;savanna_projected(id,vec2(p.x,-p.z*sign(n.y)),vec2(wp.x,-wp.z*sign(n.y)),vec2(dx.x,-dx.z*sign(n.y)),vec2(dy.x,-dy.z*sign(n.y)),fine,s,t);surface+=s*projection.y;gradient+=vec3(t.x,0,-t.y*sign(n.y))*projection.y;}
 if(projection.z>.002){vec4 s;vec3 t;savanna_projected(id,vec2(p.x,p.y*sign(n.z)),vec2(wp.x,wp.y*sign(n.z)),vec2(dx.x,dx.y*sign(n.z)),vec2(dy.x,dy.y*sign(n.z)),fine,s,t);surface+=s*projection.z;gradient+=vec3(t.x,t.y*sign(n.z),0)*projection.z;}
}

void shade_savanna(vec3 n,vec3 dx,vec3 dy,vec3 projection,float fine,out vec3 color,out float rough,out vec3 gradient,out vec3 materials,out vec3 masks){
 float moisture=clamp(savanna_control.x+savanna_season*.4*(1.0-savanna_surface.x*.5),0.0,1.0);
 float drain=savanna_control.y,slope=1.0-clamp(n.y,0.0,1.0);
 float rock=clamp(savanna_geology.x*savanna_bedrock*(.65+smoothstep(.04,.42,slope)),0.0,1.0);
 float bed=savanna_water.x,basin=savanna_water.y,water=savanna_water.z;
 float exposed=clamp(savanna_surface.y+savanna_surface.z*.45+slope*savanna_rocky_soil,0.0,.8);
 float meso=ground_field(world_position.xz/75.0+vec2(17,93));
 exposed=clamp(exposed+(meso-.5)*savanna_patch*(savanna_geology.y+savanna_surface.z)*.4,0.0,.85);
 float path=0.0;
 if(slope<.2 && water<.4 && savanna_path_frequency>.001){
  vec2 wear=ground_trail(world_position.xz,savanna_path_spacing,savanna_path_width,max(length(dx.xz),length(dy.xz)),1.1);
  float availability=smoothstep(.35,.65,ground_field(world_position.xz/350.0+vec2(71,19)));
  path=(wear.x+wear.y*.2)*savanna_path_frequency*availability*(1.0-smoothstep(.06,.2,slope))*(1.0-water);
 }
 float green=clamp(smoothstep(.25,.8,moisture)*savanna_green_cover,0.0,.9);
 float bare=clamp(exposed+bed*.65+basin*.45+path*.8,0.0,.95)*(1.0-rock);
 float w[11];
 w[0]=(1.0-bare)*(1.0-green)*(1.0-rock)*savanna_dry_cover;
 w[1]=bare*(1.0-savanna_geology.y*.6)*(1.0-bed*.5)*(1.0-basin*.5);
 w[2]=green*(1.0-bare)*(1.0-rock);
 w[3]=bare*savanna_geology.y*savanna_red_soil*(1.0-bed*.6)*(1.0-basin*.6);
 w[4]=(basin*.6+path*.5+savanna_surface.x*exposed*.3)*(1.0-rock)*(1.0-water*.5);
 float layered=smoothstep(.7,.96,savanna_geology.z);
 w[5]=rock*(1.0-layered);w[6]=rock*layered;
 w[7]=basin*(1.0-moisture)*.9*(1.0-rock)*(1.0-water);
 w[8]=(rock*(1.0-rock)*.9+bed*.45+path*.4)*savanna_gravel*(1.0-water*.4);
 w[9]=moisture*(drain*.3+basin*.45+water*.8+path*.25)*(1.0-rock);
 w[10]=bed*.45*(1.0-moisture*.6)*(1.0-rock)*(1.0-basin*.5);
 int ids[3];float selected[3];float total=0.0;
 for(int k=0;k<3;k++){int best=0;for(int j=1;j<11;j++){if(w[j]>w[best])best=j;}ids[k]=best;selected[k]=w[best];w[best]=-1.0;}
 float cutoff=0.0;for(int j=0;j<11;j++)cutoff=max(cutoff,w[j]);
 if(savanna_quality==2)cutoff=max(cutoff,selected[2]);
 for(int k=0;k<3;k++){selected[k]=max(selected[k]-cutoff,0.0);total+=selected[k];}
 if(total<.00001){selected[0]=1.0;total=1.0;}
 color=vec3(0);gradient=vec3(0);rough=0.0;materials=vec3(0);
 for(int k=0;k<3;k++){
  float amount=selected[k]/total;if(amount<.003)continue;int id=ids[k];
  float metres=(id==5 || id==6)?savanna_rock_metres:savanna_ground_metres;
  if(id==8)metres=savanna_ground_metres*.5;
  vec4 s;vec3 g;float distant=smoothstep(70.0,350.0,view_distance);
  if(distant>.999){s=savanna_average(id);g=vec3(0);}else{savanna_sample(id,metres,dx,dy,projection,n,fine,s,g);if(distant>.001)s=mix(s,savanna_average(id),distant);}
  if(id==5 || id==6){
   float macro_fade=1.0-smoothstep(1200.0,6500.0,view_distance);
   if(macro_fade>.001 && savanna_rock_macro>.001){vec4 ms;vec3 mg;savanna_sample(id,savanna_rock_metres*6.0,dx,dy,projection,n,macro_fade,ms,mg);s.rgb=mix(s.rgb,ms.rgb,savanna_rock_macro*macro_fade);g+=mg*savanna_rock_macro*macro_fade;}
   s.rgb*=savanna_rock_gain;
  }
  color+=s.rgb*amount;rough+=s.a*amount;gradient+=g*amount*((id==5 || id==6)?savanna_rock_normal:savanna_normal_strength);
  materials+=id_color(id)*amount;
 }
 float macro=1.0+(moisture-.4)*savanna_macro-(savanna_surface.x-.5)*savanna_macro*.4;
 color*=savanna_gain*macro*mix(1.0,.78,moisture*savanna_season*.5);rough=clamp(rough-moisture*water*.16,.45,.98);gradient-=n*dot(n,gradient);
 if(debug_view==7 || diagnostic_surface==2)gradient=vec3(0);
 masks=vec3(rock,bare,path);
}
vec3 savanna_debug(vec3 n,vec3 mapped,vec3 materials,vec3 masks){
 vec3 result=.5+.42*cos(vec3(0,2.1,4.2)+savanna_geology.z*12.0*2.4);
 if(debug_view==121)result=vec3(clamp(world_position.y/1000.0,0.0,1.0));
 if(debug_view==122)result=vec3(1.0-n.y);if(debug_view==123)result=vec3(masks.x);if(debug_view==124)result=vec3(masks.y);
 if(debug_view==125)result=vec3(savanna_surface.x);if(debug_view==126)result=vec3(savanna_control.x+savanna_season*.4);
 if(debug_view==127)result=vec3(savanna_control.y);if(debug_view==128)result=vec3(savanna_water.x*(1.0-savanna_water.z));
 if(debug_view==129)result=vec3(savanna_water.y);if(debug_view==130)result=materials;
 if(debug_view==131)result=vec3(savanna_control.x,savanna_geology.y,savanna_surface.x);if(debug_view==132)result=vec3(masks.z);if(debug_view==133)result=mapped*.5+.5;
 return result*savanna_control.z;
}
