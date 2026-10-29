extends RefCounted
## Private resource trial: avoid repeating dynamic integer modulus at every
## tissue call.30m is an even number of mirrored2.5m periods, and an integer
## number of2m/1.5m repeat periods. No extra varying, texture or shader branch.
const ORIGINAL="metres=max(round(metres*4.0)*.25,.25);int period=int(round(metres*4.0));ivec3 q=ivec3(round(forest_origin*4.0)),r=abs(q)%ivec3(period);\n if(q.x<0 && r.x>0)r.x=period-r.x;if(q.y<0 && r.y>0)r.y=period-r.y;if(q.z<0 && r.z>0)r.z=period-r.z;\n vec3 p=forest_local_position/metres+vec3(r)*.25/metres;"
const REPLACEMENT="vec3 p=(forest_local_position+mod(forest_origin,vec3(30.0)))/metres;"
static func apply_to(source:String)->String:
	assert(source.count(ORIGINAL)==1,"Private trial requires untouched production arithmetic")
	return source.replace(ORIGINAL,REPLACEMENT)
