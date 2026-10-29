// Dedicated Desert layer. All source maps are prepared offline; no runtime HTTP.
uniform sampler2DArray desert_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray desert_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool desert_palette_ready = false;
uniform float desert_color_variation = 0.45;
uniform float desert_ripple_strength = 0.32;
uniform float desert_ripple_wavelength = 0.24;
uniform float desert_gravel_coverage = 0.6;
uniform float desert_weathering = 0.65;
uniform float desert_macro_strength = 0.65;
uniform float desert_normal_strength = 0.65;
uniform float desert_salt_coverage = 0.55;
uniform float desert_sediment_variation = 0.55;
uniform float desert_wind_angle = 0.418879;
uniform float desert_wind_variation = 0.65;

// Derivative-free variant: the caller passes a conservative world footprint.
// Safe inside biome/material branches; no dFdx/dFdy in divergent control flow.
float desert_field(vec2 p,float footprint) {
 p=mat2(vec2(0.8,0.6),vec2(-0.6,0.8))*p;
 vec2 i=floor(p),f=fract(p);
 vec2 u=f*f*f*(f*(f*6.0-15.0)+10.0);
 vec4 a=fract(sin(vec4(dot(i,vec2(127.1,311.7)),dot(i+vec2(1,0),vec2(127.1,311.7)),dot(i+vec2(0,1),vec2(127.1,311.7)),dot(i+vec2(1,1),vec2(127.1,311.7))))*43758.5453)*6.283185;
 vec4 v=vec4(dot(vec2(cos(a.x),sin(a.x)),f),dot(vec2(cos(a.y),sin(a.y)),f-vec2(1,0)),dot(vec2(cos(a.z),sin(a.z)),f-vec2(0,1)),dot(vec2(cos(a.w),sin(a.w)),f-vec2(1,1)));
 return clamp(0.5+mix(mix(v.x,v.y,u.x),mix(v.z,v.w,u.x),u.y)*0.7*(1.0-smoothstep(0.3,1.0,footprint)),0.0,1.0);
}
vec2 desert_phase(vec2 p) {
 float phase = mod(cliff_world_seed,10007.0)*0.013;
 vec2 q=vec2(dot(p,vec2(cos(desert_wind_angle),sin(desert_wind_angle))),dot(p,vec2(-sin(desert_wind_angle),cos(desert_wind_angle))));
 float a=sin(p.x/9100.0+phase)*cos(p.y/11700.0-phase*0.71);
 float b=cos(p.x/13700.0-phase*0.43)*sin(p.y/8300.0+phase);
 return q+vec2(a,b)*desert_wind_variation*1600.0;
}
int desert_fallback(int id) {
 if(id==0 || id==5) return 1;
 if(id==1 || id==4) return 5;
 if(id==2) return 6;
 return 8;
}
void desert_projected(int id,vec2 uv,vec2 dx,vec2 dy,float near_detail,out vec4 s,out vec3 t) {
 t=vec3(0,0,1);
 vec2 alternate=vec2(-uv.y,uv.x)*0.731+vec2(7.137,19.731);
 vec2 ax=vec2(-dx.y,dx.x)*0.731, ay=vec2(-dy.y,dy.x)*0.731;
 if(desert_palette_ready) {
  s=textureGrad(desert_color,vec3(uv,float(id)),dx,dy);
  if(near_detail>0.001) {
   s=mix(s,textureGrad(desert_color,vec3(alternate,float(id)),ax,ay),0.24*near_detail);
   t=unpack_normal(textureGrad(desert_normal,vec3(uv,float(id)),dx,dy).rg);
   vec3 other=unpack_normal(textureGrad(desert_normal,vec3(alternate,float(id)),ax,ay).rg);
   t=normalize(mix(t,vec3(other.y,-other.x,other.z),0.24*near_detail));
  }
 } else {
  projected_surface(desert_fallback(id),uv,dx,dy,near_detail,s,t);
  // projected_surface already converts normals to slope; normalize restores it.
  t.z=1.0;
 }
 t.xy/=max(t.z,0.3);
}
void desert_layer(int id,vec3 p,vec3 dx,vec3 dy,vec3 projection,vec3 n,float near_detail,out vec4 surface,out vec3 gradient) {
 surface=vec4(0.0);gradient=vec3(0.0);
 // Same signed surface-gradient projection as the established Grass shader.
 if(projection.x>0.003) {
  vec4 s;vec3 t;
  desert_projected(id,vec2(p.z,-p.y*sign(n.x)),vec2(dx.z,-dx.y*sign(n.x)),vec2(dy.z,-dy.y*sign(n.x)),near_detail,s,t);
  surface+=s*projection.x;gradient+=vec3(0,-t.y*sign(n.x),t.x)*projection.x;
 }
 if(projection.y>0.003) {
  vec4 s;vec3 t;
  desert_projected(id,vec2(p.x,-p.z*sign(n.y)),vec2(dx.x,-dx.z*sign(n.y)),vec2(dy.x,-dy.z*sign(n.y)),near_detail,s,t);
  surface+=s*projection.y;gradient+=vec3(t.x,0,-t.y*sign(n.y))*projection.y;
 }
 if(projection.z>0.003) {
  vec4 s;vec3 t;
  desert_projected(id,vec2(p.x,p.y*sign(n.z)),vec2(dx.x,dx.y*sign(n.z)),vec2(dy.x,dy.y*sign(n.z)),near_detail,s,t);
  surface+=s*projection.z;gradient+=vec3(t.x,t.y*sign(n.z),0)*projection.z;
 }
}
// Rock structure from the same licensed sandstone normal source at two larger
// physical scales. This is actual normal-map relief, not painted crack lines.
vec3 desert_rock_normal(vec2 uv,vec2 dx,vec2 dy) {
 vec2 encoded;
 if(desert_palette_ready)encoded=textureGrad(desert_normal,vec3(uv,3.0),dx,dy).rg;
 else encoded=textureGrad(palette_normal,vec3(uv,float(desert_fallback(3))),dx,dy).rg;
 vec3 normal=unpack_normal(encoded);
 return vec3(normal.xy/max(normal.z,0.4),1.0);
}
vec3 desert_rock_gradient(vec3 p,vec3 dx,vec3 dy,vec3 projection,vec3 n) {
 vec3 g=vec3(0.0);
 if(projection.x>0.003){vec3 t=desert_rock_normal(vec2(p.z,-p.y*sign(n.x)),vec2(dx.z,-dx.y*sign(n.x)),vec2(dy.z,-dy.y*sign(n.x)));g+=vec3(0,-t.y*sign(n.x),t.x)*projection.x;}
 if(projection.y>0.003){vec3 t=desert_rock_normal(vec2(p.x,-p.z*sign(n.y)),vec2(dx.x,-dx.z*sign(n.y)),vec2(dy.x,-dy.z*sign(n.y)));g+=vec3(t.x,0,-t.y*sign(n.y))*projection.y;}
 if(projection.z>0.003){vec3 t=desert_rock_normal(vec2(p.x,p.y*sign(n.z)),vec2(dx.x,dx.y*sign(n.z)),vec2(dy.x,dy.y*sign(n.z)));g+=vec3(t.x,t.y*sign(n.z),0)*projection.z;}
 return g;
}
void shade_desert(vec3 n,vec3 dx,vec3 dy,vec3 projection,float near_detail,float curvature,out vec3 color,out float rough,out vec3 gradient,out vec3 weights_debug) {
 vec2 p=world_position.xz;
 float pixel=max(length(dx),length(dy));
 float slope=1.0-n.y;
 float dune=clamp(desert_region.a,0.0,1.0);
 float rock_context=desert_surface.x;
 float drainage=desert_surface.y;
 float basin=desert_surface.z;
 float accumulation=desert_surface.w;
 // Geometry, geology and deposition lead; boundary noise is a small perturbation.
 float macro=desert_field(p/1400.0+vec2(211,79),pixel/1400.0);
 // Sand interiors do not need rock/salt boundary perturbation.
 float meso=0.5;
 if(rock_context>0.001 || basin>0.001)meso=desert_field(p/27.0+vec2(37,113),pixel/27.0);
 float shelter=clamp(accumulation+smoothstep(0.03,0.4,curvature)*rock_context*0.2,0.0,1.0);
 float loose=clamp(dune+shelter*0.8,0.0,1.0);
 float rock=clamp(rock_context+smoothstep(0.18,0.5,slope)*rock_context,0.0,1.0);
 rock*=1.0-shelter*(1.0-smoothstep(0.1,0.35,slope))*0.85;
 rock=clamp(rock+(meso-0.5)*0.12*rock_context,0.0,1.0)*(1.0-basin*0.95);
 float gravel=desert_gravel_coverage*clamp(rock_context*(1.0-rock)+drainage*0.75+shelter*0.25,0.0,1.0)*(1.0-loose*0.65)*(1.0-basin*0.8);
 float salt=desert_wind.z*desert_salt_coverage*1.7;
 salt=clamp(salt+(meso-0.5)*0.12*basin,0.0,1.0);
 float wet=desert_wind.w*(1.0-smoothstep(0.0,4.0,world_position.y-water_level));
 float compact=clamp(basin*0.75+drainage*0.35+(1.0-loose)*(1.0-rock)*0.4,0.0,1.0);
 float w[6];
 w[0]=max(0.05,loose)*(1.0-rock)*(1.0-basin*0.8);
 w[1]=compact*(1.0-basin*0.65)*(1.0-rock);
 w[2]=gravel;
 w[3]=rock;
 w[4]=basin*(1.0-salt);
 w[5]=basin*salt;
 // At most three structural families; subtract fourth weight for smooth entry.
 int ids[3];float selected[3];
 for(int k=0;k<3;k++){int best=0;for(int j=1;j<6;j++){if(w[j]>w[best]) best=j;}ids[k]=best;selected[k]=w[best];w[best]=-1.0;}
 float cutoff=0.0;for(int j=0;j<6;j++)cutoff=max(cutoff,w[j]);
 float selected_rock=0.0;
 float total=0.0;for(int k=0;k<3;k++){selected[k]=max(0.0,selected[k]-cutoff);total+=selected[k];}
 if(total<0.0001){selected[0]=1.0;total=1.0;}
 color=vec3(0.0);rough=0.0;gradient=vec3(0.0);weights_debug=vec3(0.0);
 for(int k=0;k<3;k++) {
  float weight=selected[k]/total;
  if(weight<0.004) continue;
  int id=ids[k];float metres=3.5;
  if(id==3)selected_rock=weight;
  if(id==1)metres=2.0;if(id==2)metres=1.4;if(id==3)metres=5.0;if(id==4)metres=2.3;if(id==5)metres=2.0;
  float footprint=max(length(dx),length(dy))/metres;
  float micro=(1.0-smoothstep(0.15,0.85,footprint))*near_detail;
  vec4 s;vec3 g;
  // Mipmapped source albedo remains at distance, normal/anti-tile fetches fade.
  desert_layer(id,world_position/metres,dx/metres,dy/metres,projection,n,micro,s,g);
  vec3 tint=vec3(1.0);
  if(id==0) tint=mix(vec3(1.12,0.99,0.77),vec3(1.15,0.86,0.62),macro*desert_color_variation);
  if(id==1)tint=vec3(1.04,0.97,0.86);
  if(id==2)tint=vec3(0.91,0.85,0.73);
  if(id==3)tint=mix(vec3(1.12,0.94,0.79),vec3(1.17,0.75,0.54),clamp(desert_region.r-desert_region.g,0.0,1.0)*1.7);
  if(id==4)tint=vec3(1.07,0.97,0.81);
  if(id==5)tint=vec3(1.08,1.06,0.98);
  if(!desert_palette_ready && id==5)s.rgb=mix(s.rgb,vec3(0.78,0.75,0.65),0.8);
  color+=s.rgb*tint*weight;
  rough+=clamp(s.a+0.14,0.7,1.0)*weight;
  gradient+=g*weight*micro;
  weights_debug+=vec3(id==0?1.0:0.0,id==3?1.0:0.0,(id==4 || id==5)?1.0:0.0)*weight;
 }
 // Macro normals remain readable beyond the micro-detail radius, then mip-fade.
 // Only the selected rock family pays these fetches; albedo never becomes flat.
 if(selected_rock>0.02 && debug_view!=7 && diagnostic_surface!=2) {
  float medium=1.0-smoothstep(0.2,0.9,pixel/28.0);
  float broad=1.0-smoothstep(0.2,0.9,pixel/95.0);
  if(medium>0.002)gradient+=desert_rock_gradient(world_position/28.0+vec3(17,31,71),dx/28.0,dy/28.0,projection,n)*selected_rock*medium*desert_macro_strength*0.30;
  if(broad>0.002)gradient+=desert_rock_gradient(world_position/95.0+vec3(83,19,43),dx/95.0,dy/95.0,projection,n)*selected_rock*broad*desert_macro_strength*0.20;
 }
 // Coherent tilted bedding with irregular thickness, interruptions and weathering.
 // Broad tonal beds are not black crack decals; fine fractures come from PBR maps.
 if(rock>0.001) {
  float tilt=desert_field(p/11000.0+vec2(97,43),pixel/11000.0)-0.5;
  float bed=world_position.y+p.x*0.009+p.y*0.006+tilt*15.0;
  float strata=desert_field(vec2(bed/13.0,desert_field(p/650.0,pixel/650.0)*0.65),pixel/13.0);
  float interruption=desert_field(p/160.0+vec2(world_position.y/370.0,19.0),pixel/160.0);
  float weather=desert_field(p/75.0+vec2(world_position.y/95.0,31.0),pixel/75.0);
  vec3 strata_tint=mix(vec3(0.80,0.71,0.64),vec3(1.12,1.08,0.96),strata);
  color*=mix(vec3(1.0),strata_tint,rock*desert_macro_strength*(0.35+interruption*0.65));
  color*=1.0-(weather-0.5)*rock*desert_weathering*0.16;
 }
 color*=mix(1.0,mix(0.94,1.06,macro),desert_sediment_variation)*(1.0-wet*0.35);
 rough=mix(rough,0.55,wet*0.75);
 // Wind-driven sub-metre ripples: shader-only, derivative filtered, loose sand only.
 // The global bounded phase exactly matches DesertSampler.wind_coordinates.
 float wavelength=max(desert_ripple_wavelength,0.08);
 gradient*=desert_normal_strength;
 // Beyond the ripple footprint cutoff its contribution is exactly zero.
 // Avoid all phase/noise/trigonometry work in inactive sand/water/rock pixels.
 if(near_detail>0.001 && pixel<wavelength*0.22 && loose>0.001 && rock<0.999 && basin<0.999 && wet<0.999) {
  vec2 wind=normalize(desert_wind.xy*2.0-1.0+vec2(0.00001));
  vec2 wind_uv=desert_phase(p);
  float phase=wind_uv.x/wavelength+desert_field(wind_uv/vec2(4.7,1.9),pixel/1.9)*1.35;
  float phase_width=pixel/wavelength*2.5;
  float ripple_fade=(1.0-smoothstep(0.16,0.55,phase_width))*near_detail;
  float breakup=0.55+0.45*desert_field(p/3.7+vec2(71,29),pixel/3.7);
  float lee=clamp(dot(n.xz,wind)*3.0,0.0,1.0);
  float ripple=cos(phase*6.283185)+0.28*cos(phase*11.791+wind_uv.y/1.1);
  float amplitude=desert_ripple_strength*loose*(1.0-rock)*(1.0-basin)*(1.0-wet)*(1.0-lee*0.65)*breakup*ripple_fade;
  gradient+=vec3(wind.x,0.0,wind.y)*ripple*amplitude;
 }
 gradient-=n*dot(gradient,n);
 if(debug_view==7 || diagnostic_surface==2)gradient=vec3(0.0);
}
