// Numeric control atlas only, 32 bytes per terrain vertex, no PBR images per tile.
vec4 extension_texel(int id){
 ivec2 size=textureSize(extension_payload,0);float row=float(size.y);
 vec2 grid=clamp(forest_local_position.xz/chunk_size_metres,vec2(0),vec2(1))*(row-1.0);
 vec4 s=textureLod(extension_payload,vec2((float(id)*row+grid.x+.5)/float(size.x),(grid.y+.5)/row),0.0);
 return s;
}
vec3 extension_control(int id){
 vec4 s=extension_texel(id);return clamp(s.yzw/max(s.x,1.0/255.0),vec3(0),vec3(1));
}
#include "res://shaders/biological_sampling.gdshaderinc"
vec3 extension_tint(int family,int type){
 if(family==0)return type==0?vec3(.54,.53,.51):(type==1?vec3(.74,.72,.65):(type==2?vec3(.24,.26,.29):(type==3?vec3(.61,.43,.29):(type==4?vec3(.22,.23,.23):vec3(.47,.44,.39)))));
 if(family==1)return type==0?vec3(.48,.43,.36):(type==1?vec3(.63,.62,.58):(type==2?vec3(.68,.68,.61):vec3(.5,.49,.44)));
 if(family==2)return type==3?vec3(.29,.15,.10):(type==4?vec3(.13,.14,.14):(type==5?vec3(.38,.31,.24):vec3(.22,.23,.23)));
 if(family==3)return type==2?vec3(.65,.62,.50):(type==5?vec3(.55,.5,.39):vec3(.19,.15,.105));
 if(family==4)return type==2?vec3(.21,.24,.21):(type==3?vec3(.43,.28,.16):(type==5?vec3(.67,.63,.5):vec3(.48,.43,.35)));
 if(family==5)return type==1?vec3(.45,.34,.48):(type==2?vec3(.74,.74,.65):(type==3?vec3(.30,.29,.26):(type==4?vec3(.32,.44,.41):vec3(.63,.61,.55))));
 if(family==6)return type==2?vec3(.58,.47,.32):(type==4?vec3(.47,.43,.36):vec3(.46,.26,.13));
 return type==2?vec3(.14,.12,.12):(type==5?vec3(.23,.21,.19):(type==1?vec3(.44,.38,.35):vec3(.24,.12,.11)));
}
void shade_extension(int family,vec3 control,vec3 n,vec3 dx,vec3 dy,vec3 projection,float fine,out vec3 color,out float rough,out vec3 gradient,out vec3 emission){
 float region=control.x*5.0,wet=control.y,feature=control.z,slope=1.0-clamp(n.y,0.0,1.0);
 float spore_light=family==3?smoothstep(.5,.8,feature):0.0;
 if(family==3)feature=clamp(feature*2.0,0.0,1.0);
 int type=int(clamp(floor(region+.5),0.0,5.0));int ground_id=0,rock_id=2;
 vec3 tint;float rock=smoothstep(.06,.35,slope),gloss=0.0;emission=vec3(0);
 if(family==0){
  ground_id=type==5?4:0;rock_id=type==0?5:2;rock=max(rock,feature*.45);
 }else if(family==1){
  ground_id=1;rock_id=type==1?5:2;rock=max(rock,feature*.6);
 }else if(family==2){
  ground_id=type==3?1:0;rock_id=type==4?5:2;rock=max(rock,feature);gloss=type==4?.12:0.0;
 }else if(family==3){
  ground_id=type==5?0:1;rock_id=5;rock*=.65;
 }else if(family==4){
  ground_id=type==5?3:0;rock_id=2;gloss=type==2?feature*.4:0.0;
 }else if(family==5){
  ground_id=4;rock_id=5;gloss=.13;
 }else if(family==6){
  ground_id=1;rock_id=0;rock=max(rock,feature*.4);
 }else{
  ground_id=1;rock_id=5;gloss=type==3?.25:0.0;
 }
 // Match the sampler's continuous regional transition. Quantizing the whole
 // tint with round(region) painted hard kilometre-scale stripes across pits
 // and hills even though their geometry was already blending smoothly.
 int lower=int(clamp(floor(region),0.0,5.0));float regional_blend=smoothstep(.25,.75,fract(region));
 tint=mix(extension_tint(family,lower),extension_tint(family,min(lower+1,5)),regional_blend);
 if(family==0){float strata=.5+.5*sin((world_position.y+world_position.x*.015)/max(type==2?5.0:24.0,1.0));tint*=mix(.85,1.08,strata*(type==0?0.15:1.0));}
 vec4 g,r;vec3 gg,rg;float near_detail=1.0-smoothstep(1500.0,7000.0,view_distance);
 g=badlands_average(ground_id);r=badlands_average(rock_id);gg=vec3(0);rg=vec3(0);
 if(near_detail>.002){badlands_sample(ground_id,2.5,dx,dy,projection,n,fine,g,gg);badlands_sample(rock_id,8.0,dx,dy,projection,n,fine,r,rg);}
 vec4 surface=mix(g,r,rock);gradient=mix(gg,rg,rock)*extension_normals[family]*near_detail;
 // Authored geological tints follow the active renderer's working space,
 // just like source_color textures. A fixed gamma darkened Compatibility twice.
 float luminance=dot(surface.rgb,vec3(.3,.5,.2));color=badlands_working_color(tint)*(.5+luminance*.9);rough=clamp(surface.a-gloss,.25,.96);
 float cliff_exposure=smoothstep(.1,.4,slope);
 float outcrop_detail=rock*cliff_exposure*(1.0-smoothstep(7000.0,16000.0,view_distance));
 if(outcrop_detail>.01){
  // A subdued albedo-only outcrop scale, not a photographed grain normal
  // enlarged to 96m boulders. Actual landform relief comes from the mesh.
  vec4 broad;vec3 ignored;badlands_sample(rock_id,24.0,dx,dy,projection,n,0.0,broad,ignored);
  color*=mix(1.0,.88+dot(broad.rgb,vec3(.3,.5,.2))*.24,outcrop_detail*.2);
 }
 color*=.75*(1.0-wet*.16);rough=mix(rough,max(.32,rough-.12),wet);
 // World-space outcrop relief remains visible after fine PBR normals fade.
 float fracture=field(world_position.xz*.024+vec2(field(world_position.zy*.013),field(world_position.xy*.017))*3.0);
 float bedding=sin(world_position.y*.075+field(world_position.xz*.006)*9.0);
 float meso=field(world_position.xy*.12)+field(world_position.zy*.15);
 // Sub-metre apparent rock weathering on exposed faces only. The former
 // 5m amplitude inflated smooth hills and colony soils into soft grooves.
 float macro_height=(fracture*.5+bedding*.12+meso*.025)*rock*cliff_exposure*(1.0-smoothstep(4000.0,16000.0,view_distance));
 vec3 mr1=cross(dy,n),mr2=cross(n,dx);float mdet=dot(dx,mr1);
 if(abs(mdet)>.000001)gradient-=clamp((mr1*dFdx(macro_height)+mr2*dFdy(macro_height))/mdet,vec3(-.65),vec3(.65))*extension_normals[family];
 color*=.78+fracture*.3+meso*.055;rough=clamp(rough+fracture*.08,.14,.98);
 if(family==2){
  float flow_noise=field(world_position.xz*.09+vec2(field(world_position.xz*.022))*4.0);
  float rope=sin(world_position.x*.29+world_position.z*.11+flow_noise*9.0);
  float pores=smoothstep(.64,.82,field(world_position.xz*1.6));
  float lava_height=type==3?pores*.055:(type==4?rope*.09+flow_noise*.14:flow_noise*.06);
  if(abs(mdet)>.000001)gradient-=clamp((mr1*dFdx(lava_height)+mr2*dFdy(lava_height))/mdet,vec3(-.5),vec3(.5))*fine*extension_normals[family];
  color*=type==3?.67+pores*.4:(type==4?.66+flow_noise*.54: .8+flow_noise*.25);
  rough=type==4?mix(.2,.73,flow_noise):type==3?.95:rough;
 }
 if(family==3 || family==7){
  vec3 bio;float tissue_rough=.87;
  if(family==7)alien_tissue_sample(region,view_distance,dx,dy,projection,n,bio,tissue_rough);
  else{
   bio=textureLod(biological_colors,vec3(.5,.5,0.0),11.0).rgb;
   float detail=1.0-smoothstep(400.0,1800.0,view_distance);
   if(detail>.002)bio=mix(bio,biological_sample(0,2.5,dx,dy,projection,n),detail);
  }
  float colony_texture=field(world_position.xz*.032+vec2(field(world_position.xz*.007)*4.0));
  float patch=mix(.58,1.0,smoothstep(.12,.88,colony_texture));
  if(family==3 && type==2)bio=mix(bio,vec3(.38,.36,.29),.55);
  float coverage=family==3?feature*patch*(1.0-rock*.65):.65+feature*.35;
  color=mix(color,bio*.55,clamp(coverage,0.0,1.0));rough=tissue_rough;
  // Albedo-derived apparent microrelief, not a measured physical height scan.
  float height=dot(bio,vec3(.3,.5,.2))*(family==3?.001: .003)*coverage;
  vec3 r1=cross(dy,n),r2=cross(n,dx);float denominator=dot(dx,r1);
  if(abs(denominator)>.000001)gradient-=clamp((r1*dFdx(height)+r2*dFdy(height))/denominator,vec3(-.25),vec3(.25))*extension_normals[family]*fine;
  float luminous=family==3?spore_light*wet:step(.94,ground_field(world_position.xz/1900.0+vec2(81,17)))*feature*wet;
  float pulse=family==7?.94+.06*sin(TIME*.3+world_position.x/4000.0):1.0;
  emission=vec3(.12,.4,.31)*luminous*extension_emission[family]*pulse;
 }
 // Outcrop-scale normals intentionally outlive the microdetail distance, but
 // must still obey the explicit global normal-off diagnostics. Zero strength
 // and normal-off are the same physical material control, at every scale.
 if(debug_view==7 || debug_view==18 || diagnostic_surface==2 || extension_normals[family]<=.001)gradient=vec3(0);
 if(debug_view>=260 && debug_view<=264){
  color=vec3(0);gradient=vec3(0);rough=1.0;
  emission=debug_view==260?id_color(family+8):(debug_view==261?id_color(type):(debug_view==262?vec3(feature):(debug_view==263?vec3(wet):n*.5+.5)));
 }
}
