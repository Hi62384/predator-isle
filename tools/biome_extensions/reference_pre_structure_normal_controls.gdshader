shader_type spatial;
render_mode diffuse_burley,specular_schlick_ggx;
uniform int family=5;
uniform float weathering=.4;
uniform sampler2DArray structure_colors:source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2DArray structure_normals:hint_normal,filter_linear_mipmap_anisotropic,repeat_enable;
varying vec3 world;
varying vec3 face_normal;
varying vec3 world_position;
varying vec3 forest_local_position;
varying vec3 forest_origin;
float field(vec2 p){
 vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
 vec4 h=fract(sin(vec4(dot(i,vec2(127.1,311.7)),dot(i+vec2(1,0),vec2(127.1,311.7)),dot(i+vec2(0,1),vec2(127.1,311.7)),dot(i+vec2(1,1),vec2(127.1,311.7))))*43758.5453);
 return mix(mix(h.x,h.y,f.x),mix(h.z,h.w,f.x),f.y);
}
#include "res://shaders/biological_sampling.gdshaderinc"
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;world_position=world;forest_local_position=VERTEX;forest_origin=(MODEL_MATRIX*vec4(0,0,0,1)).xyz;face_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
vec3 unpack_structure(vec2 v){vec2 xy=v*2.0-1.0;float z=sqrt(max(1.0-dot(xy,xy),.05));return vec3(xy/max(z,.35),1.0);}
vec3 structure_working_color(vec3 srgb){
 if(OUTPUT_IS_SRGB)return srgb;
 return mix(srgb/12.92,pow((srgb+vec3(.055))/1.055,vec3(2.4)),step(vec3(.04045),srgb));
}
void fragment(){
 float grain=.5+.5*sin(world.x*1.7+sin(world.z*2.3))*sin(world.y*1.3+sin(world.x*.8));
 float age=.5+.5*sin(world.x*.007+world.y*.011+world.z*.013);
 ALBEDO=structure_working_color(COLOR.rgb)*(.75+grain*.12+age*.13);
 ROUGHNESS=family==5?.2+weathering*.35+grain*.1:(family==6?.85:.55+weathering*.2);
 SPECULAR=family==5?.7:.22;
 if(family==6){
  vec3 n=normalize(face_normal),weights=pow(abs(n),vec3(6));weights/=dot(weights,vec3(1));vec3 p=world/2.5;
  vec2 ux=vec2(p.z,-p.y*sign(n.x)),uy=vec2(p.x,-p.z*sign(n.y)),uz=vec2(p.x,p.y*sign(n.z));
  vec4 s=texture(structure_colors,vec3(ux,3.0))*weights.x+texture(structure_colors,vec3(uy,3.0))*weights.y+texture(structure_colors,vec3(uz,3.0))*weights.z;
  vec3 a=unpack_structure(texture(structure_normals,vec3(ux,3.0)).rg),b=unpack_structure(texture(structure_normals,vec3(uy,3.0)).rg),c=unpack_structure(texture(structure_normals,vec3(uz,3.0)).rg);
  vec3 gradient=vec3(0,-a.y*sign(n.x),a.x)*weights.x+vec3(b.x,0,-b.y*sign(n.y))*weights.y+vec3(c.x,c.y*sign(n.z),0)*weights.z;
  ALBEDO=mix(s.rgb*.6,ALBEDO,.45);ROUGHNESS=max(s.a,.72);NORMAL=normalize((VIEW_MATRIX*vec4(normalize(n+gradient*.45),0)).xyz);
 }
 if(family==7){
  // Conduit UV carries canonical regional identity/feature controls, not a
  // decorative repeating UV map. Match the terrain's tissue layer and distant
  // filtering, rather than painting pink nerve tissue across carapace aprons.
  bool semantic=UV.x>=0.0 && UV.x<=5.0;
  vec3 n=normalize(face_normal),w=pow(abs(n),vec3(6));w/=dot(w,vec3(1));
  vec3 tissue;float rough;
  alien_tissue_sample(semantic?UV.x:0.0,length(VERTEX),dFdx(world),dFdy(world),w,n,tissue,rough);
  float apron=semantic?1.0-smoothstep(.4,.9,COLOR.a):0.0;
  ALBEDO=tissue*mix(.5,.55,apron);
  ROUGHNESS=mix(.6,rough,apron);
 }
}
