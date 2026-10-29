extends RefCounted
## Private candidate: compute the common exact tissue period once per vertex,
## instead of repeating signed integer modulus in every projected sample.
## Current physical scales are 2.5m (mirrored), 2m and 1.5m (repeat).
## Thirty metres is respectively 12, 15 and 20 periods; 12 is even.
const DECLARATION = "varying flat vec3 biological_phase_origin;\n"
const ASSIGNMENT = "ivec3 biological_origin_ticks=ivec3(round(forest_origin*4.0));biological_phase_origin=vec3((biological_origin_ticks%ivec3(120)+ivec3(120))%ivec3(120))*.25;"
const ORIGINAL = "metres=max(round(metres*4.0)*.25,.25);int period=int(round(metres*4.0));ivec3 q=ivec3(round(forest_origin*4.0)),r=abs(q)%ivec3(period);\n if(q.x<0 && r.x>0)r.x=period-r.x;if(q.y<0 && r.y>0)r.y=period-r.y;if(q.z<0 && r.z>0)r.z=period-r.z;\n vec3 p=forest_local_position/metres+vec3(r)*.25/metres;"
static func sampler(source:String)->String:
	assert(source.count(ORIGINAL)==1,"Unexpected production projection source")
	return DECLARATION+source.replace(ORIGINAL,"vec3 p=(forest_local_position+biological_phase_origin)/metres;")
static func terrain(source:String)->String:
	var marker:String="forest_origin=MODEL_MATRIX[3].xyz;"
	assert(source.count(marker)==1)
	var declaration:String="varying flat vec3 forest_origin;"
	assert(source.count(declaration)==1)
	return source.replace(declaration,declaration+"\n"+DECLARATION).replace(marker,marker+ASSIGNMENT)
static func shell(source:String)->String:
	var marker:String="forest_origin=(MODEL_MATRIX*vec4(0,0,0,1)).xyz;"
	assert(source.count(marker)==1)
	return source.replace(marker,marker+ASSIGNMENT)
