shader_type spatial;
render_mode diffuse_burley,specular_schlick_ggx;
#include "res://shaders/cave_vertex_projection.gdshaderinc"
uniform int geological_style=7;
uniform float hive_region=1.0;
uniform float normal_strength=.7;
varying vec3 world_position;
varying vec3 forest_local_position;
varying vec3 forest_origin;
varying vec3 hive_normal;
float field(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);vec4 h=fract(sin(vec4(dot(i,vec2(127.1,311.7)),dot(i+vec2(1,0),vec2(127.1,311.7)),dot(i+vec2(0,1),vec2(127.1,311.7)),dot(i+vec2(1,1),vec2(127.1,311.7))))*43758.5453);return mix(mix(h.x,h.y,f.x),mix(h.z,h.w,f.x),f.y);}
#include "res://shaders/biological_sampling.gdshaderinc"
#include "res://shaders/hive_tissue_material.gdshaderinc"
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;forest_local_position=VERTEX;forest_origin=MODEL_MATRIX[3].xyz;hive_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);POSITION=cave_project_vertex(VERTEX,MODEL_MATRIX,VIEW_MATRIX,INV_VIEW_MATRIX,PROJECTION_MATRIX,MODELVIEW_MATRIX);}
void fragment(){vec3 base,mapped;float rough;shade_hive_tissue(hive_region,length(VERTEX),normalize(hive_normal),dFdx(forest_local_position),dFdy(forest_local_position),max(normal_strength,0.0),base,rough,mapped);ALBEDO=base;ROUGHNESS=rough;SPECULAR=.2;NORMAL=normalize((VIEW_MATRIX*vec4(mapped,0)).xyz);AO=.08;AO_LIGHT_AFFECT=0.0;}
