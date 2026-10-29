shader_type spatial;
render_mode blend_mix,depth_draw_always,cull_back,diffuse_burley,specular_schlick_ggx;
uniform sampler2D scene_color:hint_screen_texture,filter_linear_mipmap,repeat_disable;
uniform int debug_view=0;
varying vec3 local_point;
#include "res://tools/biome_extensions/crystal_bulk_optics.gdshaderinc"
void vertex(){local_point=VERTEX;}
void fragment(){
 int kind=int(clamp(floor(UV.x),0.0,5.0));float t=clamp(fract(UV.x)*4.0,0.0,1.0);
 vec3 n=normalize(NORMAL),incident=-normalize(VIEW);float incidence=max(dot(-incident,n),0.0),ior=mineral_ior(kind);
 float f0=pow((ior-1.0)/(ior+1.0),2.0),fresnel=f0+(1.0-f0)*pow(1.0-incidence,5.0);
 vec3 through=mineral_throughput(kind,UV.y,incidence,COLOR.rgb)*(1.0-fresnel);
 float transmission=dot(through,vec3(.3,.5,.2));vec3 behind=vec3(0);
 if(transmission>.0005){
  vec3 ray=refract(incident,n,1.0/ior);vec2 displacement=ray.xy/max(abs(ray.z),.35)*.008*clamp(UV.y/8.0,.05,1.0);
  behind=textureLod(scene_color,clamp(SCREEN_UV+displacement,vec2(.002),vec2(.998)),kind==2?1.8:1.0).rgb;
 }
 // Restrained growth zoning and cloudy inclusions,filtered before aliasing.
 float phase=local_point.y*.31+sin(local_point.x*.13)*1.6+sin(local_point.z*.17);
 float filtered=1.0-smoothstep(.5,2.0,fwidth(phase));float growth=.5+.5*sin(phase)*filtered;
 float cloudy=.5+.5*sin(local_point.x*.071+sin(local_point.z*.091)*2.0+local_point.y*.039);
 float weathered=smoothstep(.72,1.0,t)*.06;
 ALBEDO=COLOR.rgb*(.82+cloudy*.10)*(1.0-transmission);
 EMISSION=behind*through;
 ROUGHNESS=clamp((kind==2?.34:(kind==5?.65:.19))+growth*.045+cloudy*.025+weathered,.12,.85);
 SPECULAR=clamp(f0/.08,0.0,1.0);METALLIC=0.0;ALPHA=1.0;
 if(debug_view==3){EMISSION=ALBEDO;ALBEDO=vec3(0);SPECULAR=0.0;ROUGHNESS=1.0;}
 if(debug_view==4 || debug_view==8){ALBEDO=vec3(0);EMISSION=normalize((INV_VIEW_MATRIX*vec4(n,0)).xyz)*.5+.5;SPECULAR=0.0;ROUGHNESS=1.0;}
}
