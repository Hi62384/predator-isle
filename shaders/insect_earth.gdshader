shader_type spatial;
// Retained semantic family tag for diagnostics; no other family uses this shader.
uniform int family=6;
render_mode diffuse_burley,specular_schlick_ggx;
uniform float normal_strength=.7;
uniform int debug_view=0;
uniform sampler2DArray structure_colors:source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2DArray structure_normals:hint_normal,filter_linear_mipmap_anisotropic,repeat_enable;
varying vec3 local_metres;
varying vec3 origin_metres;
varying vec3 face_normal;
#include "res://shaders/insect_earth_optics.gdshaderinc"
void vertex(){local_metres=VERTEX;origin_metres=(MODEL_MATRIX*vec4(0,0,0,1)).xyz;face_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
void fragment(){
 vec3 n=normalize(face_normal),weights=pow(abs(n),vec3(6));weights/=dot(weights,vec3(1));
 vec3 p=local_metres+mod(origin_metres,vec3(3840.0));
 vec3 dx=dFdx(local_metres),dy=dFdy(local_metres);
 float footprint=max(length(dx),length(dy)),distance_to_eye=length(VERTEX);
 float near_detail=1.0-smoothstep(120.0,700.0,distance_to_eye);
 float amount=(debug_view==7 || debug_view==18)?0.0:max(normal_strength,0.0);
 // Existing photographed warm weathered red soil, not an enlarged rock scan.
 vec3 tex=p/2.5;vec2 ux=vec2(tex.z,-tex.y*sign(n.x)),uy=vec2(tex.x,-tex.z*sign(n.y)),uz=vec2(tex.x,tex.y*sign(n.z));
 vec4 soil=texture(structure_colors,vec3(ux,3))*weights.x+texture(structure_colors,vec3(uy,3))*weights.y+texture(structure_colors,vec3(uz,3))*weights.z;
 vec3 gradient=vec3(0);
 if(amount>.001 && near_detail>.001){
  vec3 a=earth_unpack(texture(structure_normals,vec3(ux,3)).rg),b=earth_unpack(texture(structure_normals,vec3(uy,3)).rg),c=earth_unpack(texture(structure_normals,vec3(uz,3)).rg);
  gradient=(vec3(0,-a.y*sign(n.x),a.x)*weights.x+vec3(b.x,0,-b.y*sign(n.y))*weights.y+vec3(c.x,c.y*sign(n.z),0)*weights.z)*(.45/.7)*near_detail;
 }
 float broad=earth_noise(p,12.0),pitting=earth_noise(p,.8),grain=earth_noise(p,.08);
 float grain_filter=1.0-smoothstep(.025,.12,footprint);
 float pitting_filter=1.0-smoothstep(.25,1.2,footprint);
 float relief=(pitting*.035*pitting_filter+grain*.006*grain_filter)*near_detail;
 vec3 r1=cross(dy,n),r2=cross(n,dx);float determinant=dot(dx,r1);
 if(amount>.001 && abs(determinant)>.000001)gradient-=clamp((r1*dFdx(relief)+r2*dFdy(relief))/determinant,vec3(-.25),vec3(.25));
 // Keep a tangent-space surface gradient; never flip the outward hemisphere.
 gradient-=n*dot(gradient,n);gradient=gradient/max(1.0,length(gradient)/.65);
 vec3 mapped=normalize(n+gradient*amount);
 float luma=dot(soil.rgb,vec3(.3,.5,.2));
 ALBEDO=earth_working_color(COLOR.rgb)*clamp(.73+luma*.85,.64,1.20)*(.88+broad*.22);
 ALBEDO*=1.0-(1.0-smoothstep(.18,.46,pitting))*.10*pitting_filter;
 ROUGHNESS=clamp(max(soil.a,.82)+(.5-grain)*.08*grain_filter,.80,.98);SPECULAR=.18;
 NORMAL=normalize((VIEW_MATRIX*vec4(mapped,0)).xyz);
 if(debug_view==3){EMISSION=ALBEDO;ALBEDO=vec3(0);SPECULAR=0.0;ROUGHNESS=1.0;}
 if(debug_view==4 || debug_view==8){EMISSION=(debug_view==4?n:mapped)*.5+.5;ALBEDO=vec3(0);SPECULAR=0.0;ROUGHNESS=1.0;}
}
