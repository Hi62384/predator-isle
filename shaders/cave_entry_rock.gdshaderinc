#include "res://shaders/cave_rock_projection.gdshaderinc"
uniform sampler2DArray cave_entry_colors:source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2DArray cave_entry_normals:hint_normal,filter_linear_mipmap_anisotropic,repeat_enable;
uniform int cave_entry_geology=0;
uniform bool cave_entry_compact_palette=false;
void shade_cave_entry(vec3 position,vec3 n,vec3 position_dx,vec3 position_dy,out vec3 base,out float rough,out vec3 mapped){
 float wall_layer=0.0,floor_layer=6.0;if(cave_entry_geology==1){wall_layer=1.0;floor_layer=5.0;}if(cave_entry_geology==2){wall_layer=2.0;floor_layer=7.0;}if(cave_entry_geology==3){wall_layer=3.0;floor_layer=4.0;}if(cave_entry_geology==4){wall_layer=0.0;floor_layer=5.0;}if(cave_entry_geology==5){wall_layer=3.0;floor_layer=6.0;}
 if(cave_entry_geology==6){wall_layer=7.0;floor_layer=7.0;}
 if(cave_entry_compact_palette){wall_layer=0.0;floor_layer=0.0;}
 vec4 surface;
 project_cave_rock(cave_entry_colors,cave_entry_normals,position/4.0,position_dx/4.0,position_dy/4.0,
  n,wall_layer,floor_layer,1.0,.52,surface,mapped);
 vec3 tint=vec3(1);if(cave_entry_geology==0)tint=vec3(1.10,1.04,.91);if(cave_entry_geology==1)tint=vec3(.94,.97,1.02);if(cave_entry_geology==2)tint=vec3(1.03,.96,.88);if(cave_entry_geology==3)tint=vec3(.96,.94,.90);if(cave_entry_geology==4)tint=vec3(.87,.94,.98);if(cave_entry_geology==5)tint=vec3(.96,.87,.79);
 if(cave_entry_geology==6)tint=vec3(.91,.77,.61);
 float broad=.96+.04*sin(position.x*.016362462)*sin(position.z*.016362462);float strata=cave_entry_geology==2?1.0-.06*smoothstep(.75,.95,.5+.5*sin(position.y*1.5707963+position.x*.016362462)):1.0;base=surface.rgb*tint*broad*strata;rough=clamp(surface.a,.68,.98);
}
