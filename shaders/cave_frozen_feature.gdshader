shader_type spatial;
render_mode diffuse_burley,specular_schlick_ggx;
#include "res://shaders/cave_vertex_projection.gdshaderinc"
#include "res://shaders/cave_frozen_surface.gdshaderinc"
varying vec3 ice_position;
varying vec3 ice_texture_position;
varying vec3 ice_normal;
varying vec4 ice_character;
void vertex(){
 ice_position=VERTEX+mod(MODEL_MATRIX[3].xyz,vec3(3840.0));
 ice_texture_position=VERTEX+mod(MODEL_MATRIX[3].xyz,vec3(max(cave_frozen_texture_metres,.5)));
 ice_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);ice_character=COLOR;
 POSITION=cave_project_vertex(VERTEX,MODEL_MATRIX,VIEW_MATRIX,INV_VIEW_MATRIX,PROJECTION_MATRIX,MODELVIEW_MATRIX);
}
void fragment(){
 vec3 base,mapped;float rough;vec3 n=normalize(ice_normal);
 cave_frozen_sample(ice_position,ice_texture_position,n,dFdx(ice_position),dFdy(ice_position),base,rough,mapped);
 // Geometry carries thickness/frost character; no emission or animated ice.
 ALBEDO=mix(base,vec3(.70,.80,.84),ice_character.g*.55);
 ROUGHNESS=mix(rough,.78,ice_character.g*.65);SPECULAR=.28;
 NORMAL=normalize((VIEW_MATRIX*vec4(mapped,0)).xyz);AO=.08;AO_LIGHT_AFFECT=0.0;
}
