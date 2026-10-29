// Texture-led CC0 AmbientCG Snow005 / Snow006 / Snow014 / Ice004.
// Geography masks are procedural; cracks, grain and wind detail come from maps.
uniform sampler2DArray snow_colors:source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2DArray snow_normals:hint_normal,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2DArray snow_heights:filter_linear_mipmap_anisotropic,repeat_enable;
uniform float snow_albedo_gain=.45;
uniform float snow_powder_strength=1.0;
uniform float snow_compacted_coverage=.55;
uniform float snow_color_variation=.06;
uniform float snow_ice_roughness=.27;
uniform float snow_macro_strength=.25;
uniform float snow_normal_strength=.8;
uniform float snow_slope_influence=1.0;
uniform float snow_exposed_ice=.65;
uniform float snow_glacier_snow=.65;
uniform float snow_ice_snow=.55;
uniform float snow_wind_angle=.488692;
uniform float snow_wind_variation=.5;
uniform float snow_seed_phase=0.0;
uniform float snow_powder_metres=3.0;
uniform float snow_crust_metres=5.0;
uniform float snow_ground_metres=3.8;
uniform float snow_rock_metres=9.0;
uniform float snow_ice_metres=12.0;
uniform float snow_wind_metres=35.0;
uniform float snow_crust_strength=.8;
uniform float snow_rock_strength=.7;
uniform float snow_ice_strength=.7;
uniform float snow_ground_strength=.45;
uniform float snow_master_strength=1.0;
vec2 snow_wind(vec2 p){
 float ca=cos(snow_wind_angle),sa=sin(snow_wind_angle);
 return vec2(ca*p.x+sa*p.y,-sa*p.x+ca*p.y)+vec2(sin(p.x/12000.0+snow_seed_phase)*cos(p.y/15000.0-snow_seed_phase),cos(p.x/17000.0-snow_seed_phase)*sin(p.y/11000.0+snow_seed_phase))*snow_wind_variation*400.0;
}
void snow_projected(int id,vec2 uv,vec2 dx,vec2 dy,float fine,out vec4 surface,out vec3 t){
 // Continuous stochastic offset blending breaks square source repetition at
 // medium range too. This mask selects scan samples; it creates no surface detail.
 float k=field(uv*.23+vec2(39.7,81.3))*8.0;
 float index=floor(k),blend=smoothstep(.1,.9,fract(k));
 vec2 a=uv+sin(vec2(3.0,7.0)*index)*19.0;
 vec2 b=uv+sin(vec2(3.0,7.0)*(index+1.0))*19.0;
 surface=mix(textureGrad(snow_colors,vec3(a,float(id)),dx,dy),textureGrad(snow_colors,vec3(b,float(id)),dx,dy),blend);
 t=vec3(0,0,1);
 if(fine>.001){
  vec3 one=unpack_normal(textureGrad(snow_normals,vec3(a,float(id)),dx,dy).rg);
  vec3 other=unpack_normal(textureGrad(snow_normals,vec3(b,float(id)),dx,dy).rg);
  t=normalize(mix(one,other,blend));t.xy/=max(t.z,.3);
 }
}
void snow_sample(int id,vec3 p,vec3 dx,vec3 dy,vec3 projection,vec3 n,float fine,out vec4 surface,out vec3 gradient){
 surface=vec4(0);gradient=vec3(0);
 if(projection.x>.002){vec4 s;vec3 t;snow_projected(id,vec2(p.z,-p.y*sign(n.x)),vec2(dx.z,-dx.y*sign(n.x)),vec2(dy.z,-dy.y*sign(n.x)),fine,s,t);surface+=s*projection.x;gradient+=vec3(0,-t.y*sign(n.x),t.x)*projection.x;}
 if(projection.y>.002){vec4 s;vec3 t;snow_projected(id,vec2(p.x,-p.z*sign(n.y)),vec2(dx.x,-dx.z*sign(n.y)),vec2(dy.x,-dy.z*sign(n.y)),fine,s,t);surface+=s*projection.y;gradient+=vec3(t.x,0,-t.y*sign(n.y))*projection.y;}
 if(projection.z>.002){vec4 s;vec3 t;snow_projected(id,vec2(p.x,p.y*sign(n.z)),vec2(dx.x,dx.y*sign(n.z)),vec2(dy.x,dy.y*sign(n.z)),fine,s,t);surface+=s*projection.z;gradient+=vec3(t.x,t.y*sign(n.z),0)*projection.z;}
}
void shade_snow(vec3 n,vec3 dx,vec3 dy,vec3 projection,float fine,out vec3 color,out float rough,out vec3 gradient,out vec3 weights){
 float macro=field(world_position.xz/550.0+vec2(71.3,19.8));
 float depth=snow_a.w*12.0,slope=1.0-clamp(n.y,0.0,1.0);
 float facing=dot(n.xz,vec2(cos(snow_wind_angle),sin(snow_wind_angle)))*.18;
 float rock=clamp(snow_c.x*1.7*smoothstep(.08,.58,slope*snow_slope_influence+snow_b.x*.25+facing)*(1.0-smoothstep(.5,5.0,depth)),0.0,1.0);
 rock=max(rock,smoothstep(.35,.72,slope*snow_slope_influence)*clamp(snow_c.x*3.4,0.0,1.0));
 float frozen=max(snow_b.z,snow_b.w)*(1.0-smoothstep(.8,6.0,abs(world_position.y-water_level)));
 float glacier=snow_b.y;
 float ice=max(frozen*(1.0-snow_ice_snow*.8),glacier*snow_exposed_ice*(1.0-snow_glacier_snow*.85+snow_c.y*.35));
 // Scanned height breaks retained snow on ice into source-driven patches.
 if(ice>.001){
  float h=textureGrad(snow_heights,vec3(world_position.xz/28.0,1),dx.xz/28.0,dy.xz/28.0).r;
  ice=clamp(ice*(.65+smoothstep(.25,.7,h)*.7),0.0,1.0);
 }
 float compact=clamp(snow_b.x*.65+snow_compacted_coverage*(1.0-smoothstep(.2,3.0,depth))+glacier*.3,0.0,1.0);
 vec4 powder;vec3 powder_g;
 snow_sample(0,world_position/snow_powder_metres,dx/snow_powder_metres,dy/snow_powder_metres,projection,n,fine,powder,powder_g);
 vec4 crust=powder;vec3 crust_g=powder_g;
 if(compact>.01){
  // Avoid a hard source switch along the wind-exposure isocontour.
  snow_sample(1,world_position/snow_crust_metres+vec3(17.1),dx/snow_crust_metres,dy/snow_crust_metres,projection,n,fine,crust,crust_g);
 }
 color=mix(powder.rgb,crust.rgb,compact)*snow_albedo_gain;
 color*=1.0+(macro-.5)*snow_color_variation;
 rough=clamp(mix(powder.a,crust.a,compact),.68,.98);
 gradient=mix(powder_g*snow_powder_strength,crust_g*snow_crust_strength,compact)*snow_normal_strength;
 float bare=smoothstep(.28,.60,snow_b.x)*(1.0-smoothstep(.15,1.1,depth))*(1.0-glacier)*(1.0-frozen);
 if(bare>.001){
  vec4 ground;vec3 ground_g;sample_layer(6,world_position/snow_ground_metres,dx/snow_ground_metres,dy/snow_ground_metres,projection,n,fine,ground,ground_g);
  color=mix(color,ground.rgb*vec3(.65,.66,.68),bare);rough=mix(rough,ground.a,bare);gradient=mix(gradient,ground_g*snow_ground_strength,bare);
 }
 // Meso relief uses the scanned wind-packed normal, never cosine bands.
 if(snow_macro_strength>.001 && n.y>.5 && rock<.9){
  vec2 scale=vec2(snow_wind_metres*3.5,snow_wind_metres*.65);
  vec2 wind=snow_wind(world_position.xz)/scale;
  float ca=cos(snow_wind_angle),sa=sin(snow_wind_angle);
  mat2 rot=mat2(vec2(ca,-sa),vec2(sa,ca));
  vec3 t=unpack_normal(textureGrad(snow_normals,vec3(wind,2),rot*dx.xz/scale,rot*dy.xz/scale).rg);
  vec2 g=transpose(rot)*t.xy/max(t.z,.35);
  gradient+=vec3(g.x,0,g.y)*snow_macro_strength*(1.0-ice)*(1.0-rock)*smoothstep(.5,.85,n.y);
 }
 if(ice>.001){
  vec4 frozen_surface;vec3 frozen_g;
  if(glacier>.1){
   vec2 flow=normalize(snow_c.zw*2.0-1.0+vec2(.0001));vec2 across=vec2(-flow.y,flow.x);
   vec3 p=vec3(dot(world_position.xz,flow),world_position.y,dot(world_position.xz,across));
   vec3 gx=vec3(dot(dx.xz,flow),dx.y,dot(dx.xz,across)),gy=vec3(dot(dy.xz,flow),dy.y,dot(dy.xz,across));
   vec3 fn=vec3(dot(n.xz,flow),n.y,dot(n.xz,across));vec3 proj=pow(abs(fn),vec3(4));proj/=max(dot(proj,vec3(1)),.001);
   vec3 scale=vec3(snow_ice_metres*3.0,snow_ice_metres,snow_ice_metres*.7);
   snow_sample(3,p/scale,gx/scale,gy/scale,proj,fn,fine,frozen_surface,frozen_g);
   frozen_g=vec3(flow.x*frozen_g.x+across.x*frozen_g.z,frozen_g.y,flow.y*frozen_g.x+across.y*frozen_g.z);
  }else snow_sample(3,world_position/snow_ice_metres,dx/snow_ice_metres,dy/snow_ice_metres,projection,n,fine,frozen_surface,frozen_g);
  vec3 ice_color=frozen_surface.rgb*mix(vec3(.40,.57,.66),vec3(.56,.66,.72),glacier);
  color=mix(color,ice_color,ice);
  rough=mix(rough,clamp(frozen_surface.a+snow_ice_roughness-.35,.15,.8),ice);
  gradient=mix(gradient,frozen_g*snow_ice_strength,ice);
 }
 if(rock>.001){
  vec4 stone;vec3 stone_g;
  sample_layer(7,world_position/snow_rock_metres,dx/snow_rock_metres,dy/snow_rock_metres,projection,n,fine*smoothstep(.01,.1,rock),stone,stone_g);
  color=mix(color,stone.rgb*.65,rock);rough=mix(rough,.88,rock);gradient=mix(gradient,stone_g*snow_rock_strength,rock);
 }
 gradient-=n*dot(n,gradient);gradient*=snow_master_strength;
 if(debug_view==7)gradient=vec3(0);
 weights=vec3((1.0-ice)*(1.0-rock),ice*(1.0-rock),rock);
}
vec3 snow_debug(int mode,vec3 normal,vec3 weights){
 vec3 d=snow_a.rgb;
 if(mode==61)d=vec3(snow_a.w);
 if(mode==62){vec2 p=snow_wind(world_position.xz);vec2 x=snow_wind(world_position.xz+vec2(10,0)),y=snow_wind(world_position.xz+vec2(0,10));vec2 wind=normalize(vec2(y.y-p.y,p.y-x.y));d=vec3(wind*.5+.5,.5);}
 if(mode==63)d=vec3(snow_b.x);
 if(mode==64)d=vec3(smoothstep(.0,.4,snow_a.w));
 if(mode==65)d=vec3(weights.z);
 if(mode==66)d=vec3(snow_b.y);
 if(mode==67)d=vec3(snow_c.y);
 if(mode==68)d=vec3(snow_b.z,snow_b.w,0);
 if(mode==69)d=weights;
 if(mode==70)d=normal*.5+.5;
 if(mode==71){d=vec3(.5)+.4*cos(vec3(0,2.1,4.2)+chunk_lod*1.7);vec2 edge=min(mod(world_position.xz,chunk_size_metres),chunk_size_metres-mod(world_position.xz,chunk_size_metres));d*=smoothstep(0.0,max(1.0,view_distance*.0015),min(edge.x,edge.y));}
 return d;
}
