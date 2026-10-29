extends RefCounted
## Private common30m period. Current terrain/shell origins are integer256m
## chunk origins,with Y0. Keep modulo operands NONNEGATIVE as in the original
## shader; do not rely on signed remainder behavior of the GLES compiler.
const REPLACEMENT="ivec3 biological_origin=ivec3(round(forest_origin)),biological_phase=abs(biological_origin)%ivec3(30);\n if(biological_origin.x<0 && biological_phase.x>0)biological_phase.x=30-biological_phase.x;\n if(biological_origin.y<0 && biological_phase.y>0)biological_phase.y=30-biological_phase.y;\n if(biological_origin.z<0 && biological_phase.z>0)biological_phase.z=30-biological_phase.z;\n vec3 p=(forest_local_position+vec3(biological_phase))/metres;"
static func apply_to(source:String)->String:
	var original:String=preload("res://tools/biome_extensions/biological_float_period_candidate.gd").ORIGINAL
	assert(source.count(original)==1,"Private trial requires original sampler")
	return source.replace(original,REPLACEMENT)
