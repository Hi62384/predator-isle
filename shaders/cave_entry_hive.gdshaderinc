uniform float cave_entry_hive_region=1.0;
uniform float cave_entry_hive_normal_strength=.7;
#include "res://shaders/hive_tissue_material.gdshaderinc"
void shade_cave_entry(vec3 position,float hive_entry_view_range,vec3 n,vec3 position_dx,vec3 position_dy,out vec3 base,out float rough,out vec3 mapped){
 shade_hive_tissue(cave_entry_hive_region,hive_entry_view_range,n,position_dx,position_dy,cave_entry_hive_normal_strength,base,rough,mapped);
}
