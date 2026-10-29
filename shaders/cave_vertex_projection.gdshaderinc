// Shared camera-grid-relative composition prevents separately rounded tile
// MODELVIEW translations opening subpixel sky cracks at welded cell joins.
uniform bool cave_common_projection=true;
vec4 cave_project_vertex(vec3 local_vertex,mat4 cave_model,mat4 cave_view,mat4 cave_inverse_view,mat4 cave_projection,mat4 cave_modelview){
 if(!cave_common_projection)return cave_projection*(cave_modelview*vec4(local_vertex,1.0));
 vec3 shared_origin=floor(cave_inverse_view[3].xyz/4096.0)*4096.0;
 vec3 relative_world=(cave_model[3].xyz-shared_origin)+mat3(cave_model)*local_vertex;
 vec3 origin_view=(cave_view*vec4(shared_origin,1.0)).xyz;
 return cave_projection*vec4(mat3(cave_view)*relative_world+origin_view,1.0);
}
