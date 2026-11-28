shader_type spatial;
render_mode diffuse_burley,specular_schlick_ggx;
#include "res://shaders/cave_vertex_projection.gdshaderinc"
#include "res://shaders/cave_rock_projection.gdshaderinc"
uniform sampler2DArray cave_rock_colors:source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2DArray cave_rock_normals:hint_normal,filter_linear_mipmap_anisotropic,repeat_enable;
uniform int geological_style=0;
uniform bool cave_compact_palette=false;
uniform float texture_metres=4.0;
uniform float normal_strength=.52;
uniform vec4 cave_pool_positions[4];
uniform int cave_pool_count=0;
varying vec3 cave_position;
varying vec3 cave_world;
varying vec3 cave_normal;
varying float cave_mineral;
varying float cave_bedrock;
void vertex(){
 cave_position=VERTEX+mod(MODEL_MATRIX[3].xyz,vec3(3840.0));
 cave_world=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;
 cave_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
 cave_mineral=smoothstep(.5,.7,COLOR.r);
 cave_bedrock=1.0-smoothstep(.5,.75,COLOR.a);
 POSITION=cave_project_vertex(VERTEX,MODEL_MATRIX,VIEW_MATRIX,INV_VIEW_MATRIX,PROJECTION_MATRIX,MODELVIEW_MATRIX);
}
void fragment(){
 vec3 n=normalize(cave_normal),p=cave_position/max(texture_metres,.5);
 vec3 dx=dFdx(p),dy=dFdy(p);
 float wall_layer=0.0,floor_layer=6.0;
 if(geological_style==1){wall_layer=1.0;floor_layer=5.0;}
 if(geological_style==2){wall_layer=2.0;floor_layer=7.0;}
 if(geological_style==3){wall_layer=3.0;floor_layer=4.0;}
 if(geological_style==4){wall_layer=0.0;floor_layer=5.0;}
 if(geological_style==5){wall_layer=3.0;floor_layer=6.0;}
 if(geological_style==6){wall_layer=7.0;floor_layer=7.0;}
 if(cave_compact_palette){wall_layer=0.0;floor_layer=0.0;}
 vec4 surface;vec3 mapped;
 float gravel=(1.0-cave_mineral)*(1.0-cave_bedrock);
 project_cave_rock(cave_rock_colors,cave_rock_normals,p,dx,dy,n,wall_layer,floor_layer,gravel,normal_strength,surface,mapped);
 vec3 tint=vec3(1);if(geological_style==0)tint=vec3(1.10,1.04,.91);if(geological_style==1)tint=vec3(.94,.97,1.02);if(geological_style==2)tint=vec3(1.03,.96,.88);if(geological_style==3)tint=vec3(.96,.94,.90);if(geological_style==4)tint=vec3(.87,.94,.98);if(geological_style==5)tint=vec3(.96,.87,.79);
 if(geological_style==6)tint=vec3(.91,.77,.61);
 float broad=.96+.04*sin(cave_position.x*.016362462)*sin(cave_position.z*.016362462);float strata=geological_style==2?1.0-.06*smoothstep(.75,.95,.5+.5*sin(cave_position.y*1.5707963+cave_position.x*.016362462)):1.0;
 float wet=0.0;
 for(int i=0;i<4;i++){if(i>=cave_pool_count)break;vec4 pool=cave_pool_positions[i];float bank=1.0-smoothstep(pool.w,pool.w+8.0,length(cave_world.xz-pool.xz));float level=1.0-smoothstep(.5,3.0,abs(cave_world.y-pool.y));wet=max(wet,bank*level);}
 ALBEDO=surface.rgb*mix(tint,vec3(1.25,1.18,1.05),cave_mineral*.75)*broad*strata*mix(1.0,.64,wet);ROUGHNESS=mix(clamp(surface.a,.68,.98),.27,wet);ROUGHNESS=mix(ROUGHNESS,.48,cave_mineral*.6);SPECULAR=mix(.2,.38,wet);NORMAL=normalize((VIEW_MATRIX*vec4(mapped,0)).xyz);
 // Compatibility rendering has no volumetric sky-occlusion solution. This
 // material shelter term attenuates sky ambient only,not direct lights or
 // geometry. Real double-sided roof shadowing still blocks the sun.
 EMISSION+=cave_fill_light(ALBEDO,mapped);
 AO=.08;AO_LIGHT_AFFECT=0.0;
}
