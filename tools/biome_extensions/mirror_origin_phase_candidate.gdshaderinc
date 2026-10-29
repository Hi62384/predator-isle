// PRIVATE rejected cold-resource trial. Not included by production shaders.
#ifndef BIOLOGICAL_ORIGIN_PHASE_INCLUDED
#define BIOLOGICAL_ORIGIN_PHASE_INCLUDED
// Mycelium's mirrored lookup has a two-repeat period. Keep the odd origin
// quotient in the vertex stage without changing ordinary tissue sampling.
// Current layer-zero physical scale is 2.5m (10 quarter-metre ticks).
varying flat vec3 biological_mirror_origin;
vec3 biological_origin_parity(vec3 origin){
 ivec3 q=ivec3(round(origin*4.0)),r=abs(q)%ivec3(20);
 if(q.x<0 && r.x>0)r.x=20-r.x;if(q.y<0 && r.y>0)r.y=20-r.y;if(q.z<0 && r.z>0)r.z=20-r.z;
 return floor(vec3(r)/10.0);
}
#endif
