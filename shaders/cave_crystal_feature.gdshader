shader_type spatial;
render_mode diffuse_burley,specular_schlick_ggx;
#include "res://shaders/cave_vertex_projection.gdshaderinc"
#include "res://shaders/crystal_bulk_optics.gdshaderinc"
uniform bool cave_crystal_bed=false;
uniform float cave_crystal_luminous_strength=0.0;
uniform float cave_crystal_ambient_shelter=0.08;
varying vec3 crystal_position;
void vertex(){
 crystal_position=VERTEX+mod(MODEL_MATRIX[3].xyz,vec3(3840.0));
 POSITION=cave_project_vertex(VERTEX,MODEL_MATRIX,VIEW_MATRIX,INV_VIEW_MATRIX,PROJECTION_MATRIX,MODELVIEW_MATRIX);
}
void fragment(){
 int kind=int(clamp(floor(UV.x),0.0,5.0));float t=clamp(fract(UV.x)*4.0,0.0,1.0);
 float phase=UV2.x*(6.283185307179586/6.0)+UV2.y;
 float growth=.5+.5*sin(phase)*(1.0-smoothstep(.5,2.0,fwidth(phase)));
 float cloud=.5+.5*sin(dot(crystal_position,vec3(6.283185307179586/96.0,6.283185307179586/120.0,6.283185307179586/160.0)));
 float f0=pow((mineral_ior(kind)-1.0)/(mineral_ior(kind)+1.0),2.0);
 float facing=abs(dot(normalize(NORMAL),normalize(VIEW)));float edge=pow(1.0-facing,4.0);
 float micro_phase=dot(crystal_position,vec3(6.283185307179586/.5,6.283185307179586/.25,6.283185307179586/.75));float micro=.5+.5*sin(micro_phase)*(1.0-smoothstep(.5,2.0,fwidth(micro_phase)));
 // Sub-metre cloudy growth interruptions and fine cleavage striae belong
 // to the mineral bulk,not noisy smoothed facet normals. All wavelengths
 // divide the same3840m origin period and are filtered before minification.
 float inclusion_phase=crystal_position.x*(6.283185307179586/2.5)+sin(crystal_position.z*(6.283185307179586/1.25))*1.3;
 float inclusions=.5+.5*sin(inclusion_phase)*sin(crystal_position.y*(6.283185307179586/.75));
 float striae_phase=UV2.x*(6.283185307179586/.06)+UV2.y+sin(crystal_position.x*(6.283185307179586/.5))*.15;
 float striae=.5+.5*sin(striae_phase)*(1.0-smoothstep(.5,2.0,fwidth(striae_phase)));
 float weather=COLOR.a;
 ALBEDO=COLOR.rgb*(.63+.13*cloud+.08*growth+.06*edge+.06*inclusions+.005*striae);
 ROUGHNESS=clamp((kind==2?.25:(kind==5?.22:.105))+growth*.025+weather*.17+inclusions*.035+striae*.018+smoothstep(.8,1.0,t)*.035,.10,.8);
 if(cave_crystal_bed){ALBEDO*=.52+.14*cloud+.08*micro;ROUGHNESS=.57+micro*.13;}
 SPECULAR=clamp(f0/.08,0.0,1.0);METALLIC=0.0;AO=mix(.72,1.0,smoothstep(0.0,.22,t))*cave_crystal_ambient_shelter;AO_LIGHT_AFFECT=0.0;
 // SELECTIVE_NEAR_TRANSMISSION
 if(UV.y<0.0){vec3 fictional_tint=kind%3==0?vec3(.14,.65,.8):(kind%3==1?vec3(.42,.22,.8):vec3(.16,.36,.8));EMISSION=fictional_tint*cave_crystal_luminous_strength;}
}
